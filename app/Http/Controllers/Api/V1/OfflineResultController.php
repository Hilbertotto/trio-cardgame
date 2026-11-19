<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Resources\UserResource;
use App\Models\PointTransaction;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class OfflineResultController extends Controller
{
    public function __invoke(Request $request): JsonResponse
    {
        $data = $request->validate([
            'player_count' => ['required', 'integer', 'in:3,4,5,6'],
            'won' => ['required', 'boolean'],
            'game_id' => ['required', 'string', 'max:100'],
        ]);

        $user = $request->user();
        $updated = DB::transaction(function () use ($data, $user): bool {
            $duplicate = PointTransaction::query()
                ->where('user_id', $user->id)
                ->where('type', 'offline_game')
                ->where('metadata->game_id', $data['game_id'])
                ->exists();
            if ($duplicate) return false;

            $locked = $user->newQuery()->lockForUpdate()->findOrFail($user->id);
            $amount = (int) config('trio.points.completed_game');
            if ($data['won']) $amount += (int) config('trio.points.winner_bonus');
            $locked->increment('points', $amount);
            $locked->refresh();
            $locked->pointTransactions()->create([
                'type' => 'offline_game',
                'amount' => $amount,
                'balance_after' => $locked->points,
                'metadata' => [
                    'game_id' => $data['game_id'],
                    'player_count' => $data['player_count'],
                    'won' => $data['won'],
                ],
            ]);
            return true;
        });

        return response()->json([
            'recorded' => $updated,
            'player' => new UserResource($user->fresh()),
        ]);
    }
}
