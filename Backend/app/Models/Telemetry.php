<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Telemetry extends Model
{
    protected $fillable = [
        'device_id',
        'user_id',
        'uv_index',
        'temperature',
        'humidity',
        'voc',
        'latitude',
        'longitude',
    ];

    protected $appends = ['mac_address'];

    public function getMacAddressAttribute()
    {
        return $this->device?->mac_address ?? 'KLIMO-DEV';
    }

    public function device()
    {
        return $this->belongsTo(Device::class);
    }

    public function user()
    {
        return $this->belongsTo(User::class);
    }
}
