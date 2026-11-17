<?php

namespace App\Http\Controllers\Api\V1;

use App\Actions\JoinMatchmakingAction;
use App\Http\Controllers\Controller;
use App\Http\Requests\JoinMatchmakingRequest;
use App\Http\Resources\GameRoomResource;
use App\Models\MatchmakingEntry;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class MatchmakingController extends Controller
{
    public function store(JoinMatchmakingRequest $request, JoinMatchmakingAction $action): JsonResponse
    {
        $room = $action->handle($request->user(), $request->integer('player_count'));

        return response()->json([
            'status' => $room === null ? 'queued' : 'matched',
            'room' => $room === null ? null : new GameRoomResource($room),
        ]);
    }

    public function destroy(Request $request): JsonResponse
    {
        MatchmakingEntry::query()
            ->whereBelongsTo($request->user())
            ->where('status', 'waiting')
            ->delete();

        return response()->json(status: 204);
    }
}
