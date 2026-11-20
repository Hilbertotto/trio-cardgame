<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class UserResource extends JsonResource
{
    /**
     * Transform the resource into an array.
     *
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'name' => $this->name,
            'full_name' => $this->full_name ?? $this->name,
            'country_code' => $this->country_code,
            'is_guest' => $this->is_guest,
            'points' => $this->points,
            'coins' => $this->coins,
            'avatar_id' => $this->avatar_id ?? (($this->id - 1) % 40) + 1,
        ];
    }
}
