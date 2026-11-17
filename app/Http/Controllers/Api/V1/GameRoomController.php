<?php

namespace App\Http\Controllers\Api\V1;

use App\Actions\CreateGameRoomAction;
use App\Actions\JoinGameRoomAction;
use App\Http\Controllers\Controller;
use App\Http\Requests\StoreGameRoomRequest;
use App\Http\Resources\GameRoomResource;
use App\Models\GameRoom;
use Illuminate\Http\Request;

class GameRoomController extends Controller
{
    public function store(StoreGameRoomRequest $request, CreateGameRoomAction $action): GameRoomResource
    {
        $room = $action->handle($request->user(), $request->integer('player_count'));

        return new GameRoomResource($room);
    }

    public function show(Request $request, string $code): GameRoomResource
    {
        $room = GameRoom::query()
            ->where('code', mb_strtoupper($code))
            ->whereHas('players', fn ($query) => $query->whereKey($request->user()->id))
            ->with('players')
            ->firstOrFail();

        return new GameRoomResource($room);
    }

    public function join(Request $request, string $code, JoinGameRoomAction $action): GameRoomResource
    {
        return new GameRoomResource($action->handle($code, $request->user()));
    }
}
