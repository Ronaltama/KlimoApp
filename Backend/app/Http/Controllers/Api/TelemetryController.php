<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;

use App\Models\Telemetry;
use App\Models\Device;

class TelemetryController extends Controller
{
    /**
     * Menyimpan data sensor hanya saat terjadi perubahan signifikan (Delta Threshold)
     * atau saat mencapai batas Heartbeat (5 menit) untuk efisiensi basis data.
     */
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

        // Ambil rekaman telemetri terakhir dari perangkat ini
        $last = Telemetry::where('device_id', $device->id)
            ->latest('id')
            ->first();

        $shouldSave = false;
        $reason = 'initial';

        if (!$last) {
            // Data pertama kali untuk perangkat ini wajib disimpan
            $shouldSave = true;
            $reason = 'first_record';
        } else {
            // 1. Cek Heartbeat: jika sudah 5 menit (300 detik) tidak ada data baru, simpan sebagai checkpoint
            $secondsSinceLast = now()->diffInSeconds($last->created_at);
            if ($secondsSinceLast >= 300) {
                $shouldSave = true;
                $reason = 'heartbeat';
            } else {
                // 2. Cek Ambang Batas Perubahan (Delta Threshold)
                $uvDiff   = abs((float)($request->uv_index ?? 0) - (float)($last->uv_index ?? 0));
                $tempDiff = abs((float)($request->temperature ?? 0) - (float)($last->temperature ?? 0));
                $humDiff  = abs((float)($request->humidity ?? 0) - (float)($last->humidity ?? 0));
                $vocDiff  = abs((int)($request->voc ?? 0) - (int)($last->voc ?? 0));

                $latDiff  = abs((float)($request->latitude ?? 0) - (float)($last->latitude ?? 0));
                $lngDiff  = abs((float)($request->longitude ?? 0) - (float)($last->longitude ?? 0));

                // Kriteria perubahan:
                // - UV Index berubah >= 0.2
                // - Suhu berubah >= 0.3 °C
                // - Kelembaban berubah >= 1.0 %
                // - Gas VOC berubah >= 10 index
                // - Lokasi GPS berpindah >= ~11 meter (0.0001 derajat)
                if (
                    $uvDiff >= 0.2 ||
                    $tempDiff >= 0.3 ||
                    $humDiff >= 1.0 ||
                    $vocDiff >= 10 ||
                    $latDiff >= 0.0001 ||
                    $lngDiff >= 0.0001
                ) {
                    $shouldSave = true;
                    $reason = 'value_changed';
                }
            }
        }

        if ($shouldSave) {
            $telemetry = new Telemetry([
                'device_id'   => $device->id,
                'user_id'     => $request->user_id,
                'uv_index'    => $request->uv_index,
                'temperature' => $request->temperature,
                'humidity'    => $request->humidity,
                'voc'         => $request->voc,
                'latitude'    => $request->latitude,
                'longitude'   => $request->longitude,
            ]);

            // Jika HP mengirim timestamp perekaman saat offline, gunakan timestamp tersebut
            if ($request->filled('timestamp') || $request->filled('recorded_at')) {
                $telemetry->created_at = $request->input('timestamp') ?? $request->input('recorded_at');
            }

            $telemetry->save();

            return response()->json([
                'status'  => 'saved',
                'reason'  => $reason,
                'message' => 'Telemetry disimpan ke database (terdeteksi perubahan nilai atau checkpoint heartbeat)',
                'data'    => $telemetry
            ], 201);
        }

        // Jika tidak ada perubahan signifikan, kembalikan response sukses tanpa menambah baris di database
        return response()->json([
            'status'  => 'unchanged',
            'reason'  => 'delta_below_threshold',
            'message' => 'Data sensor stabil / tidak berubah signifikan. Baris database dilewati untuk efisiensi penyimpanan.',
            'data'    => $last
        ], 200);
    }

    /**
     * Sinkronisasi kumpulan data offline sekaligus dari HP (Batch Sync)
     */
    public function batchStore(Request $request)
    {
        $request->validate([
            'readings' => 'required|array',
            'readings.*.mac_address' => 'required|string',
            'readings.*.user_id' => 'required|exists:users,id',
            'readings.*.uv_index' => 'nullable|numeric',
            'readings.*.temperature' => 'nullable|numeric',
            'readings.*.humidity' => 'nullable|numeric',
            'readings.*.voc' => 'nullable|integer',
            'readings.*.latitude' => 'nullable|numeric',
            'readings.*.longitude' => 'nullable|numeric',
            'readings.*.timestamp' => 'nullable|string',
        ]);

        $savedCount = 0;
        foreach ($request->readings as $item) {
            $device = Device::firstOrCreate(
                ['mac_address' => $item['mac_address']],
                ['user_id' => $item['user_id'], 'name' => 'Klimo Device']
            );

            $telemetry = new Telemetry([
                'device_id'   => $device->id,
                'user_id'     => $item['user_id'],
                'uv_index'    => $item['uv_index'] ?? null,
                'temperature' => $item['temperature'] ?? null,
                'humidity'    => $item['humidity'] ?? null,
                'voc'         => $item['voc'] ?? null,
                'latitude'    => $item['latitude'] ?? null,
                'longitude'   => $item['longitude'] ?? null,
            ]);

            if (!empty($item['timestamp'])) {
                $telemetry->created_at = $item['timestamp'];
            }

            $telemetry->save();
            $savedCount++;
        }

        return response()->json([
            'status' => 'success',
            'message' => "Berhasil menyinkronkan $savedCount data telemetri offline.",
            'synced_count' => $savedCount
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

        // Fallback jika user ini belum punya data, ambil data telemetri terbaru di sistem (untuk kemudahan demo)
        if (!$telemetry) {
            $telemetry = Telemetry::orderBy('created_at', 'desc')->first();
        }

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

        if ($history->isEmpty()) {
            $history = Telemetry::orderBy('created_at', 'desc')->limit(50)->get();
        }

        return response()->json([
            'data' => $history
        ]);
    }

    public function devices(Request $request)
    {
        $userId = $request->user()?->id ?? 1;
        
        $devices = Device::where('user_id', $userId)->get();

        if ($devices->isEmpty()) {
            $devices = Device::all();
        }

        return response()->json([
            'data' => $devices
        ]);
    }
}
