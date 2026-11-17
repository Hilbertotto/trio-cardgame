<?php

namespace App\Models;

use Database\Factories\MatchmakingEntryFactory;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class MatchmakingEntry extends Model
{
    /** @use HasFactory<MatchmakingEntryFactory> */
    use HasFactory;

    protected $fillable = ['user_id', 'game_room_id', 'player_count', 'status'];

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function gameRoom(): BelongsTo
    {
        return $this->belongsTo(GameRoom::class);
    }
}
