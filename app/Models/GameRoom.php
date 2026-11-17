<?php

namespace App\Models;

use Database\Factories\GameRoomFactory;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\BelongsToMany;
use Illuminate\Database\Eloquent\Relations\HasMany;

class GameRoom extends Model
{
    /** @use HasFactory<GameRoomFactory> */
    use HasFactory;

    protected $fillable = [
        'code',
        'host_id',
        'player_count',
        'status',
        'state',
        'started_at',
        'finished_at',
    ];

    protected function casts(): array
    {
        return [
            'state' => 'array',
            'started_at' => 'datetime',
            'finished_at' => 'datetime',
        ];
    }

    public function host(): BelongsTo
    {
        return $this->belongsTo(User::class, 'host_id');
    }

    public function players(): BelongsToMany
    {
        return $this->belongsToMany(User::class)
            ->withPivot(['seat', 'is_ready'])
            ->withTimestamps()
            ->orderByPivot('seat');
    }

    public function pointTransactions(): HasMany
    {
        return $this->hasMany(PointTransaction::class);
    }
}
