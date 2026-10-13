<?php

namespace Tests\Feature;

use App\Models\User;
use App\Models\Device;
use App\Models\Telemetry;
use Illuminate\Foundation\Testing\DatabaseTransactions;
use Tests\TestCase;

class KlimoApiTest extends TestCase
{
    use DatabaseTransactions;

    public function test_user_can_register_successfully(): void
    {
        $response = $this->postJson('/api/register', [
            'name' => 'Budi Santoso',
            'email' => 'budi@klimo.app',
            'password' => 'secret123',
        ]);

        $response->assertStatus(201)
            ->assertJsonStructure([
                'status',
                'message',
                'data' => [
                    'user' => ['id', 'name', 'email'],
                    'token',
                ],
            ]);

        $this->assertDatabaseHas('users', [
            'email' => 'budi@klimo.app',
        ]);
    }

    public function test_registration_validation_fails_on_duplicate_email(): void
    {
        User::factory()->create([
            'email' => 'duplicate@klimo.app',
        ]);

        $response = $this->postJson('/api/register', [
            'name' => 'Duplicate User',
            'email' => 'duplicate@klimo.app',
            'password' => 'secret123',
        ]);

        $response->assertStatus(422)
            ->assertJsonValidationErrors(['email']);
    }

    public function test_registration_validation_fails_on_short_password(): void
    {
        $response = $this->postJson('/api/register', [
            'name' => 'Short Pass',
            'email' => 'short@klimo.app',
            'password' => '123',
        ]);

        $response->assertStatus(422)
            ->assertJsonValidationErrors(['password']);
    }

    public function test_user_can_login_successfully(): void
    {
        $user = User::factory()->create([
            'email' => 'login@klimo.app',
            'password' => bcrypt('password123'),
        ]);

        $response = $this->postJson('/api/login', [
            'email' => 'login@klimo.app',
            'password' => 'password123',
        ]);

        $response->assertStatus(200)
            ->assertJsonStructure([
                'status',
                'message',
                'data' => [
                    'user' => ['id', 'name', 'email'],
                    'token',
                ],
            ]);
    }

    public function test_login_fails_with_invalid_credentials(): void
    {
        User::factory()->create([
            'email' => 'valid@klimo.app',
            'password' => bcrypt('correct_password'),
        ]);

        $response = $this->postJson('/api/login', [
            'email' => 'valid@klimo.app',
            'password' => 'wrong_password',
        ]);

        $response->assertStatus(422)
            ->assertJsonValidationErrors(['email']);
    }

    public function test_authenticated_user_can_get_profile(): void
    {
        $user = User::factory()->create(['name' => 'Profile User']);
        $token = $user->createToken('test_token')->plainTextToken;

        $response = $this->withHeader('Authorization', "Bearer $token")
            ->getJson('/api/profile');

        $response->assertStatus(200)
            ->assertJson([
                'status' => 'success',
                'data' => [
                    'id' => $user->id,
                    'name' => 'Profile User',
                ],
            ]);
    }

    public function test_authenticated_user_can_update_profile(): void
    {
        $user = User::factory()->create(['name' => 'Old Name']);
        $token = $user->createToken('test_token')->plainTextToken;

        $response = $this->withHeader('Authorization', "Bearer $token")
            ->putJson('/api/profile', [
                'name' => 'New Name',
            ]);

        $response->assertStatus(200)
            ->assertJson([
                'status' => 'success',
                'data' => [
                    'name' => 'New Name',
                ],
            ]);

        $this->assertDatabaseHas('users', [
            'id' => $user->id,
            'name' => 'New Name',
        ]);
    }

    public function test_authenticated_user_can_logout(): void
    {
        $user = User::factory()->create();
        $token = $user->createToken('test_token')->plainTextToken;

        $response = $this->withHeader('Authorization', "Bearer $token")
            ->postJson('/api/logout');

        $response->assertStatus(200)
            ->assertJson(['status' => 'success']);

        $this->assertCount(0, $user->fresh()->tokens);
    }

    public function test_store_telemetry_with_delta_threshold(): void
    {
        $user = User::factory()->create();

        // 1. Initial record
        $response1 = $this->postJson('/api/telemetry', [
            'mac_address' => 'AA:BB:CC:DD:EE:01',
            'user_id' => $user->id,
            'uv_index' => 2.5,
            'temperature' => 28.0,
            'humidity' => 60.0,
            'voc' => 50,
            'latitude' => -6.2000,
            'longitude' => 106.8166,
        ]);

        $response1->assertStatus(201)
            ->assertJson(['status' => 'saved']);

        // 2. Unchanged record (small diff below threshold)
        $response2 = $this->postJson('/api/telemetry', [
            'mac_address' => 'AA:BB:CC:DD:EE:01',
            'user_id' => $user->id,
            'uv_index' => 2.55,
            'temperature' => 28.1,
            'humidity' => 60.2,
            'voc' => 52,
            'latitude' => -6.2000,
            'longitude' => 106.8166,
        ]);

        $response2->assertStatus(200)
            ->assertJson(['status' => 'unchanged']);

        // 3. Significant change
        $response3 = $this->postJson('/api/telemetry', [
            'mac_address' => 'AA:BB:CC:DD:EE:01',
            'user_id' => $user->id,
            'uv_index' => 5.0, // UV changed by 2.45
            'temperature' => 31.0,
            'humidity' => 55.0,
            'voc' => 100,
            'latitude' => -6.2000,
            'longitude' => 106.8166,
        ]);

        $response3->assertStatus(201)
            ->assertJson(['status' => 'saved']);
    }

