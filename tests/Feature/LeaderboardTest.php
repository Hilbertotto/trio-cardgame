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

    public function test_daily_country_filters_use_todays_transactions(): void
    {
        $this->travelTo(\Carbon\Carbon::parse('2026-11-20 12:00:00', 'Europe/Budapest'));
        $me = User::factory()->create(['is_guest' => false, 'points' => 500]);
        $me->country_code = 'HU';
        $me->save();
        $other = User::factory()->create(['is_guest' => false, 'points' => 900]);
        $other->country_code = 'AT';
        $other->save();
        foreach ([[$me, 20, now()], [$me, 100, now()->subDay()], [$other, 80, now()]] as [$user, $amount, $at]) {
            \App\Models\PointTransaction::create(['user_id' => $user->id, 'type' => 'test', 'amount' => $amount, 'balance_after' => $amount, 'created_at' => $at]);
        }
        Sanctum::actingAs($me);
        $this->getJson('/api/v1/leaderboard?scope=country&period=daily')->assertOk()
            ->assertJsonCount(1, 'top')->assertJsonPath('me.points', 20)->assertJsonPath('me.rank', 1);
        $this->getJson('/api/v1/leaderboard?period=daily')->assertOk()
            ->assertJsonPath('top.0.points', 80)->assertJsonPath('me.rank', 2);
        $this->travelBack();
    }
}
