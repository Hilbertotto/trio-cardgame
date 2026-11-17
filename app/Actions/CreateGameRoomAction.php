<?php

namespace App\Actions;

use App\Models\GameRoom;
use App\Models\User;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

class CreateGameRoomAction
{
    public function handle(User $host, int $playerCount): GameRoom
    {
        return DB::transaction(function () use ($host, $playerCount): GameRoom {
            do {
                $code = Str::upper(Str::random(6));
            } while (GameRoom::query()->where('code', $code)->exists());

            $room = GameRoom::query()->create([
                'code' => $code,
                'host_id' => $host->id,
                'player_count' => $playerCount,
                'status' => 'waiting',
            ]);

            $room->players()->attach($host, ['seat' => 1]);

            return $room->load('players');
        });
    }
}
