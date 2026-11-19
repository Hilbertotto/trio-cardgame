<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class CoinTransaction extends Model
{
    protected $fillable = ['user_id', 'game_room_id', 'type', 'amount', 'balance_after', 'metadata'];

    protected function casts(): array
    {
        return ['amount' => 'integer', 'balance_after' => 'integer', 'metadata' => 'array'];
    }

    public function user(): BelongsTo { return $this->belongsTo(User::class); }
    public function gameRoom(): BelongsTo { return $this->belongsTo(GameRoom::class); }
}
