<?php

namespace App\Http\Controllers\Api\V1;

use App\Actions\CreateGameRoomAction;
use App\Actions\AwardGamePointsAction;
use App\Actions\JoinGameRoomAction;
use App\Actions\PlayGameRoomCardAction;
use App\Http\Controllers\Controller;
use App\Http\Requests\StoreGameRoomRequest;
use App\Http\Resources\GameRoomResource;
use App\Models\GameRoom;
use Illuminate\Http\Request;
use Illuminate\Http\Response;
use Illuminate\Support\Facades\DB;

class GameRoomController extends Controller
{
    public function store(StoreGameRoomRequest $request, CreateGameRoomAction $action): GameRoomResource
    {
        $room = $action->handle($request->user(), $request->integer('player_count'));

        return new GameRoomResource($room);
    }

    public function show(Request $request, string $code, PlayGameRoomCardAction $play, AwardGamePointsAction $award): GameRoomResource
    {
        $room = GameRoom::query()
            ->where('code', mb_strtoupper($code))
            ->whereHas('players', fn ($query) => $query->whereKey($request->user()->id))
            ->with('players')
            ->firstOrFail();

        return new GameRoomResource($this->settleIfFinished($play->refresh($room), $award));
    }

    public function join(Request $request, string $code, JoinGameRoomAction $action): GameRoomResource
    {
        return new GameRoomResource($action->handle($code, $request->user()));
    }

    public function destroy(Request $request, string $code): Response
    {
        DB::transaction(function () use ($request, $code): void {
            $room = GameRoom::query()
                ->where('code', mb_strtoupper($code))
                ->whereHas('players', fn ($query) => $query->whereKey($request->user()->id))
                ->with('players')
                ->lockForUpdate()
                ->firstOrFail();

            abort_if($room->status !== 'waiting', 409, 'A megkezdett játékból itt nem lehet kilépni.');

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

        return response()->noContent();
    }

    public function play(Request $request, string $code, PlayGameRoomCardAction $action, AwardGamePointsAction $award): GameRoomResource
    {
        $validated = $request->validate([
            'source' => ['required', 'in:table,hand'],
            'owner_seat' => ['nullable', 'integer', 'min:1', 'max:6'],
            'slot' => ['required', 'integer', 'min:0', 'max:11'],
        ]);
        $room = GameRoom::query()
            ->where('code', mb_strtoupper($code))
            ->whereHas('players', fn ($query) => $query->whereKey($request->user()->id))
            ->firstOrFail();

        return new GameRoomResource($this->settleIfFinished($action->handle($room, $request->user(), $validated), $award));
    }

    private function settleIfFinished(GameRoom $room, AwardGamePointsAction $award): GameRoom
    {
        if ($room->status !== 'finished' || empty($room->state['winner_seat'])) {
            return $room;
        }

        $winner = $room->players->first(fn ($player): bool => (int) $player->pivot->seat === (int) $room->state['winner_seat']);
        return $winner === null ? $room : $award->handle($room, $winner);
    }
}
