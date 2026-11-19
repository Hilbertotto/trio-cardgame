import 'dart:convert';

import 'package:http/http.dart' as http;

class TrioApiException implements Exception {
  const TrioApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class TrioRoom {
  const TrioRoom({
    required this.code,
    required this.status,
    required this.playerCount,
    required this.joinedPlayers,
    required this.playerNames,
    required this.playerIds,
    required this.playerAvatarIds,
    required this.seats,
    required this.mySeat,
    required this.forcedDisconnect,
    this.turnTimeoutRemaining,
    this.gameState,
  });

  final String code;
  final String status;
  final int playerCount;
  final int joinedPlayers;
  final List<String> playerNames;
  final List<int> playerIds;
  final List<int> playerAvatarIds;
  final List<int> seats;
  final int mySeat;
  final bool forcedDisconnect;
  final int? turnTimeoutRemaining;
  final Map<String, dynamic>? gameState;

  factory TrioRoom.fromJson(Map<String, dynamic> json) {
    final players = json['players'];
    final rawSeats = json['seats'];
    return TrioRoom(
      code: json['code'] as String? ?? '',
      status: json['status'] as String? ?? 'waiting',
      playerCount: (json['player_count'] as num?)?.toInt() ?? 0,
      joinedPlayers: players is List ? players.length : 0,
      playerNames: players is List
          ? players
                .whereType<Map<String, dynamic>>()
                .map((player) => player['name'] as String? ?? 'Játékos')
                .toList(growable: false)
          : const [],
      playerIds: players is List
          ? players
                .whereType<Map<String, dynamic>>()
                .map((player) => (player['id'] as num?)?.toInt() ?? 0)
                .toList(growable: false)
          : const [],
      playerAvatarIds: players is List
          ? players
                .whereType<Map<String, dynamic>>()
                .map((player) => (player['avatar_id'] as num?)?.toInt() ?? 1)
                .toList(growable: false)
          : const [],
      seats: rawSeats is List
          ? rawSeats
                .whereType<Map<String, dynamic>>()
                .map((seat) => (seat['seat'] as num?)?.toInt() ?? 0)
                .toList(growable: false)
          : const [],
      mySeat: (json['my_seat'] as num?)?.toInt() ?? 0,
      forcedDisconnect: json['forced_disconnect'] as bool? ?? false,
      turnTimeoutRemaining: (json['turn_timeout_remaining'] as num?)?.toInt(),
      gameState: json['state'] is Map<String, dynamic>
          ? json['state'] as Map<String, dynamic>
          : null,
    );
  }
}

class MatchmakingResult {
  const MatchmakingResult({required this.status, this.room});

  final String status;
  final TrioRoom? room;
}

class TrioApi {
  TrioApi({
    this.baseUrl = 'https://trio.solarisminer.com/api/v1',
    http.Client? client,
  }) : _client = client ?? http.Client();

  final String baseUrl;
  final http.Client _client;
  String? _token;
  int? playerId;

  bool get isAuthenticated => _token != null;

  Future<void> createGoogleSession(String idToken) async {
    final response = await _client
        .post(
          Uri.parse('$baseUrl/auth/google'),
          headers: const {'Accept': 'application/json'},
          body: {'id_token': idToken, 'device_name': 'TRIO Android'},
        )
        .timeout(const Duration(seconds: 15));
    final json = _decode(response);
    _token = json['token'] as String?;
    final player = json['player'];
    if (player is Map<String, dynamic>) {
      final data = _resource(player);
      playerId = (data['id'] as num?)?.toInt();
    }
    if (_token == null || _token!.isEmpty) {
      throw const TrioApiException('A szerver nem adott belépési tokent.');
    }
  }

  Future<void> createGuest(String name) async {
    final response = await _client
        .post(
          Uri.parse('$baseUrl/auth/guest'),
          headers: const {'Accept': 'application/json'},
          body: {'name': name.trim(), 'device_name': 'TRIO Android'},
        )
        .timeout(const Duration(seconds: 15));
    final json = _decode(response);
    _token = json['token'] as String?;
    final player = json['player'];
    if (player is Map<String, dynamic>) {
      final data = _resource(player);
      playerId = (data['id'] as num?)?.toInt();
    }
    if (_token == null || _token!.isEmpty) {
      throw const TrioApiException('A szerver nem adott belépési tokent.');
    }
  }

