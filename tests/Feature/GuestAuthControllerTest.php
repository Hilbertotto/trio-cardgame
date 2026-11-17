<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\LazilyRefreshDatabase;
use Tests\TestCase;

class GuestAuthControllerTest extends TestCase
{
    use LazilyRefreshDatabase;

    public function test_valid_payload_creates_guest_and_returns_token_with_zero_points(): void
    {
        $response = $this->postJson('/api/v1/auth/guest', [
            'name' => 'Játékos',
            'device_name' => 'Pixel 9 Pro',
        ]);

        $response
            ->assertCreated()
            ->assertJsonPath('player.name', 'Játékos')
            ->assertJsonPath('player.is_guest', true)
            ->assertJsonPath('player.points', 0)
            ->assertJsonStructure(['token', 'player' => ['id', 'name', 'is_guest', 'points']]);

        $this->assertDatabaseHas('users', ['name' => 'Játékos', 'is_guest' => true, 'points' => 0]);
        $this->assertDatabaseCount('personal_access_tokens', 1);
    }

    public function test_returns_422_when_guest_name_is_missing(): void
    {
        $this->postJson('/api/v1/auth/guest', ['device_name' => 'Pixel 9 Pro'])
            ->assertUnprocessable()
            ->assertJsonValidationErrors('name');
    }
}
