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
            // Minden szabályos lapválasztás újraindítja a játékos idejét.
            $state['turn_started_at'] = now()->toIso8601String();

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
        if ($room->status !== 'playing') {
            return $room;
        }

        return DB::transaction(function () use ($room): GameRoom {
            $locked = GameRoom::query()->with('players')->lockForUpdate()->findOrFail($room->id);
            $state = $this->resolveIfDue($locked->state ?? []);
            $state = $this->replaceTimedOutPlayer($state);
            $state = $this->playBotCard($state);
            if ($state !== $locked->state) {
                $changes = ['state' => $state];
                if (! empty($state['winner_seat'])) {
                    $changes['status'] = 'finished';
                    $changes['finished_at'] = now();
                }
                $locked->update($changes);
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
        $state['turn_started_at'] = now()->toIso8601String();
        $state['bot_next_action_at'] = now()->addSeconds(2)->toIso8601String();
        $state['message'] = 'A(z) '.$state['turn_seat'].'. játékos következik.';
        $state['version'] = ((int) ($state['version'] ?? 0)) + 1;
        return $state;
    }

    private function replaceTimedOutPlayer(array $state): array
    {
        if (! empty($state['resolve_at']) || ! empty($state['winner_seat'])) {
            return $state;
        }

        $seat = (int) ($state['turn_seat'] ?? 0);
        $botSeats = array_map('intval', $state['bot_seats'] ?? []);
        if ($seat < 1 || in_array($seat, $botSeats, true)) {
            return $state;
        }

        $startedAt = $state['turn_started_at'] ?? null;
        if ($startedAt === null) {
            $state['turn_started_at'] = now()->toIso8601String();
            return $state;
        }
        // 90 mp alapidő + 30 mp türelmi idő, csak az érintett kliensnek jelzett.
        if (CarbonImmutable::parse($startedAt)->addSeconds(120)->isFuture()) {
            return $state;
        }

        $botSeats[] = $seat;
        sort($botSeats);
        $state['bot_seats'] = array_values(array_unique($botSeats));
        $state['bot_next_action_at'] = now()->addSeconds(2)->toIso8601String();
        $state['message'] = "A(z) {$seat}. játékos ideje lejárt — a gép folytatja helyette.";
        $state['version'] = ((int) ($state['version'] ?? 0)) + 1;

        $humanSeats = array_values(array_diff(
            range(1, count($state['hands'] ?? [])),
            $state['bot_seats'],
        ));
        if (count($humanSeats) === 1) {
            $winnerSeat = (int) $humanSeats[0];
            $state['winner_seat'] = $winnerSeat;
            $state['message'] = "A(z) {$winnerSeat}. játékos nyert, mert ő maradt az egyetlen aktív játékos.";
        }

        return $state;
    }

    private function playBotCard(array $state): array
    {
        $seat = (int) ($state['turn_seat'] ?? 0);
        if (! in_array($seat, array_map('intval', $state['bot_seats'] ?? []), true)
            || ! empty($state['resolve_at'])
            || ! empty($state['winner_seat'])) {
            return $state;
        }

        $nextActionAt = $state['bot_next_action_at'] ?? null;
        if ($nextActionAt !== null && CarbonImmutable::parse($nextActionAt)->isFuture()) {
            return $state;
        }

        $choices = $this->availableChoices($state);
        if ($choices === []) {
            return $state;
        }

        // A szerveres bot sem használhatja a rejtett lapok értékét a
        // döntéshez: kizárólag a szabályos helyek közül sorsol.
        $choice = $choices[array_rand($choices)];

        if ($choice['source'] === 'table') {
            $state['table'][$choice['slot']] = null;
        } else {
            $state['hands'][$choice['ownerSeat'] - 1][$choice['slot']] = null;
        }
        $state['revealed'][] = $choice;
        $state['bot_next_action_at'] = now()->addSeconds(2)->toIso8601String();
        $values = array_column($state['revealed'], 'value');
        $state['version'] = ((int) ($state['version'] ?? 0)) + 1;

        if (count($values) > 1 && count(array_unique($values)) > 1) {
            $state['message'] = 'A gép lapjai nem egyeznek — 2 másodperc múlva folytatjuk.';
            $state['resolve_at'] = now()->addSeconds(2)->toIso8601String();
        } elseif (count($values) === 3) {
            $value = $values[0];
            $state['trios'][$seat - 1][] = $value;
            $won = $value === 7 || count($state['trios'][$seat - 1]) >= 3;
            if ($won) {
                $state['winner_seat'] = $seat;
                $state['message'] = "A(z) {$seat}. játékos helyén játszó gép megnyerte a játékot!";
            } else {
                $state['message'] = "TRIO! A gép megszerezte a(z) {$value}-es hármast.";
                $state['resolve_at'] = now()->addSeconds(2)->toIso8601String();
            }
        } else {
            $state['message'] = 'A gép választott.';
        }

        return $state;
    }

    /** @return array<int, array{source: string, ownerSeat: int, slot: int, value: int}> */
    private function availableChoices(array $state): array
    {
        $choices = [];
        foreach ($state['table'] ?? [] as $slot => $value) {
            if ($value !== null) {
                $choices[] = ['source' => 'table', 'ownerSeat' => 0, 'slot' => $slot, 'value' => $value];
            }
        }
        foreach ($state['hands'] ?? [] as $handIndex => $hand) {
            $liveSlots = array_keys(array_filter($hand, fn ($value) => $value !== null));
            foreach (array_unique($liveSlots === [] ? [] : [min($liveSlots), max($liveSlots)]) as $slot) {
                $choices[] = [
                    'source' => 'hand',
                    'ownerSeat' => $handIndex + 1,
                    'slot' => $slot,
                    'value' => $hand[$slot],
                ];
            }
        }

        return $choices;
    }
}
