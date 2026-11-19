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
        private StartGameRoomAction $startGameRoom,
    ) {}

    public function handle(User $player, int $playerCount): GameRoom
    {
        return DB::transaction(function () use ($player, $playerCount): GameRoom {
            $existing = MatchmakingEntry::query()
                ->whereBelongsTo($player)
                ->with('gameRoom.players')
                ->lockForUpdate()
                ->first();

            $existingRoom = $existing?->gameRoom;
            $activeSeat = $existingRoom?->players->firstWhere('id', $player->id)?->pivot->seat;
            $canResume = $existingRoom !== null
                && in_array($existingRoom->status, ['waiting', 'playing'], true)
                && empty($existingRoom->state['winner_seat'])
                && $activeSeat !== null
                && ! in_array((int) $activeSeat, array_map('intval', $existingRoom->state['bot_seats'] ?? []), true);

            if ($canResume && $existing->player_count === $playerCount) {
                return $existing->gameRoom;
            }

            if ($existing !== null) {
                if ($existing->gameRoom?->status === 'waiting') {
                    $existing->gameRoom->players()->detach($player->id);
                }
                $existing->delete();
            }

            $candidateEntries = MatchmakingEntry::query()
                ->where('status', 'waiting')
                ->where('player_count', $playerCount)
                ->whereNotNull('game_room_id')
                ->where('user_id', '!=', $player->id)
                ->oldest('id')
                ->lockForUpdate()
                ->get();

            $room = null;
            foreach ($candidateEntries as $candidate) {
                $candidateRoom = GameRoom::query()
                    ->with('players')
                    ->lockForUpdate()
                    ->find($candidate->game_room_id);

                if ($candidateRoom !== null
                    && $candidateRoom->status === 'waiting'
                    && $candidateRoom->players->count() < $candidateRoom->player_count) {
                    $room = $candidateRoom;
                    break;
                }
            }

            if ($room === null) {
                $room = $this->createGameRoom->handle($player, $playerCount);
            } else {
                $room = $this->joinGameRoom->handle($room->code, $player);
            }

            MatchmakingEntry::query()->create([
                'user_id' => $player->id,
                'game_room_id' => $room->id,
                'player_count' => $playerCount,
                'status' => 'waiting',
            ]);

            $room->load('players');
            if ($room->players->count() >= $room->player_count) {
                MatchmakingEntry::query()
                    ->where('game_room_id', $room->id)
                    ->update(['status' => 'matched']);
                $room = $this->startGameRoom->handle($room);
            }

            return $room;
        });
    }
}
