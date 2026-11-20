<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;

class LeaderboardController extends Controller
{
    public function __invoke(Request $request): JsonResponse
    {
        $query = User::query()->where('is_guest', false);
        $entry = fn (User $user, int $rank): array => [
            'rank' => $rank, 'name' => $user->full_name ?? $user->name,
            'country_code' => $user->country_code,
            'avatar_id' => $user->avatar_id ?: 1, 'points' => (int) $user->points,
        ];
        $top = (clone $query)->orderByDesc('points')->orderBy('id')->limit(5)->get()
            ->map(fn (User $user, int $index) => $entry($user, $index + 1));
        $me = $request->user();
        $mine = null;
        if ($me && ! $me->is_guest) {
            $rank = (clone $query)->where(function ($q) use ($me) {
                $q->where('points', '>', $me->points)->orWhere(function ($q) use ($me) {
                    $q->where('points', $me->points)->where('id', '<', $me->id);
                });
            })->count() + 1;
            $mine = $entry($me, $rank);
        }
        return response()->json(['top' => $top, 'me' => $mine]);
    }
}
