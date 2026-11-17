<?php

namespace App\Actions;

use App\Models\GameRoom;

class StartGameRoomAction
{
    public function handle(GameRoom $room): GameRoom
    {
        $room->load('players');
        if ($room->status !== 'waiting' || $room->players->count() < $room->player_count) {
            return $room;
        }

        $deal = [3 => [9, 9], 4 => [7, 8], 5 => [6, 6], 6 => [5, 6]][$room->player_count];
        $deck = [];
        foreach (range(1, 12) as $value) {
            array_push($deck, $value, $value, $value);
        }
        shuffle($deck);

        $hands = [];
        foreach (range(1, $room->player_count) as $seat) {
            $hand = array_splice($deck, 0, $deal[0]);
            sort($hand);
            $hands[] = $hand;
        }

        $room->update([
            'status' => 'playing',
            'started_at' => now(),
            'state' => [
                'version' => 1,
                'turn_seat' => 1,
                'hands' => $hands,
                'table' => array_splice($deck, 0, $deal[1]),
                'revealed' => [],
                'trios' => array_fill(0, $room->player_count, []),
                'message' => 'Az 1. játékos következik.',
                'resolve_at' => null,
                'winner_seat' => null,
            ],
        ]);

        return $room->fresh('players');
    }
}
