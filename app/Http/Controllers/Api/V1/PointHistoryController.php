<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Resources\PointTransactionResource;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;

class PointHistoryController extends Controller
{
    /**
     * Handle the incoming request.
     */
    public function __invoke(Request $request): AnonymousResourceCollection
    {
        $transactions = $request->user()
            ->pointTransactions()
            ->with('gameRoom')
            ->latest('id')
            ->paginate(25);

        return PointTransactionResource::collection($transactions);
    }
}
