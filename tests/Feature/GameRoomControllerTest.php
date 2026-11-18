<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\LazilyRefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class GameRoomControllerTest extends TestCase
{
    use LazilyRefreshDatabase;

    public function test_authenticated_player_creates_room_and_occupies_first_seat(): void
    {
        $host = User::factory()->guest()->create();
        Sanctum::actingAs($host);

        $response = $this->postJson('/api/v1/rooms', ['player_count' => 4]);

        $response
            ->assertSuccessful()
            ->assertJsonPath('data.player_count', 4)
            ->assertJsonPath('data.players.0.id', $host->id)
            ->assertJsonPath('data.seats.0.seat', 1);

        $this->assertDatabaseHas('game_rooms', ['host_id' => $host->id, 'player_count' => 4]);
    }

    public function test_second_player_joins_room_and_receives_second_seat(): void
    {
        $host = User::factory()->guest()->create();
        $player = User::factory()->guest()->create();

        Sanctum::actingAs($host);
        $roomCode = $this->postJson('/api/v1/rooms', ['player_count' => 3])->json('data.code');

        Sanctum::actingAs($player);
        $this->postJson("/api/v1/rooms/{$roomCode}/join")
            ->assertSuccessful()
            ->assertJsonPath('data.seats.1.player_id', $player->id)
            ->assertJsonPath('data.seats.1.seat', 2);

        $this->assertDatabaseHas('game_room_user', ['user_id' => $player->id, 'seat' => 2]);
    }

    public function test_returns_422_when_room_is_full(): void
    {
        $players = User::factory()->guest()->count(4)->create();
        Sanctum::actingAs($players[0]);
        $roomCode = $this->postJson('/api/v1/rooms', ['player_count' => 3])->json('data.code');

        foreach ([1, 2] as $index) {
            Sanctum::actingAs($players[$index]);
            $this->postJson("/api/v1/rooms/{$roomCode}/join")->assertSuccessful();
        }

        Sanctum::actingAs($players[3]);
        $this->postJson("/api/v1/rooms/{$roomCode}/join")
            ->assertUnprocessable()
            ->assertJsonValidationErrors('room');
    }

    public function test_returns_friendly_404_when_room_code_does_not_exist(): void
    {
        Sanctum::actingAs(User::factory()->guest()->create());

        $this->postJson('/api/v1/rooms/ABC123/join')
            ->assertNotFound()
            ->assertJsonPath('message', 'A szoba nem található.');
    }

    public function test_player_can_leave_waiting_room_and_free_the_seat(): void
    {
        $host = User::factory()->guest()->create();
        $player = User::factory()->guest()->create();

        Sanctum::actingAs($host);
        $roomCode = $this->postJson('/api/v1/rooms', ['player_count' => 3])->json('data.code');

        Sanctum::actingAs($player);
        $this->postJson("/api/v1/rooms/{$roomCode}/join")->assertSuccessful();
        $this->deleteJson("/api/v1/rooms/{$roomCode}")->assertNoContent();

        $this->assertDatabaseMissing('game_room_user', ['user_id' => $player->id]);
        $this->assertDatabaseHas('game_rooms', ['code' => $roomCode]);
    }

    public function test_empty_waiting_room_is_deleted_when_host_leaves(): void
    {
        $host = User::factory()->guest()->create();
        Sanctum::actingAs($host);
        $roomCode = $this->postJson('/api/v1/rooms', ['player_count' => 3])->json('data.code');

        $this->deleteJson("/api/v1/rooms/{$roomCode}")->assertNoContent();

        $this->assertDatabaseMissing('game_rooms', ['code' => $roomCode]);
    }

    public function test_returns_401_when_room_is_created_without_token(): void
    {
        $this->postJson('/api/v1/rooms', ['player_count' => 3])->assertUnauthorized();
    }

    public function test_full_room_starts_once_and_players_share_the_same_deal(): void
    {
        $players = User::factory()->guest()->count(3)->create();
        Sanctum::actingAs($players[0]);
        $roomCode = $this->postJson('/api/v1/rooms', ['player_count' => 3])->json('data.code');

        foreach ($players->skip(1) as $player) {
            Sanctum::actingAs($player);
            $this->postJson("/api/v1/rooms/{$roomCode}/join")->assertSuccessful();
        }

        Sanctum::actingAs($players[0]);
        $first = $this->getJson("/api/v1/rooms/{$roomCode}")
            ->assertJsonPath('data.status', 'playing')
            ->assertJsonPath('data.my_seat', 1)
            ->assertJsonCount(3, 'data.state.hands')
            ->assertJsonCount(9, 'data.state.table')
            ->json('data.state');

        Sanctum::actingAs($players[1]);
        $this->getJson("/api/v1/rooms/{$roomCode}")
            ->assertJsonPath('data.my_seat', 2)
            ->assertJsonPath('data.state', $first);
    }

    public function test_current_player_can_reveal_a_table_card(): void
    {
        $players = User::factory()->guest()->count(3)->create();
        Sanctum::actingAs($players[0]);
        $roomCode = $this->postJson('/api/v1/rooms', ['player_count' => 3])->json('data.code');
        foreach ($players->skip(1) as $player) {
            Sanctum::actingAs($player);
            $this->postJson("/api/v1/rooms/{$roomCode}/join");
        }

        Sanctum::actingAs($players[0]);
        $value = $this->getJson("/api/v1/rooms/{$roomCode}")->json('data.state.table.0');
        $this->postJson("/api/v1/rooms/{$roomCode}/play", [
            'source' => 'table',
            'slot' => 0,
        ])->assertSuccessful()
            ->assertJsonPath('data.state.table.0', null)
            ->assertJsonPath('data.state.revealed.0.value', $value);

        Sanctum::actingAs($players[1]);
        $this->postJson("/api/v1/rooms/{$roomCode}/play", [
            'source' => 'table',
            'slot' => 1,
        ])->assertUnprocessable()->assertJsonValidationErrors('move');
    }

    public function test_only_timed_out_player_gets_ten_second_warning_before_bot_takeover(): void
    {
        $players = User::factory()->guest()->count(3)->create();
        Sanctum::actingAs($players[0]);
        $roomCode = $this->postJson('/api/v1/rooms', ['player_count' => 3])->json('data.code');
        foreach ($players->skip(1) as $player) {
            Sanctum::actingAs($player);
            $this->postJson("/api/v1/rooms/{$roomCode}/join");
        }

        $this->travel(31)->seconds();
        Sanctum::actingAs($players[0]);
        $warning = $this->getJson("/api/v1/rooms/{$roomCode}")
            ->assertSuccessful()
            ->assertJsonPath('data.forced_disconnect', false)
            ->json('data.turn_timeout_remaining');
        $this->assertGreaterThanOrEqual(8, $warning);
        $this->assertLessThanOrEqual(10, $warning);

        Sanctum::actingAs($players[1]);
        $this->getJson("/api/v1/rooms/{$roomCode}")
            ->assertSuccessful()
            ->assertJsonPath('data.turn_timeout_remaining', null)
            ->assertJsonPath('data.forced_disconnect', false)
            ->assertJsonPath('data.state.bot_seats', []);

        $this->travel(10)->seconds();
        $response = $this->getJson("/api/v1/rooms/{$roomCode}")
            ->assertSuccessful()
            ->assertJsonPath('data.state.bot_seats.0', 1)
            ->assertJsonCount(1, 'data.state.revealed');

        $revealed = $response->json('data.state.revealed.0');
        $this->assertContains($revealed['source'], ['table', 'hand']);
        $this->assertSame(1, $response->json('data.state.turn_seat'));

        Sanctum::actingAs($players[0]);
        $this->getJson("/api/v1/rooms/{$roomCode}")
            ->assertJsonPath('data.forced_disconnect', true)
            ->assertJsonPath('data.turn_timeout_remaining', null);
    }

    public function test_last_human_player_wins_when_every_other_seat_is_taken_over(): void
    {
        $players = User::factory()->guest()->count(3)->create();
        Sanctum::actingAs($players[0]);
        $roomCode = $this->postJson('/api/v1/rooms', ['player_count' => 3])->json('data.code');
        foreach ($players->skip(1) as $player) {
            Sanctum::actingAs($player);
            $this->postJson("/api/v1/rooms/{$roomCode}/join");
        }

        $room = \App\Models\GameRoom::query()->where('code', $roomCode)->firstOrFail();
        $state = $room->state;
        $state['turn_seat'] = 2;
        $state['bot_seats'] = [1];
        $state['turn_started_at'] = now()->subSeconds(41)->toIso8601String();
        $room->update(['state' => $state]);

        Sanctum::actingAs($players[2]);
        $this->getJson("/api/v1/rooms/{$roomCode}")
            ->assertSuccessful()
            ->assertJsonPath('data.status', 'finished')
            ->assertJsonPath('data.state.bot_seats', [1, 2])
            ->assertJsonPath('data.state.winner_seat', 3)
            ->assertJsonCount(0, 'data.state.revealed');
    }
}
