<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;

use App\Models\Telemetry;
use App\Models\Device;

class TelemetryController extends Controller
{
    public function store(Request $request)
    {
        $request->validate([
            'mac_address' => 'required|string',
            'user_id' => 'required|exists:users,id',
            'uv_index' => 'nullable|numeric',
            'temperature' => 'nullable|numeric',
            'humidity' => 'nullable|numeric',
            'voc' => 'nullable|integer',
            'latitude' => 'nullable|numeric',
            'longitude' => 'nullable|numeric',
        ]);

        $device = Device::firstOrCreate(
            ['mac_address' => $request->mac_address],
            ['user_id' => $request->user_id, 'name' => 'Klimo Device']
        );

        $telemetry = Telemetry::create([
            'device_id' => $device->id,
            'user_id' => $request->user_id,
            'uv_index' => $request->uv_index,
            'temperature' => $request->temperature,
            'humidity' => $request->humidity,
            'voc' => $request->voc,
            'latitude' => $request->latitude,
            'longitude' => $request->longitude,
        ]);

        return response()->json([
            'message' => 'Telemetry saved',
            'data' => $telemetry
        ], 201);
    }

    public function heatmap()
    {
        $telemetries = Telemetry::whereNotNull('latitude')
            ->whereNotNull('longitude')
            ->orderBy('created_at', 'desc')
            ->limit(100)
            ->get();

        return response()->json([
            'data' => $telemetries
        ]);
    }

    public function latest(Request $request)
    {
        $userId = $request->user()?->id ?? 1;
        
        $telemetry = Telemetry::where('user_id', $userId)
            ->orderBy('created_at', 'desc')
            ->first();

        return response()->json([
            'data' => $telemetry
        ]);
    }

    public function history(Request $request)
    {
        $userId = $request->user()?->id ?? 1;

        // Ambil 50 data terakhir untuk riwayat & grafik
        $history = Telemetry::where('user_id', $userId)
            ->orderBy('created_at', 'desc')
            ->limit(50)
            ->get();

        return response()->json([
            'data' => $history
        ]);
    }

    public function devices(Request $request)
    {
        $userId = $request->user()?->id ?? 1;
        
        $devices = Device::where('user_id', $userId)->get();

        return response()->json([
            'data' => $devices
        ]);
    }
}
