<?php

return [
    'points' => [
        'completed_game' => (int) env('TRIO_POINTS_COMPLETED_GAME', 20),
        'winner_bonus' => (int) env('TRIO_POINTS_WINNER_BONUS', 100),
    ],
];
