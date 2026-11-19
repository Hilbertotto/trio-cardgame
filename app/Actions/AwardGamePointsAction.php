<?php

namespace App\Actions;

use App\Models\GameRoom;
use App\Models\CoinTransaction;
use App\Models\PointTransaction;
use App\Models\User;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

class AwardGamePointsAction
{
    public function handle(GameRoom $gameRoom, User $winner): GameRoom
    {
        return DB::transaction(function () use ($gameRoom, $winner): GameRoom {
            $lockedRoom = GameRoom::query()->lockForUpdate()->findOrFail($gameRoom->id);
            $players = $lockedRoom->players()->get();

            if (! $players->contains('id', $winner->id)) {
                throw ValidationException::withMessages(['winner' => 'A győztes nem tagja a szobának.']);
            }

            foreach ($players as $player) {
                $this->creditOnce(
                    user: $player,
                    gameRoom: $lockedRoom,
                    type: 'completed_game',
                    amount: config('trio.points.completed_game'),
                );
            }

            $this->creditOnce(
                user: $winner,
                gameRoom: $lockedRoom,
                type: 'winner_bonus',
                amount: config('trio.points.winner_bonus'),
            );

            $this->creditCoinsOnce($winner, $lockedRoom);

            $lockedRoom->update([
                'status' => 'finished',
                'finished_at' => $lockedRoom->finished_at ?? now(),
            ]);

            return $lockedRoom->load('players');
        });
    }

    private function creditCoinsOnce(User $user, GameRoom $gameRoom): void
    {
        $type = 'winner_reward';
        if (CoinTransaction::query()->whereBelongsTo($user)->whereBelongsTo($gameRoom)->where('type', $type)->exists()) return;

        $lockedUser = User::query()->lockForUpdate()->findOrFail($user->id);
        $amount = (int) (config('trio.coins.winner.'.$gameRoom->player_count) ?? 0);
        $lockedUser->increment('coins', $amount);
        $lockedUser->refresh();
        $lockedUser->coinTransactions()->create([
            'game_room_id' => $gameRoom->id,
            'type' => $type,
            'amount' => $amount,
            'balance_after' => $lockedUser->coins,
            'metadata' => ['player_count' => $gameRoom->player_count],
        ]);
    }

    private function creditOnce(User $user, GameRoom $gameRoom, string $type, int $amount): void
    {
        if (PointTransaction::query()
            ->whereBelongsTo($user)
            ->whereBelongsTo($gameRoom)
            ->where('type', $type)
            ->exists()) {
            return;
        }

        $lockedUser = User::query()->lockForUpdate()->findOrFail($user->id);
        $lockedUser->increment('points', $amount);
        $lockedUser->refresh();

        $lockedUser->pointTransactions()->create([
            'game_room_id' => $gameRoom->id,
            'type' => $type,
            'amount' => $amount,
            'balance_after' => $lockedUser->points,
        ]);
    }
}
