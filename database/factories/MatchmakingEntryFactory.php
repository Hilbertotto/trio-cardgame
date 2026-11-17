<?php

namespace Database\Factories;

use App\Models\MatchmakingEntry;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<MatchmakingEntry>
 */
class MatchmakingEntryFactory extends Factory
{
    /**
     * Define the model's default state.
     *
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        return [
            'user_id' => User::factory(),
            'player_count' => 3,
            'status' => 'waiting',
        ];
    }
}
