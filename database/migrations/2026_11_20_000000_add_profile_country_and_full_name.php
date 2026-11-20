<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->string('full_name', 255)->nullable();
            $table->char('country_code', 2)->nullable()->index();
        });
        \Illuminate\Support\Facades\DB::table('users')->update(['full_name' => \Illuminate\Support\Facades\DB::raw('name')]);
    }
    public function down(): void
    {
        Schema::table('users', fn (Blueprint $table) => $table->dropColumn(['full_name', 'country_code']));
    }
};
