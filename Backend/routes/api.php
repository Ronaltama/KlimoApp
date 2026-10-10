<?php

use App\Http\Controllers\Api\AuthController;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;

use App\Http\Controllers\Api\TelemetryController;

// Public Auth Routes
Route::post('/register', [AuthController::class, 'register']);
Route::post('/login', [AuthController::class, 'login'])->name('login');

// IoT & Telemetry Routes (Accessible for demo & app live stream)
Route::post('/telemetry', [TelemetryController::class, 'store']);
Route::get('/telemetry/latest', [TelemetryController::class, 'latest']);
Route::get('/telemetry/history', [TelemetryController::class, 'history']);
Route::get('/map/heatmap', [TelemetryController::class, 'heatmap']);
Route::get('/devices', [TelemetryController::class, 'devices']);

// Protected User Routes
Route::middleware('auth:sanctum')->group(function () {
    Route::get('/user', function (Request $request) {
        return $request->user();
    });
    Route::get('/profile', [AuthController::class, 'profile']);
    Route::put('/profile', [AuthController::class, 'updateProfile']);
    Route::post('/logout', [AuthController::class, 'logout']);
});
