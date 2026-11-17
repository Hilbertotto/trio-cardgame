<?php

namespace App\Http\Resources;

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
        return [
            'code' => $this->code,
            'status' => $this->status,
            'player_count' => $this->player_count,
            'players' => UserResource::collection($this->whenLoaded('players')),
            'seats' => $this->whenLoaded('players', fn () => $this->players->map(fn ($player): array => [
                'player_id' => $player->id,
                'seat' => $player->pivot->seat,
                'is_ready' => (bool) $player->pivot->is_ready,
            ])),
        ];
    }
}
