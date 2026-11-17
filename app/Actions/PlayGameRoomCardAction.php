<?php

namespace App\Actions;

use App\Models\GameRoom;
use App\Models\User;
use Carbon\CarbonImmutable;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

class PlayGameRoomCardAction
{
    public function handle(GameRoom $room, User $player, array $selection): GameRoom
    {
        return DB::transaction(function () use ($room, $player, $selection): GameRoom {
            $room = GameRoom::query()->with('players')->lockForUpdate()->findOrFail($room->id);
            $state = $this->resolveIfDue($room->state ?? []);
            $seat = (int) $room->players->firstWhere('id', $player->id)?->pivot->seat;

            if ($room->status !== 'playing' || $seat < 1 || (int) ($state['turn_seat'] ?? 0) !== $seat) {
                throw ValidationException::withMessages(['move' => 'Most nem te következel.']);
            }
            if (! empty($state['resolve_at'])) {
                throw ValidationException::withMessages(['move' => 'Várd meg a felfedett lapok visszafordítását.']);
            }
            if (count($state['revealed'] ?? []) >= 3) {
                throw ValidationException::withMessages(['move' => 'Ez a kör már lezárult.']);
            }

            $source = $selection['source'];
            $slot = (int) $selection['slot'];
            $ownerSeat = $source === 'table' ? 0 : (int) $selection['owner_seat'];
            if ($source === 'table') {
                $value = $state['table'][$slot] ?? null;
                if ($value === null) {
                    throw ValidationException::withMessages(['move' => 'Ez az asztali lap nem választható.']);
                }
                $state['table'][$slot] = null;
            } else {
                $handIndex = $ownerSeat - 1;
                $hand = $state['hands'][$handIndex] ?? [];
                $liveSlots = array_keys(array_filter($hand, fn ($value) => $value !== null));
                if ($ownerSeat < 1 || $slot < 0 || $liveSlots === [] || ! in_array($slot, [min($liveSlots), max($liveSlots)], true)) {
                    throw ValidationException::withMessages(['move' => 'Csak egy játékos legkisebb vagy legnagyobb lapja választható.']);
                }
                $value = $hand[$slot];
                $state['hands'][$handIndex][$slot] = null;
            }

            $state['revealed'][] = compact('source', 'ownerSeat', 'slot', 'value');
            $values = array_column($state['revealed'], 'value');
            $state['version'] = ((int) ($state['version'] ?? 0)) + 1;

            if (count($values) > 1 && count(array_unique($values)) > 1) {
                $state['message'] = 'Nem egyezik — 2 másodperc múlva a következő játékos jön.';
                $state['resolve_at'] = now()->addSeconds(2)->toIso8601String();
            } elseif (count($values) === 3) {
                $value = $values[0];
                $state['trios'][$seat - 1][] = $value;
                $won = $value === 7 || count($state['trios'][$seat - 1]) >= 3;
                if ($won) {
                    $state['winner_seat'] = $seat;
                    $state['message'] = "A(z) {$seat}. játékos megnyerte a játékot!";
                    $room->status = 'finished';
                    $room->finished_at = now();
                } else {
                    $state['message'] = "TRIO! A {$value}-es hármas megvan.";
                    $state['resolve_at'] = now()->addSeconds(2)->toIso8601String();
                }
            } else {
                $state['message'] = 'Még '.(3 - count($values)).' azonos lap kell.';
            }

            $room->state = $state;
            $room->save();

            return $room->fresh('players');
        });
    }

    public function refresh(GameRoom $room): GameRoom
    {
        if ($room->status !== 'playing' || empty($room->state['resolve_at'])) {
            return $room;
        }

        return DB::transaction(function () use ($room): GameRoom {
            $locked = GameRoom::query()->with('players')->lockForUpdate()->findOrFail($room->id);
            $state = $this->resolveIfDue($locked->state ?? []);
            if ($state !== $locked->state) {
                $locked->update(['state' => $state]);
            }
            return $locked->fresh('players');
        });
    }

    private function resolveIfDue(array $state): array
    {
        $resolveAt = $state['resolve_at'] ?? null;
        if ($resolveAt === null || CarbonImmutable::parse($resolveAt)->isFuture()) {
            return $state;
        }

        $revealed = $state['revealed'] ?? [];
        $isTrio = count($revealed) === 3 && count(array_unique(array_column($revealed, 'value'))) === 1;
        if (! $isTrio) {
            foreach ($revealed as $card) {
                if ($card['source'] === 'table') {
                    $state['table'][$card['slot']] = $card['value'];
                } else {
                    $state['hands'][$card['ownerSeat'] - 1][$card['slot']] = $card['value'];
                }
            }
        }
        $state['revealed'] = [];
        $state['resolve_at'] = null;
        $state['turn_seat'] = ((int) $state['turn_seat'] % count($state['hands'])) + 1;
        $state['message'] = 'A(z) '.$state['turn_seat'].'. játékos következik.';
        $state['version'] = ((int) ($state['version'] ?? 0)) + 1;
        return $state;
    }
}
