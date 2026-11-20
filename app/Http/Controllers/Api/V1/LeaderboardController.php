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
        $filters = $request->validate(['scope' => ['sometimes', 'in:global,country'], 'period' => ['sometimes', 'in:all,daily']]);
        $country = ($filters['scope'] ?? 'global') === 'country';
        $daily = ($filters['period'] ?? 'all') === 'daily';
        $me = $request->user();
        if ($country && ! $me->country_code) {
            return response()->json(['message' => 'Előbb add meg az országodat a profilodban.'], 422);
        }
        $base = User::query()->where('is_guest', false)->select('users.*');
        if ($country) $base->where('country_code', $me->country_code);
        if ($daily) {
            $start = \Carbon\CarbonImmutable::now('Europe/Budapest')->startOfDay()->utc();
            $end = $start->setTimezone('Europe/Budapest')->addDay()->utc();
            $base->selectSub(\App\Models\PointTransaction::query()
                ->selectRaw('COALESCE(SUM(amount), 0)')->whereColumn('user_id', 'users.id')
                ->where('created_at', '>=', $start)->where('created_at', '<', $end), 'score');
        } else {
            $base->selectRaw('points as score');
        }
        $query = User::query()->fromSub($base, 'ranked')->select('ranked.*');
        if ($daily) $query->where('score', '>', 0);
        $entry = fn (User $user, int $rank): array => [
            'rank' => $rank, 'name' => $user->full_name ?? $user->name,
            'country_code' => $user->country_code,
            'avatar_id' => $user->avatar_id ?: (($user->id - 1) % 40) + 1, 'points' => (int) $user->score,
        ];
        $top = (clone $query)->orderByDesc('score')->orderBy('id')->limit(5)->get()
            ->map(fn (User $user, int $index) => $entry($user, $index + 1));
        $myRow = (clone $query)->where('id', $me->id)->first();
        $mine = null;
        if ($myRow) {
            $rank = (clone $query)->where(function ($q) use ($myRow) {
                $q->where('score', '>', $myRow->score)->orWhere(function ($q) use ($myRow) {
                    $q->where('score', $myRow->score)->where('id', '<', $myRow->id);
                });
            })->count() + 1;
            $mine = $entry($myRow, $rank);
        }
        return response()->json(['top' => $top, 'me' => $mine]);
    }
}
