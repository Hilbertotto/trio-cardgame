<?php

namespace App\Actions;

use App\Models\GameRoom;
use App\Models\User;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;
use Symfony\Component\HttpKernel\Exception\NotFoundHttpException;

class JoinGameRoomAction
{
    public function __construct(private StartGameRoomAction $startGameRoom) {}

    public function handle(string $code, User $player): GameRoom
    {
        return DB::transaction(function () use ($code, $player): GameRoom {
            $room = GameRoom::query()
                ->where('code', mb_strtoupper($code))
                ->lockForUpdate()
                ->first();

            if ($room === null) {
                throw new NotFoundHttpException('A szoba nem található.');
            }

            if ($room->status !== 'waiting') {
                throw ValidationException::withMessages(['room' => 'A szobához már nem lehet csatlakozni.']);
            }

            if ($room->players()->whereKey($player->id)->exists()) {
                return $room->load('players');
            }

            $occupiedSeats = $room->players()->pluck('game_room_user.seat');

            if ($occupiedSeats->count() >= $room->player_count) {
                throw ValidationException::withMessages(['room' => 'A szoba megtelt.']);
            }

            $seat = collect(range(1, $room->player_count))
                ->first(fn (int $candidate): bool => ! $occupiedSeats->contains($candidate));

            $room->players()->attach($player, ['seat' => $seat]);

            if ($room->players()->count() >= $room->player_count) {
                return $this->startGameRoom->handle($room);
            }

            return $room->load('players');
        });
    }
}