  Future<TrioRoom> createRoom(int playerCount) async {
    final response = await _client
        .post(
          Uri.parse('$baseUrl/rooms'),
          headers: _headers,
          body: jsonEncode({'player_count': playerCount}),
        )
        .timeout(const Duration(seconds: 15));
    return TrioRoom.fromJson(_resource(_decode(response)));
  }

  Future<TrioRoom> joinRoom(String code) async {
    final normalized = code.trim().toUpperCase();
    final response = await _client
        .post(Uri.parse('$baseUrl/rooms/$normalized/join'), headers: _headers)
        .timeout(const Duration(seconds: 15));
    return TrioRoom.fromJson(_resource(_decode(response)));
  }

  Future<TrioRoom> getRoom(String code) async {
    final response = await _client
        .get(Uri.parse('$baseUrl/rooms/$code'), headers: _headers)
        .timeout(const Duration(seconds: 15));
    return TrioRoom.fromJson(_resource(_decode(response)));
  }

  Future<void> leaveRoom(String code) async {
    final response = await _client
        .delete(Uri.parse('$baseUrl/rooms/$code'), headers: _headers)
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 204) _decode(response);
  }

  Future<TrioRoom> playCard(
    String code, {
    required String source,
    required int slot,
    int? ownerSeat,
  }) async {
    final response = await _client
        .post(
          Uri.parse('$baseUrl/rooms/$code/play'),
          headers: _headers,
          body: jsonEncode({
            'source': source,
            'slot': slot,
            if (ownerSeat != null) 'owner_seat': ownerSeat,
          }),
        )
        .timeout(const Duration(seconds: 15));
    return TrioRoom.fromJson(_resource(_decode(response)));
  }

  Future<MatchmakingResult> joinMatchmaking(int playerCount) async {
    final response = await _client
        .post(
          Uri.parse('$baseUrl/matchmaking'),
          headers: _headers,
          body: jsonEncode({'player_count': playerCount}),
        )
        .timeout(const Duration(seconds: 15));
    final json = _decode(response);
    final rawRoom = json['room'];
    final room = rawRoom is Map<String, dynamic>
        ? TrioRoom.fromJson(_resource(rawRoom))
        : null;
    return MatchmakingResult(
      status: json['status'] as String? ?? 'queued',
      room: room,
    );
  }

  Future<MatchmakingResult> getMatchmakingStatus() async {
    final response = await _client
        .get(Uri.parse('$baseUrl/matchmaking'), headers: _headers)
        .timeout(const Duration(seconds: 15));
    final json = _decode(response);
    final rawRoom = json['room'];
    final room = rawRoom is Map<String, dynamic>
        ? TrioRoom.fromJson(_resource(rawRoom))
        : null;
    return MatchmakingResult(
      status: json['status'] as String? ?? 'idle',
      room: room,
    );
  }

  Future<void> leaveMatchmaking() async {
    final response = await _client
        .delete(Uri.parse('$baseUrl/matchmaking'), headers: _headers)
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 204) _decode(response);
  }

  Map<String, String> get _headers {
    final token = _token;
    if (token == null) {
      throw const TrioApiException('Előbb jelentkezz be a szerverre.');
    }
    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Map<String, dynamic> _decode(http.Response response) {
    Map<String, dynamic> json = const {};
    if (response.body.isNotEmpty) {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) json = decoded;
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = json['message'] as String?;
      throw TrioApiException(
        message ?? 'Szerverhiba (${response.statusCode}). Próbáld újra!',
      );
    }
    return json;
  }

  Map<String, dynamic> _resource(Map<String, dynamic> json) {
    final data = json['data'];
    return data is Map<String, dynamic> ? data : json;
  }
}
