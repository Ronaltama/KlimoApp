<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Device extends Model
{
    protected $fillable = [
        'user_id',
        'mac_address',
        'name',
    ];

    public function user()
    {
        return $this->belongsTo(User::class);
    }

    public function telemetries()
    {
        return $this->hasMany(Telemetry::class);
    }
}
