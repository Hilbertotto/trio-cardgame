<?php

namespace Tests\Feature;

use App\Actions\AwardGamePointsAction;
use App\Models\GameRoom;
use App\Models\User;
use Illuminate\Foundation\Testing\LazilyRefreshDatabase;
use Tests\TestCase;

class AwardGamePointsActionTest extends TestCase
{
    use LazilyRefreshDatabase;

    public function test_completed_game_awards_participation_points_and_winner_bonus(): void
    {
        [$room, $winner, $otherPlayer] = $this->roomWithTwoPlayers();

        app(AwardGamePointsAction::class)->handle($room, $winner);

        $this->assertSame(120, $winner->fresh()->points);
        $this->assertSame(20, $otherPlayer->fresh()->points);
        $this->assertDatabaseCount('point_transactions', 3);
        $this->assertDatabaseHas('game_rooms', ['id' => $room->id, 'status' => 'finished']);
    }

    public function test_same_game_cannot_award_points_twice(): void
    {
        [$room, $winner, $otherPlayer] = $this->roomWithTwoPlayers();
        $action = app(AwardGamePointsAction::class);

        $action->handle($room, $winner);
        $action->handle($room, $winner);

        $this->assertSame(120, $winner->fresh()->points);
        $this->assertSame(20, $otherPlayer->fresh()->points);
        $this->assertDatabaseCount('point_transactions', 3);
    }

    /** @return array{GameRoom, User, User} */
    private function roomWithTwoPlayers(): array
    {
        $winner = User::factory()->guest()->create();
        $otherPlayer = User::factory()->guest()->create();
        $room = GameRoom::factory()->for($winner, 'host')->create(['player_count' => 3]);
        $room->players()->attach($winner, ['seat' => 1]);
        $room->players()->attach($otherPlayer, ['seat' => 2]);

        return [$room, $winner, $otherPlayer];
    }
}
