<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Resources\UserResource;
use App\Models\User;
use Google\Client as GoogleClient;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;

class GoogleAuthController extends Controller
{
    public function __invoke(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'id_token' => ['required', 'string'],
            'device_name' => ['required', 'string', 'max:100'],
        ]);

        $clientId = (string) config('services.google.client_id');
        if ($clientId === '') {
            abort(503, 'A Google-belépés még nincs beállítva a szerveren.');
        }

        try {
            $payload = (new GoogleClient(['client_id' => $clientId]))
                ->verifyIdToken($validated['id_token']);
        } catch (\Throwable) {
            throw ValidationException::withMessages([
                'id_token' => 'A Google-azonosítás érvénytelen vagy lejárt.',
            ]);
        }

        if (! is_array($payload)
            || empty($payload['sub'])
            || empty($payload['email'])
            || filter_var($payload['email_verified'] ?? false, FILTER_VALIDATE_BOOLEAN) !== true) {
            throw ValidationException::withMessages([
                'id_token' => 'A Google-azonosítás érvénytelen vagy lejárt.',
            ]);
        }

        $user = User::query()
            ->where('google_sub', $payload['sub'])
            ->orWhere('email', $payload['email'])
            ->first();

        if ($user === null) {
            $user = new User([
                'password' => Hash::make(Str::random(64)),
                'avatar_id' => random_int(1, 40),
            ]);
        }

        $user->fill([
            'google_sub' => $payload['sub'],
            'name' => Str::limit((string) ($payload['name'] ?? 'Játékos'), 30, ''),
            'email' => $payload['email'],
            'is_guest' => false,
        ]);
        $user->email_verified_at ??= now();
        $user->full_name ??= (string) ($payload['name'] ?? $user->name);
        $user->save();

        return response()->json([
            'token' => $user->createToken($validated['device_name'])->plainTextToken,
            'player' => new UserResource($user->fresh()),
        ]);
    }
}
