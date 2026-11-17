<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\LazilyRefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class MatchmakingControllerTest extends TestCase
{
    use LazilyRefreshDatabase;

    public function test_player_is_queued_until_enough_players_join(): void
    {
        $player = User::factory()->guest()->create();
        Sanctum::actingAs($player);

        $this->postJson('/api/v1/matchmaking', ['player_count' => 3])
            ->assertSuccessful()
            ->assertJsonPath('status', 'queued')
            ->assertJsonPath('room', null);

        $this->assertDatabaseHas('matchmaking_entries', [
            'user_id' => $player->id,
            'player_count' => 3,
            'status' => 'waiting',
        ]);
    }

    public function test_last_required_player_creates_room_for_every_queued_player(): void
    {
        $players = User::factory()->guest()->count(3)->create();

        foreach ($players->take(2) as $player) {
            Sanctum::actingAs($player);
            $this->postJson('/api/v1/matchmaking', ['player_count' => 3])
                ->assertJsonPath('status', 'queued');
        }

        Sanctum::actingAs($players[2]);
        $this->postJson('/api/v1/matchmaking', ['player_count' => 3])
            ->assertSuccessful()
            ->assertJsonPath('status', 'matched')
            ->assertJsonCount(3, 'room.players');

        $this->assertDatabaseCount('game_rooms', 1);
        $this->assertDatabaseCount('game_room_user', 3);
        $this->assertDatabaseCount('matchmaking_entries', 3);
        $this->assertDatabaseMissing('matchmaking_entries', ['status' => 'waiting']);

        Sanctum::actingAs($players[0]);
        $this->getJson('/api/v1/matchmaking')
            ->assertSuccessful()
            ->assertJsonPath('status', 'matched')
            ->assertJsonCount(3, 'room.players');
    }

    public function test_player_can_check_waiting_queue_status(): void
    {
        $player = User::factory()->guest()->create();
        Sanctum::actingAs($player);

        $this->getJson('/api/v1/matchmaking')
            ->assertSuccessful()
            ->assertJsonPath('status', 'idle')
            ->assertJsonPath('room', null);

        $this->postJson('/api/v1/matchmaking', ['player_count' => 4]);

        $this->getJson('/api/v1/matchmaking')
            ->assertSuccessful()
            ->assertJsonPath('status', 'waiting')
            ->assertJsonPath('room', null);
    }

    public function test_player_can_leave_waiting_queue(): void
    {
        $player = User::factory()->guest()->create();
        Sanctum::actingAs($player);
        $this->postJson('/api/v1/matchmaking', ['player_count' => 4]);

        $this->deleteJson('/api/v1/matchmaking')->assertNoContent();

        $this->assertDatabaseMissing('matchmaking_entries', ['user_id' => $player->id]);
    }
}