    public function test_batch_store_telemetry(): void
    {
        $user = User::factory()->create();

        $initialCount = Telemetry::count();
        $response = $this->postJson('/api/telemetry/batch', [
            'readings' => [
                [
                    'mac_address' => 'AA:BB:CC:01',
                    'user_id' => $user->id,
                    'uv_index' => 3.1,
                    'temperature' => 29.5,
                    'humidity' => 62.0,
                    'voc' => 65,
                    'latitude' => -6.2001,
                    'longitude' => 106.8167,
                    'timestamp' => '2026-10-13T10:00:00Z',
                ],
                [
                    'mac_address' => 'AA:BB:CC:01',
                    'user_id' => $user->id,
                    'uv_index' => 4.2,
                    'temperature' => 30.1,
                    'humidity' => 59.0,
                    'voc' => 75,
                    'latitude' => -6.2002,
                    'longitude' => 106.8168,
                    'timestamp' => '2026-10-13T10:05:00Z',
                ],
            ],
        ]);

        $response->assertStatus(201)
            ->assertJson([
                'status' => 'success',
                'synced_count' => 2,
            ]);

        $this->assertEquals($initialCount + 2, Telemetry::count());
    }

    public function test_get_heatmap_data(): void
    {
        $user = User::factory()->create();
        $device = Device::create([
            'user_id' => $user->id,
            'mac_address' => 'KLIMO-DEV-01',
            'name' => 'Klimo Wearth',
        ]);

        Telemetry::create([
            'device_id' => $device->id,
            'user_id' => $user->id,
            'uv_index' => 2.8,
            'temperature' => 29.0,
            'humidity' => 65.0,
            'voc' => 70,
            'latitude' => -6.2000,
            'longitude' => 106.8166,
        ]);

        $response = $this->getJson('/api/map/heatmap');

        $response->assertStatus(200)
            ->assertJsonStructure([
                'data' => [
                    '*' => ['id', 'uv_index', 'temperature', 'latitude', 'longitude'],
                ],
            ]);
    }

    public function test_user_can_register_with_skin_type(): void
    {
        $response = $this->postJson('/api/register', [
            'name' => 'Siti Nurhaliza',
            'email' => 'siti@klimo.app',
            'password' => 'secret123',
            'skin_type' => 'Tipe II',
        ]);

        $response->assertStatus(201)
            ->assertJson([
                'status' => 'success',
                'data' => [
                    'user' => [
                        'name' => 'Siti Nurhaliza',
                        'email' => 'siti@klimo.app',
                        'skin_type' => 'Tipe II',
                    ],
                ],
            ]);

        $this->assertDatabaseHas('users', [
            'email' => 'siti@klimo.app',
            'skin_type' => 'Tipe II',
        ]);
    }

    public function test_user_can_login_via_google_endpoint(): void
    {
        $response = $this->postJson('/api/login/google', [
            'email' => 'google.user@klimo.app',
            'name' => 'Google Tester',
        ]);

        $response->assertStatus(200)
            ->assertJsonStructure([
                'status',
                'data' => [
                    'user' => ['id', 'name', 'email', 'skin_type'],
                    'token',
                ],
            ]);

        $this->assertDatabaseHas('users', [
            'email' => 'google.user@klimo.app',
        ]);
    }

    public function test_user_can_update_profile_skin_type(): void
    {
        $user = User::factory()->create(['skin_type' => 'Tipe I']);
        $token = $user->createToken('test_token')->plainTextToken;

        $response = $this->withHeader('Authorization', "Bearer $token")
            ->putJson('/api/profile', [
                'skin_type' => 'Tipe III',
            ]);

        $response->assertStatus(200)
            ->assertJson([
                'status' => 'success',
                'data' => [
                    'skin_type' => 'Tipe III',
                ],
            ]);

        $this->assertDatabaseHas('users', [
            'id' => $user->id,
            'skin_type' => 'Tipe III',
        ]);
    }

    public function test_user_can_store_and_link_device(): void
    {
        $user = User::factory()->create();
        $token = $user->createToken('test_token')->plainTextToken;

        $response = $this->withHeader('Authorization', "Bearer $token")
            ->postJson('/api/devices', [
                'mac_address' => 'KLIMO-NEW-MAC',
                'name' => 'Klimo Wearth C3-4A1B',
            ]);

        $response->assertStatus(201)
            ->assertJson([
                'status' => 'success',
                'data' => [
                    'mac_address' => 'KLIMO-NEW-MAC',
                    'name' => 'Klimo Wearth C3-4A1B',
                    'user_id' => $user->id,
                ],
            ]);

        $this->assertDatabaseHas('devices', [
            'mac_address' => 'KLIMO-NEW-MAC',
            'user_id' => $user->id,
        ]);
    }

    public function test_telemetry_includes_mac_address_accessor(): void
    {
        $user = User::factory()->create();
        $device = Device::create([
            'user_id' => $user->id,
            'mac_address' => 'KLIMO-MAC-ACCESSOR',
            'name' => 'Klimo Device',
        ]);

        $telemetry = Telemetry::create([
            'device_id' => $device->id,
            'user_id' => $user->id,
            'uv_index' => 1.5,
            'temperature' => 27.5,
            'humidity' => 60.0,
            'voc' => 45,
            'latitude' => -6.2000,
            'longitude' => 106.8166,
        ]);

        $array = $telemetry->toArray();
        $this->assertArrayHasKey('mac_address', $array);
        $this->assertEquals('KLIMO-MAC-ACCESSOR', $array['mac_address']);
    }
}
