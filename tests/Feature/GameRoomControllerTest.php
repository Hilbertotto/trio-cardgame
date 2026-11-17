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
}
