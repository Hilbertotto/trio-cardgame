<?php

use Illuminate\Support\Facades\Broadcast;

Broadcast::channel('App.Models.User.{id}', function ($user, $id) {
    return (int) $user->id === (int) $id;
});

Broadcast::channel('room.{roomCode}', function ($user, string $roomCode): bool {
    return $user->gameRooms()->where('code', mb_strtoupper($roomCode))->exists();
});
