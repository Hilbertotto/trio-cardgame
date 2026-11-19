<?php

return [
    'points' => [
        'completed_game' => (int) env('TRIO_POINTS_COMPLETED_GAME', 20),
        'winner_bonus' => (int) env('TRIO_POINTS_WINNER_BONUS', 100),
    ],
    'coins' => [
        'winner' => [3 => 100, 4 => 120, 5 => 140, 6 => 160],
    ],
];
