<?php

namespace App\Http\Controllers\Api\V1;

use App\Actions\JoinMatchmakingAction;
use App\Http\Controllers\Controller;
use App\Http\Requests\JoinMatchmakingRequest;
use App\Http\Resources\GameRoomResource;
use App\Models\MatchmakingEntry;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class MatchmakingController extends Controller
{
    public function show(Request $request): JsonResponse
    {
        $entry = MatchmakingEntry::query()
            ->whereBelongsTo($request->user())
            ->with('gameRoom.players')
            ->first();

        return response()->json([
            'status' => $entry?->status ?? 'idle',
            'room' => $entry?->gameRoom === null
                ? null
                : new GameRoomResource($entry->gameRoom),
        ]);
    }

    public function store(JoinMatchmakingRequest $request, JoinMatchmakingAction $action): JsonResponse
    {
        $room = $action->handle($request->user(), $request->integer('player_count'));
        $matched = $room->players->count() >= $room->player_count;

        return response()->json([
            'status' => $matched ? 'matched' : 'waiting',
            'room' => new GameRoomResource($room),
        ]);
    }

    public function destroy(Request $request): JsonResponse
    {
        DB::transaction(function () use ($request): void {
            $entry = MatchmakingEntry::query()
                ->whereBelongsTo($request->user())
                ->where('status', 'waiting')
                ->with('gameRoom')
                ->lockForUpdate()
                ->first();

            if ($entry === null) {
                return;
            }

            $room = $entry->gameRoom;
            $entry->delete();

            if ($room === null) {
                return;
            }

            $room->players()->detach($request->user()->id);
            if ($room->players()->count() === 0) {
                $room->delete();

                return;
            }

            if ($room->host_id === $request->user()->id) {
                $room->update([
                    'host_id' => $room->players()->orderByPivot('seat')->value('users.id'),
                ]);
            }
        });

        return response()->json(status: 204);
    }
}
