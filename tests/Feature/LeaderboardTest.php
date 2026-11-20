<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class LeaderboardTest extends TestCase
{
    use RefreshDatabase;

    public function test_ranking_uses_points_and_returns_own_rank(): void
    {
        $leader = User::factory()->create(['is_guest' => false, 'points' => 100]);
        $me = User::factory()->create(['is_guest' => false, 'points' => 30]);
        User::factory()->create(['is_guest' => true, 'points' => 999]);
        Sanctum::actingAs($me);
        $this->getJson('/api/v1/leaderboard')->assertOk()
            ->assertJsonCount(2, 'top')->assertJsonPath('top.0.name', $leader->name)
            ->assertJsonPath('me.rank', 2)->assertJsonPath('me.points', 30);
    }

    public function test_authentication_is_required(): void
    {
        $this->getJson('/api/v1/leaderboard')->assertUnauthorized();
    }
}
