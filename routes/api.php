<?php

use App\Http\Controllers\Api\V1\GameRoomController;
use App\Http\Controllers\Api\V1\GuestAuthController;
use App\Http\Controllers\Api\V1\GoogleAuthController;
use App\Http\Controllers\Api\V1\MatchmakingController;
use App\Http\Controllers\Api\V1\OfflineResultController;
use App\Http\Controllers\Api\V1\PointHistoryController;
use App\Http\Controllers\Api\V1\ProfileController;
use Illuminate\Support\Facades\Route;

Route::prefix('v1')->group(function (): void {
    Route::post('/auth/guest', GuestAuthController::class)->middleware('throttle:10,1');
    Route::post('/auth/google', GoogleAuthController::class)->middleware('throttle:10,1');

    Route::middleware('auth:sanctum')->group(function (): void {
        Route::get('/profile', ProfileController::class);
        Route::get('/points/history', PointHistoryController::class);
        Route::post('/offline-results', OfflineResultController::class);
        Route::post('/rooms', [GameRoomController::class, 'store']);
        Route::get('/rooms/{code}', [GameRoomController::class, 'show']);
        Route::post('/rooms/{code}/join', [GameRoomController::class, 'join']);
        Route::post('/rooms/{code}/play', [GameRoomController::class, 'play']);
        Route::delete('/rooms/{code}', [GameRoomController::class, 'destroy']);
        Route::post('/matchmaking', [MatchmakingController::class, 'store']);
        Route::get('/matchmaking', [MatchmakingController::class, 'show']);
        Route::delete('/matchmaking', [MatchmakingController::class, 'destroy']);
    });
});
