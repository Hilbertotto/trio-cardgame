<?php

namespace App\Actions;

use App\Models\GameRoom;
use App\Models\MatchmakingEntry;
use App\Models\User;
use Illuminate\Support\Facades\DB;

class JoinMatchmakingAction
{
    public function __construct(
        private CreateGameRoomAction $createGameRoom,
        private JoinGameRoomAction $joinGameRoom,
    ) {}

    public function handle(User $player, int $playerCount): ?GameRoom
    {
        return DB::transaction(function () use ($player, $playerCount): ?GameRoom {
            MatchmakingEntry::query()->updateOrCreate(
                ['user_id' => $player->id],
                ['player_count' => $playerCount, 'status' => 'waiting', 'game_room_id' => null],
            );

            $entries = MatchmakingEntry::query()
                ->where('status', 'waiting')
                ->where('player_count', $playerCount)
                ->oldest('id')
                ->limit($playerCount)
                ->lockForUpdate()
                ->get();

            if ($entries->count() < $playerCount) {
                return null;
            }

            $players = User::query()->whereKey($entries->pluck('user_id'))->get()->keyBy('id');
            $host = $players->get($entries->first()->user_id);
            $room = $this->createGameRoom->handle($host, $playerCount);

            foreach ($entries->skip(1) as $entry) {
                $this->joinGameRoom->handle($room->code, $players->get($entry->user_id));
            }

            MatchmakingEntry::query()
                ->whereKey($entries->pluck('id'))
                ->update(['status' => 'matched', 'game_room_id' => $room->id]);

            return $room->load('players');
        });
    }
}
