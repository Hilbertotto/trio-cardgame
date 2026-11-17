<?php

namespace Database\Factories;

use App\Models\GameRoom;
use App\Models\PointTransaction;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<PointTransaction>
 */
class PointTransactionFactory extends Factory
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
            'game_room_id' => GameRoom::factory(),
            'type' => 'completed_game',
            'amount' => 20,
            'balance_after' => 20,
        ];
    }
}
