<?php

namespace App\Http\Resources;

use Carbon\CarbonImmutable;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class GameRoomResource extends JsonResource
{
    /**
     * Transform the resource into an array.
     *
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        $mySeat = $this->relationLoaded('players')
            ? (int) ($this->players->firstWhere('id', $request->user()?->id)?->pivot->seat ?? 0)
            : 0;
        $state = $this->state ?? [];
        $botSeats = array_map('intval', $state['bot_seats'] ?? []);
        $isMyTurn = $mySeat > 0 && (int) ($state['turn_seat'] ?? 0) === $mySeat;
        $timeoutRemaining = null;
        if ($isMyTurn && ! in_array($mySeat, $botSeats, true) && ! empty($state['turn_started_at'])) {
            $startedAt = CarbonImmutable::parse($state['turn_started_at']);
            $warningAt = $startedAt->addSeconds(30);
            $disconnectAt = $startedAt->addSeconds(40);
            if (now()->greaterThanOrEqualTo($warningAt) && now()->lessThan($disconnectAt)) {
                $timeoutRemaining = max(1, $disconnectAt->getTimestamp() - now()->getTimestamp());
            }
        }

        return [
            'code' => $this->code,
            'status' => $this->status,
            'player_count' => $this->player_count,
            'state' => $this->state,
            'my_seat' => $this->whenLoaded('players', fn () => $mySeat),
            // Ezek személyre szabott mezők: másik játékos nem kapja meg a figyelmeztetést.
            'turn_timeout_remaining' => $timeoutRemaining,
            'forced_disconnect' => $mySeat > 0 && in_array($mySeat, $botSeats, true),
            'players' => UserResource::collection($this->whenLoaded('players')),
            'seats' => $this->whenLoaded('players', fn () => $this->players->map(fn ($player): array => [
                'player_id' => $player->id,
                'seat' => $player->pivot->seat,
                'is_ready' => (bool) $player->pivot->is_ready,
            ])),
        ];
    }
}
