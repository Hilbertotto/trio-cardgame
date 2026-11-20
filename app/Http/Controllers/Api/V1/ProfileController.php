<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Resources\UserResource;
use Illuminate\Http\Request;

class ProfileController extends Controller
{
    /**
     * Handle the incoming request.
     */
    public function __invoke(Request $request): UserResource
    {
        return new UserResource($request->user());
    }

    public function update(Request $request): UserResource
    {
        $data = $request->validate([
            'full_name' => ['required', 'string', 'max:255'],
            'country_code' => ['required', 'string', 'size:2', 'regex:/^[A-Z]{2}$/'],
        ]);
        $user = $request->user();
        $user->full_name = trim($data['full_name']);
        $user->country_code = $data['country_code'];
        $user->save();
        return new UserResource($user);
    }
}
