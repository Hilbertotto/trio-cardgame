<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table): void {
            $table->unsignedBigInteger('coins')->default(0)->after('points');
        });

        Schema::create('coin_transactions', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->foreignId('game_room_id')->nullable()->constrained()->nullOnDelete();
            $table->string('type', 40);
            $table->integer('amount');
            $table->unsignedBigInteger('balance_after');
            $table->json('metadata')->nullable();
            $table->timestamps();
            $table->unique(['user_id', 'game_room_id', 'type']);
            $table->index(['user_id', 'created_at']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('coin_transactions');
        Schema::table('users', function (Blueprint $table): void {
            $table->dropColumn('coins');
        });
    }
};
