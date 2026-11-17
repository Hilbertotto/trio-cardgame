<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Resources\UserResource;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;

class GuestAuthController extends Controller
{
    /**
     * Handle the incoming request.
     */
    public function __invoke(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'name' => ['required', 'string', 'min:2', 'max:30'],
            'device_name' => ['required', 'string', 'max:100'],
        ]);

        $identifier = Str::lower((string) Str::uuid());
        $user = User::query()->create([
            'name' => $validated['name'],
            'email' => $identifier.'@guest.trio.local',
            'password' => Hash::make(Str::random(64)),
            'is_guest' => true,
            'avatar_id' => random_int(1, 40),
        ]);
        $user->refresh();

        return response()->json([
            'token' => $user->createToken($validated['device_name'])->plainTextToken,
            'player' => new UserResource($user),
        ], 201);
    }
}
