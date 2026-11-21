import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'trio_api.dart';
import 'rules_card_demo.dart';
import 'leaderboard_page.dart';

bool isWinningTrio(int trioValue, int trioCount) =>
    trioValue == 7 || trioCount >= 3;

enum BotDifficulty { soft, medium, hard }

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(const TrioApp());
}

class TrioApp extends StatelessWidget {
  const TrioApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData.dark(useMaterial3: true),
    home: const TrioGame(),
  );
}

class P {
  P(this.name, this.bot, this.hand);
  final String name;
  final bool bot;
  final List<int?> hand;
  final List<int> trios = [];
}

class R {
  R(this.value, this.source, this.owner, this.slot);
  final int value, owner, slot;
  final String source;
}

class _RevealFace extends StatelessWidget {
  const _RevealFace({required this.reveal, super.key});

  final R reveal;

  @override
  Widget build(BuildContext context) => Center(
    child: AspectRatio(
      aspectRatio: 245 / 332,
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(7),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(5),
          child: Image.asset(
            'assets/cards_new/${reveal.value}.png',
            fit: BoxFit.contain,
          ),
        ),
      ),
    ),
  );
}

class TrioGame extends StatefulWidget {
  const TrioGame({super.key});
  @override
  State<TrioGame> createState() => _TrioGameState();
}

class _TrioGameState extends State<TrioGame> with TickerProviderStateMixin {
  final random = Random();
  final api = TrioApi();
  static const googleWebClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
    defaultValue:
        '1075466467650-geobj7gpcmglmqbdoag7prghdeinf8mq.apps.googleusercontent.com',
  );
  bool googleSignInInitialized = false;
  GoogleSignInAccount? googleAccount;
  final tableSlotKeys = List<GlobalKey>.generate(12, (_) => GlobalKey());
  final handSlotKeys = List<List<GlobalKey>>.generate(
    6,
    (_) => List<GlobalKey>.generate(12, (_) => GlobalKey()),
  );
  final revealSlotKeys = List<GlobalKey>.generate(3, (_) => GlobalKey());
  int count = 6, turn = 0, turnSerial = 0;
  BotDifficulty botDifficulty = BotDifficulty.soft;
  bool auto = true,
      serverMode = false,
      playing = false,
      showGameOptions = false,
      busy = false,
      gameOver = false,
      boardReady = false;
  String winner = '';
  String? networkRoomCode;
  Timer? networkTimer;
  int? turnTimeoutRemaining;
  int? coins;
  int? gameStartingCoins;
  String? localGameId;
  List<int> networkSeats = [];
  bool networkSyncing = false;
  List<P> ps = [];
  List<int> avatarIds = [];
  List<int?> table = [];
  List<R> shown = [];
  final Map<String, int> botMemory = <String, int>{};
  final Map<String, int> botMemoryTurn = <String, int>{};
  String message = 'Indítsd el a játékot!';
  List<int> live(P p) => [
    for (int i = 0; i < p.hand.length; i++)
      if (p.hand[i] != null) i,
  ];

  String cardMemoryKey(R card) => '${card.source}:${card.owner}:${card.slot}';

  void rememberRevealedCard(R card) {
    if (serverMode || botDifficulty == BotDifficulty.soft) return;
    final key = cardMemoryKey(card);
    botMemory[key] = card.value;
    botMemoryTurn[key] = turnSerial;
  }

  void pruneMediumMemory() {
    if (botDifficulty != BotDifficulty.medium || ps.isEmpty) return;
    final oldestTurn = turnSerial - (2 * ps.length);
    final expired = botMemoryTurn.entries
        .where((entry) => entry.value <= oldestTurn)
        .map((entry) => entry.key)
        .toList();
    for (final key in expired) {
      botMemory.remove(key);
      botMemoryTurn.remove(key);
    }
  }

  R chooseBotCard(List<R> candidates) {
    if (botDifficulty == BotDifficulty.soft) {
      return candidates[random.nextInt(candidates.length)];
    }
    pruneMediumMemory();

    final target = shown.isEmpty ? null : shown.first.value;
    if (target != null) {
      final matches = candidates
          .where((card) => botMemory[cardMemoryKey(card)] == target)
          .toList();
      if (matches.isNotEmpty) return matches[random.nextInt(matches.length)];
    }

    if (botDifficulty == BotDifficulty.hard && shown.isEmpty) {
      final knownGroups = <int, List<R>>{};
      for (final card in candidates) {
        final knownValue = botMemory[cardMemoryKey(card)];
        if (knownValue != null) {
          knownGroups.putIfAbsent(knownValue, () => <R>[]).add(card);
        }
      }
      final usefulGroups =
          knownGroups.entries.where((entry) => entry.value.length >= 2).toList()
            ..sort((a, b) {
              if (a.key == 7 && b.key != 7) return -1;
              if (b.key == 7 && a.key != 7) return 1;
              return b.value.length.compareTo(a.value.length);
            });
      if (usefulGroups.isNotEmpty) return usefulGroups.first.value.first;
    }

    final unknown = candidates
        .where((card) => !botMemory.containsKey(cardMemoryKey(card)))
        .toList();
    final pool = unknown.isNotEmpty ? unknown : candidates;
    return pool[random.nextInt(pool.length)];
  }

  @override
  void initState() {
    super.initState();
    api.restoreSession().then((_) {
      if (mounted) setState(() => coins = api.coins);
      if (api.isAuthenticated) refreshOnlineProfile();
    });
  }

  @override
  void dispose() {
    networkTimer?.cancel();
    super.dispose();
  }

  void startNetworkGame(TrioRoom room) {
    gameStartingCoins = api.coins;
    networkTimer?.cancel();
    networkRoomCode = room.code;
    serverMode = true;
    auto = false;
    applyNetworkRoom(room);
    networkTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      final code = networkRoomCode;
      if (!mounted || !playing || code == null) return;
      try {
        await syncNetworkRoom(await api.getRoom(code));
      } catch (_) {
        // Egy rövid hálózati kimaradás után a következő lekérés újrapróbálja.
      }
    });
  }

  Future<void> refreshOnlineProfile() async {
    if (!api.isAuthenticated) return;
    try {
      await api.refreshProfile();
      if (mounted) setState(() => coins = api.coins);
    } catch (_) {}
  }

  void applyNetworkRoom(TrioRoom room) {
    final state = room.gameState;
    if (!mounted || state == null || room.mySeat < 1) return;
    final wasGameOver = gameOver;
    final previousTrios = ps.fold<int>(0, (sum, player) => sum + player.trios.length);
    final allSeats = room.seats.isNotEmpty
        ? room.seats
        : [for (int i = 1; i <= room.playerCount; i++) i];
    networkSeats = [room.mySeat, ...allSeats.where((s) => s != room.mySeat)];
    final rawHands = state['hands'] as List<dynamic>? ?? const [];
    final rawTrios = state['trios'] as List<dynamic>? ?? const [];
    final botSeats = (state['bot_seats'] as List<dynamic>? ?? const [])
        .map((seat) => (seat as num).toInt())
        .toSet();
    final players = <P>[];
    final networkAvatars = <int>[];
    for (final seat in networkSeats) {
      final playerIndex = allSeats.indexOf(seat);
      final name = playerIndex >= 0 && playerIndex < room.playerNames.length
          ? room.playerNames[playerIndex]
          : 'Játékos $seat';
      final rawHand = seat - 1 < rawHands.length
          ? rawHands[seat - 1] as List<dynamic>
          : const <dynamic>[];
      final player = P(
        botSeats.contains(seat) ? '$name (Gép)' : name,
        botSeats.contains(seat),
        rawHand
            .map<int?>((value) => value == null ? null : (value as num).toInt())
            .toList(),
      );
      networkAvatars.add(
        playerIndex >= 0 && playerIndex < room.playerAvatarIds.length
            ? room.playerAvatarIds[playerIndex]
            : ((seat - 1) % 40) + 1,
      );
      if (seat - 1 < rawTrios.length) {
        player.trios.addAll(
          (rawTrios[seat - 1] as List<dynamic>).map(
            (value) => (value as num).toInt(),
          ),
        );
      }
      players.add(player);
    }
    final rawTable = state['table'] as List<dynamic>? ?? const [];
    final rawRevealed = state['revealed'] as List<dynamic>? ?? const [];
    final serverTurn = (state['turn_seat'] as num?)?.toInt() ?? 1;
    final winnerSeat = (state['winner_seat'] as num?)?.toInt();
    setState(() {
      count = room.playerCount;
      ps = players;
      avatarIds = networkAvatars;
      table = rawTable
          .map<int?>((value) => value == null ? null : (value as num).toInt())
          .toList();
      shown = rawRevealed.whereType<Map<String, dynamic>>().map((card) {
        final ownerSeat = (card['ownerSeat'] as num?)?.toInt() ?? 0;
        return R(
          (card['value'] as num).toInt(),
          card['source'] as String,
          ownerSeat == 0 ? -1 : networkSeats.indexOf(ownerSeat),
          (card['slot'] as num).toInt(),
        );
      }).toList();
      turn = max(0, networkSeats.indexOf(serverTurn));
      busy = state['resolve_at'] != null || botSeats.contains(serverTurn);
      message = state['message'] as String? ?? 'A játék elindult.';
      gameOver = room.status == 'finished' || winnerSeat != null;
      winner = winnerSeat == null
          ? ''
          : ps[max(0, networkSeats.indexOf(winnerSeat))].name;
      playing = true;
      boardReady = true;
      turnTimeoutRemaining = room.turnTimeoutRemaining;
    });
    if (!wasGameOver && gameOver) {
      unawaited(resultVibration(winner: true));
      Future<void>.microtask(refreshOnlineProfile);
    } else if (!gameOver && players.fold<int>(0, (sum, player) => sum + player.trios.length) > previousTrios) {
      unawaited(resultVibration());
    }
  }

  R networkReveal(Map<String, dynamic> card) {
    final ownerSeat = (card['ownerSeat'] as num?)?.toInt() ?? 0;
    return R(
      (card['value'] as num).toInt(),
      card['source'] as String,
      ownerSeat == 0 ? -1 : networkSeats.indexOf(ownerSeat),
      (card['slot'] as num).toInt(),
    );
  }

  Future<void> syncNetworkRoom(TrioRoom room) async {
    if (!mounted || networkSyncing || room.gameState == null) return;
    if (room.forcedDisconnect) {
      networkTimer?.cancel();
      networkRoomCode = null;
      setState(() {
        playing = false;
        turnTimeoutRemaining = null;
      });
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('A kapcsolat megszakadt'),
          content: const Text(
            'Nem választottál a 30 másodperces türelmi idő alatt, ezért a helyedet egy gépi játékos vette át.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Rendben'),
            ),
          ],
        ),
      );
      return;
    }
    networkSyncing = true;
    try {
      final raw = room.gameState!['revealed'] as List<dynamic>? ?? const [];
      if (raw.length > shown.length) {
        for (int index = shown.length; index < raw.length; index++) {
          final card = networkReveal(raw[index] as Map<String, dynamic>);
          final fromKey = sourceKey(card);
          setState(() {
            busy = true;
            if (card.source == 'table') {
              table[card.slot] = null;
            } else if (card.owner >= 0) {
              ps[card.owner].hand[card.slot] = null;
            }
          });
          await flyCard(card.value, fromKey, revealSlotKeys[index]);
          if (!mounted) return;
          setState(() => shown.add(card));
          playCardClick();
          if (shown.length == 3 && shown.every((item) => item.value == shown.first.value)) {
            unawaited(playGameSound('trio'));
          }
        }
      } else if (raw.isEmpty && shown.isNotEmpty) {
        final returning = List<R>.of(shown);
        final isTrio =
            returning.length == 3 &&
            returning.every((card) => card.value == returning.first.value);
        if (!isTrio) {
          setState(() => shown.clear());
          await Future.wait([
            for (int index = 0; index < returning.length; index++)
              flyCard(
                returning[index].value,
                revealSlotKeys[index],
                sourceKey(returning[index]),
              ),
          ]);
          if (!mounted) return;
        }
      }
      applyNetworkRoom(room);
    } finally {
      networkSyncing = false;
    }
  }

  Widget timeoutWarning() {
    final seconds = turnTimeoutRemaining;
    if (seconds == null) return const SizedBox.shrink();
    return Positioned(
      left: 32,
      right: 32,
      top: MediaQuery.paddingOf(context).top + 82,
      child: IgnorePointer(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xffb6203c),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xffffd21f), width: 3),
            boxShadow: const [
              BoxShadow(
                color: Colors.black54,
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Text(
            'Válassz lapot! $seconds mp múlva a gép átveszi a helyed.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> playNetworkCard(String source, int slot, {int? owner}) async {
    final code = networkRoomCode;
    if (code == null || busy || turn != 0 || gameOver) return;
    setState(() => busy = true);
    try {
      final ownerSeat = owner == null ? null : networkSeats[owner];
      await syncNetworkRoom(
        await api.playCard(
          code,
          source: source,
          slot: slot,
          ownerSeat: ownerSeat,
        ),
      );
    } on TrioApiException catch (error) {
      if (mounted)
        setState(() {
          message = error.message;
          busy = false;
        });
    } catch (_) {
      if (mounted)
        setState(() {
          message = 'Nem sikerült elküldeni a lépést.';
          busy = false;
        });
    }
  }

  Rect? slotRect(GlobalKey key, RenderBox overlayBox) {
    final box = key.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return null;
    final topLeft = box.localToGlobal(Offset.zero, ancestor: overlayBox);
    return topLeft & box.size;
  }

  Future<void> flyCard(int value, GlobalKey fromKey, GlobalKey toKey) async {
    final overlay = Overlay.of(context);
    final overlayBox = overlay.context.findRenderObject();
    if (overlayBox is! RenderBox) return;
    final from = slotRect(fromKey, overlayBox);
    final to = slotRect(toKey, overlayBox);
    if (from == null || to == null) return;

    final controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    final curved = CurvedAnimation(
      parent: controller,
      curve: Curves.easeInOutCubic,
    );
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => AnimatedBuilder(
        animation: curved,
        builder: (_, child) {
          final t = curved.value;
          final rect = Rect.lerp(from, to, t)!;
          return Positioned.fromRect(rect: rect, child: child!);
        },
        child: IgnorePointer(child: face(value, w: to.width, framed: false)),
      ),
    );
    overlay.insert(entry);
    await controller.forward();
    entry.remove();
    controller.dispose();
  }

  GlobalKey sourceKey(R r) => r.source == 'table'
      ? tableSlotKeys[r.slot]
      : handSlotKeys[r.owner][r.slot];

  void start() {
    botMemory.clear();
    botMemoryTurn.clear();
    turnSerial = 0;
    localGameId = '${DateTime.now().microsecondsSinceEpoch}-${random.nextInt(1 << 32)}';
    avatarIds = [for (int i = 1; i <= 40; i++) i]..shuffle(random);
    final deck = <int>[
      for (int n = 1; n <= 12; n++) ...<int>[n, n, n],
    ]..shuffle(random);
    final d = {
      3: [9, 9],
      4: [7, 8],
      5: [6, 6],
      6: [5, 6],
    }[count]!;
    ps = List.generate(count, (i) {
      final h = <int?>[...deck.take(d[0])]..sort((a, b) => a!.compareTo(b!));
      deck.removeRange(0, d[0]);
      return P(
        i == 0
            ? (api.isAuthenticated && (api.playerName?.trim().isNotEmpty ?? false)
                ? api.playerName!.trim()
                : 'Játékos 1')
            : (auto ? 'Gép ' + i.toString() : 'Játékos ' + (i + 1).toString()),
        auto && i > 0,
        h,
      );
    });
    table = deck.take(d[1]).map<int?>((e) => e).toList();
    setState(() {
      turn = 0;
      shown = [];
      busy = false;
      gameOver = false;
      winner = '';
      gameStartingCoins = api.coins;
      playing = true;
      boardReady = false;
      message = 'Válassz asztali lapot vagy egy játékos szélső lapját!';
    });
    Future<void>.delayed(const Duration(milliseconds: 450), () {
      if (mounted && playing) setState(() => boardReady = true);
    });
  }

  Future<void> pickTable(int i) async {
    if (serverMode && networkRoomCode != null) {
      playCardClick();
      await playNetworkCard('table', i);
      return;
    }
    if (gameOver || busy || turn != 0 || table[i] == null) return;
    playCardClick();
    final v = table[i]!;
    setState(() {
      busy = true;
      table[i] = null;
    });
    await flyCard(v, tableSlotKeys[i], revealSlotKeys[shown.length]);
    if (!mounted) return;
    setState(() {
      shown.add(R(v, 'table', -1, i));
      rememberRevealedCard(shown.last);
      busy = false;
    });
    resolve();
  }

  Future<void> pickHand(int p, int i) async {
    if (serverMode && networkRoomCode != null) {
      playCardClick();
      await playNetworkCard('hand', i, owner: p);
      return;
    }
    if (gameOver || busy || turn != 0) return;
    final l = live(ps[p]);
    if (l.isEmpty || (i != l.first && i != l.last)) return;
    playCardClick();
    final v = ps[p].hand[i]!;
    setState(() {
      busy = true;
      ps[p].hand[i] = null;
    });
    await flyCard(v, handSlotKeys[p][i], revealSlotKeys[shown.length]);
    if (!mounted) return;
    setState(() {
      shown.add(R(v, 'hand', p, i));
      rememberRevealedCard(shown.last);
      busy = false;
    });
    resolve();
  }

  void playCardClick() {
    unawaited(playGameSound('flip'));
  }

  Future<void> resultVibration({bool winner = false}) async {
    await HapticFeedback.mediumImpact();
    if (winner) {
      await Future<void>.delayed(const Duration(milliseconds: 220));
      if (mounted) await HapticFeedback.mediumImpact();
    }
  }

  Future<void> playGameSound(String sound) async {
    try {
      await const MethodChannel('hu.triogame/sounds').invokeMethod<void>(sound);
    } on PlatformException {
      // Audio must never interrupt gameplay.
    } on MissingPluginException {
      // Native audio is only available on Android.
    }
  }

  Future<void> resolve() async {
    if (shown.length > 1 && shown.last.value != shown.first.value) {
      setState(() {
        busy = true;
        message = 'Nem egyezik — várunk 2 másodpercet.';
      });
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return;
      final returning = List<R>.of(shown);
      final flights = <Future<void>>[
        for (int i = 0; i < returning.length; i++)
          flyCard(
            returning[i].value,
            revealSlotKeys[i],
            sourceKey(returning[i]),
          ),
      ];
      setState(() => shown.clear());
      await Future.wait(flights);
      if (!mounted) return;
      for (final r in returning) {
        if (r.source == 'table')
          table[r.slot] = r.value;
        else
          ps[r.owner].hand[r.slot] = r.value;
      }
      next();
    } else if (shown.length == 3) {
      final v = shown.first.value;
      ps[turn].trios.add(v);
      unawaited(playGameSound('trio'));
      final won = isWinningTrio(v, ps[turn].trios.length);
      unawaited(resultVibration(winner: won));
      setState(() {
        busy = true;
        message = won
            ? ps[turn].name + ' megnyerte a játékot!'
            : 'TRIO! A ' + v.toString() + '-es hármas megvan.';
      });
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return;
      shown.clear();
      if (won) {
        setState(() {
          gameOver = true;
          winner = ps[turn].name;
          busy = true;
        });
        if (!serverMode && turn == 0 && api.isAuthenticated) {
          final gameId = localGameId;
          if (gameId != null) {
            Future<void>.microtask(() async {
              try {
                await api.submitOfflineResult(
                  playerCount: count,
                  won: true,
                  gameId: gameId,
                );
                if (mounted) setState(() => coins = api.coins);
              } catch (_) {}
            });
          }
        }
        return;
      }
      next();
    } else {
      setState(
        () => message =
            'Még ' + (3 - shown.length).toString() + ' azonos lap kell.',
      );
    }
  }

  void next() {
    if (gameOver) return;
    turnSerial++;
    pruneMediumMemory();
    turn = (turn + 1) % ps.length;
    busy = ps[turn].bot;
    setState(
      () => message = busy
          ? ps[turn].name + ' gondolkodik…'
          : 'Te következel — válassz asztali lapot vagy zöld szélső lapot!',
    );
    if (busy) {
      Future<void>.delayed(const Duration(milliseconds: 1400), () {
        if (mounted && playing && !gameOver && ps[turn].bot) botPick();
      });
    }
  }

  Future<void> botPick() async {
    if (!mounted || gameOver || !ps[turn].bot) return;
    final o = <R>[];
    for (int i = 0; i < table.length; i++)
      if (table[i] != null) o.add(R(table[i]!, 'table', -1, i));
    for (int p = 0; p < ps.length; p++) {
      final l = live(ps[p]);
      if (l.isNotEmpty) {
        o.add(R(ps[p].hand[l.first]!, 'hand', p, l.first));
        if (l.last != l.first) o.add(R(ps[p].hand[l.last]!, 'hand', p, l.last));
      }
    }
    if (o.isEmpty) {
      next();
      return;
    }
    // A döntés csak pozíciókat és korábban nyilvánosan felfedett értékeket
    // használ. Ismeretlen lap értéke csak a választás után válik láthatóvá.
    final r = chooseBotCard(o);
    final fromKey = sourceKey(r);
    if (r.source == 'table')
      table[r.slot] = null;
    else
      ps[r.owner].hand[r.slot] = null;
    setState(() => message = ps[turn].name + ' választott.');
    await flyCard(r.value, fromKey, revealSlotKeys[shown.length]);
    if (!mounted || gameOver) return;
    shown.add(r);
    rememberRevealedCard(r);
    setState(() => message = ps[turn].name + ' választott.');
    if ((shown.length > 1 && shown.last.value != shown.first.value) ||
        shown.length == 3) {
      busy = false;
      resolve();
    } else
      Future<void>.delayed(const Duration(milliseconds: 1400), () {
        if (mounted && playing && !gameOver && ps[turn].bot) botPick();
      });
  }

  Widget face(int v, {double w = 42, bool framed = true}) => Container(
    width: w,
    height: w / (245 / 332),
    padding: framed ? const EdgeInsets.all(2) : EdgeInsets.zero,
    decoration: BoxDecoration(
      color: framed ? Colors.white : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Image.asset(
        'assets/cards_new/' + v.toString() + '.png',
        fit: BoxFit.contain,
      ),
    ),
  );
  Widget back({double w = 42, VoidCallback? tap}) => InkWell(
    onTap: tap,
    child: Container(
      width: w,
      height: w / (152 / 271),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(7)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(7),
        child: Image.asset('assets/cards_new/back.png', fit: BoxFit.fill),
      ),
    ),
  );

  Widget revealSlot(int i) => i < shown.length
      ? _RevealFace(reveal: shown[i])
      : const SizedBox.expand();

  void leaveFinishedGame() {
    networkTimer?.cancel();
    networkRoomCode = null;
    setState(() {
      playing = false;
      showGameOptions = false;
    });
  }

  void replayFinishedGame() {
    if (!serverMode) {
      start();
      return;
    }
    networkTimer?.cancel();
    networkRoomCode = null;
    setState(() {
      playing = false;
      showGameOptions = true;
    });
    Future<void>.microtask(openServerLobby);
  }

  Widget victoryOverlay() {
    final winnerIndex = max(
      0,
      ps.indexWhere((player) => player.name == winner),
    );
    final winnerAvatar = winnerIndex < avatarIds.length
        ? avatarIds[winnerIndex]
        : 1;

    return Positioned.fill(
      child: Container(
        color: const Color(0xd9002523),
        alignment: Alignment.center,
        child: LayoutBuilder(
          builder: (_, constraints) {
            const ratio = 1151 / 1367;
            final width = min(
              constraints.maxWidth * .96,
              constraints.maxHeight * .96 * ratio,
            );
            final height = width / ratio;
            return SizedBox(
              width: width,
              height: height,
              child: LayoutBuilder(
                builder: (_, panel) => Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset(
                      'assets/design/victory_panel.png',
                      fit: BoxFit.fill,
                    ),
                    Positioned(
                      left: panel.maxWidth * .282,
                      top: panel.maxHeight * .285,
                      width: panel.maxWidth * .436,
                      height: panel.maxHeight * .366,
                      child: ClipOval(
                        child: Padding(
                          padding: EdgeInsets.all(panel.maxWidth * .025),
                          child: Image.asset(
                            'assets/avatars/portraits/$winnerAvatar.png',
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                    if (coins != null && gameStartingCoins != null && coins! > gameStartingCoins!)
                      Positioned(
                        left: panel.maxWidth * .18,
                        right: panel.maxWidth * .18,
                        top: panel.maxHeight * .50,
                        height: panel.maxHeight * .10,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: const Color(0xff003d39),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: const Color(0xffffcf40), width: 2),
                            boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 8)],
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.monetization_on, color: Color(0xffffcf40), size: 42),
                                  const SizedBox(width: 8),
                                  Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text('+${coins! - gameStartingCoins!} érme', style: const TextStyle(color: Color(0xffffcf40), fontSize: 24, fontWeight: FontWeight.w900)),
                                      Text('Egyenleg: $coins', style: const TextStyle(color: Color(0xfffff0c7), fontSize: 12)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    Positioned(
                      left: panel.maxWidth * .28,
                      right: panel.maxWidth * .28,
                      top: panel.maxHeight * .605,
                      height: panel.maxHeight * .058,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: const Color(0xffffedbd),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                            color: const Color(0xffffbd19),
                            width: 2,
                          ),
                          boxShadow: const [
                            BoxShadow(color: Colors.black45, blurRadius: 5),
                          ],
                        ),
                        child: Center(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              child: Text(
                                winner,
                                style: TextStyle(
                                  color: const Color(0xff002f2c),
                                  fontSize: panel.maxWidth * .045,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: panel.maxWidth * .25,
                      right: panel.maxWidth * .25,
                      top: panel.maxHeight * .685,
                      height: panel.maxHeight * .105,
                      child: Semantics(
                        button: true,
                        label: 'Újra',
                        child: InkWell(
                          borderRadius: BorderRadius.circular(50),
                          onTap: replayFinishedGame,
                        ),
                      ),
                    ),
                    Positioned(
                      left: panel.maxWidth * .25,
                      right: panel.maxWidth * .25,
                      top: panel.maxHeight * .795,
                      height: panel.maxHeight * .105,
                      child: Semantics(
                        button: true,
                        label: 'Kilépés',
                        child: InkWell(
                          borderRadius: BorderRadius.circular(50),
                          onTap: leaveFinishedGame,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext c) => Scaffold(
    backgroundColor: const Color(0xff10131f),
    extendBody: true,
    extendBodyBehindAppBar: true,
    body: SizedBox.expand(child: playing ? board() : setup()),
  );

  Future<void> showRulesModal() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: const Color(0xff07534d),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(26),
          side: const BorderSide(color: Color(0xff8ff1d7), width: 3),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420, maxHeight: 680),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 14),
            child: Column(
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'JÁTÉKSZABÁLY',
                        style: TextStyle(
                          color: Color(0xffffd33f),
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      icon: const Icon(Icons.close, color: Color(0xfffff0c7)),
                    ),
                  ],
                ),
                const Divider(color: Color(0xff38d8c0)),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'A cél',
                          style: TextStyle(
                            color: Color(0xffffd33f),
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Gyűjts össze három egyforma értékű lapot, és szerezz TRIO-t. A 7-es TRIO azonnal megnyeri a partit.',
                          style: TextStyle(color: Color(0xfffff0c7), height: 1.35),
                        ),
                        const SizedBox(height: 14),
                        Center(
                          child: const RulesCardDemo(),
                        ),
                        const SizedBox(height: 16),
                        _ruleStep('1', 'A körödben válaszd az asztal vagy egy játékos szélső lapját.'),
                        _ruleStep('2', 'A Lo a legalacsonyabb, a Hi a legmagasabb elérhető lap.'),
                        _ruleStep('3', 'Fordíts fel legfeljebb három lapot. Ha mindhárom azonos, TRIO-t szereztél.'),
                        _ruleStep('4', 'Három megszerzett TRIO vagy egy 7-es TRIO győzelmet jelent.'),
                        const SizedBox(height: 10),
                        const Text(
                          'Játékosok',
                          style: TextStyle(color: Color(0xffffd33f), fontSize: 18, fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Helyben 3–6 játékos játszhat gépi ellenfelekkel. Szerveres módban szobakóddal vagy matchmakinggel csatlakozhattok.',
                          style: TextStyle(color: Color(0xfffff0c7), height: 1.35),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _ruleStep(String number, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 14,
          backgroundColor: const Color(0xffffd33f),
          child: Text(number, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900)),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: const TextStyle(color: Color(0xfffff0c7), height: 1.3))),
      ],
    ),
  );

  Widget designPanel({required bool game}) => LayoutBuilder(
    builder: (context, constraints) {
      if (game) {
        return Image.asset(
          'assets/design/turquoise_board_base.png',
          width: constraints.maxWidth,
          height: constraints.maxHeight,
          fit: BoxFit.fill,
        );
      }
      final side = constraints.maxHeight;
      return ClipRect(
        child: OverflowBox(
          alignment: Alignment.centerLeft,
          minWidth: side,
          maxWidth: side,
          minHeight: side,
          maxHeight: side,
          child: Image.asset(
            'assets/design/trio_mobile_design.png',
            width: side,
            height: side,
            fit: BoxFit.fill,
          ),
        ),
      );
    },
  );

  Widget setup() => Stack(
    fit: StackFit.expand,
    children: [
      Image.asset(
        'assets/design/login_screen.png',
        fit: BoxFit.cover,
        alignment: Alignment.center,
      ),
      if (!showGameOptions) ...[
        Positioned(
          left: 32,
          right: 32,
          top: MediaQuery.sizeOf(context).height * .68,
          height: MediaQuery.sizeOf(context).height * .095,
          child: Semantics(
            button: true,
            label: 'Játék indítása',
            child: InkWell(
              onTap: () async {
                if (mounted) setState(() => showGameOptions = true);
              },
            ),
          ),
        ),
        Positioned(
          left: MediaQuery.sizeOf(context).width * .66,
          right: MediaQuery.sizeOf(context).width * .04,
          bottom: MediaQuery.sizeOf(context).height * .035,
          height: MediaQuery.sizeOf(context).height * .085,
          child: Semantics(
            button: true,
            label: 'Játékszabály',
            child: InkWell(onTap: showRulesModal),
          ),
        ),
        Positioned(
          left: MediaQuery.sizeOf(context).width * .35,
          right: MediaQuery.sizeOf(context).width * .35,
          bottom: MediaQuery.sizeOf(context).height * .06,
          height: MediaQuery.sizeOf(context).height * .06,
          child: Semantics(button: true, label: 'Ranglista', child: InkWell(onTap: showLeaderboard)),
        ),
        Positioned(
          left: MediaQuery.sizeOf(context).width * .08,
          right: MediaQuery.sizeOf(context).width * .08,
          top: MediaQuery.sizeOf(context).height * .785,
          height: MediaQuery.sizeOf(context).height * .09,
          child: Semantics(
            button: true,
            label: api.isAuthenticated ? 'Kijelentkezés' : 'Bejelentkezés',
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(40),
                onTap: () async {
                  if (api.isAuthenticated) {
                    await api.clearSession();
                    googleAccount = null;
                    if (mounted) setState(() => coins = null);
                  } else if (await showGoogleLogin()) {
                    if (mounted) setState(() => coins = api.coins);
                  }
                },
                child: Image.asset(
                  api.isAuthenticated
                      ? 'assets/design/logout_button.png'
                      : 'assets/design/login_button.png',
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
        ),
      ] else
        gameOptionsPanel(),
    ],
  );

  Future<void> showLeaderboard() async {
    if (!api.isAuthenticated && !await showGoogleLogin()) return;
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 24),
        child: LeaderboardPage(api: api),
      ),
    );
  }

  Widget gameOptionsPanel() => LayoutBuilder(
    builder: (_, screen) {
      const panelRatio = 1146 / 1365;
      final panelWidth = min(
        screen.maxWidth * .92,
        screen.maxHeight * .84 * panelRatio,
      );
      final panelHeight = panelWidth / panelRatio;
      return Container(
        color: const Color(0xaa001e1c),
        alignment: Alignment.center,
        child: SizedBox(
          width: panelWidth,
          height: panelHeight,
          child: gameOptionsPanelBody(),
        ),
      );
    },
  );

  Widget gameOptionsPanelBody() => LayoutBuilder(
    builder: (_, size) => Stack(
      fit: StackFit.expand,
      children: [
        Image.asset('assets/design/game_options_panel.png', fit: BoxFit.fill),
        Positioned(
          left: size.maxWidth * .145,
          right: size.maxWidth * .145,
          top: size.maxHeight * .29,
          height: size.maxHeight * .105,
          child: Row(
            children: [
              for (int value = 3; value <= 6; value++)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () => setState(() => count = value),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 160),
                        child: Image.asset(
                          'assets/design/player_count_${value}_${count == value ? 'selected' : 'normal'}.png',
                          key: ValueKey<bool>(count == value),
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Positioned(
          left: size.maxWidth * .085,
          right: size.maxWidth * .085,
          top: size.maxHeight * .498,
          height: size.maxHeight * .055,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: Row(children: [
                  for (final isServer in [false, true]) Expanded(
                    child: ColoredBox(
                      color: serverMode == isServer ? const Color(0xffffcc38) : const Color(0xff003d39),
                      child: Center(child: FittedBox(fit: BoxFit.scaleDown, child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text('${serverMode == isServer ? '✓ ' : ''}${isServer ? 'Szerver játék' : 'Gépi játék'}',
                          style: TextStyle(fontFamily: 'serif', fontWeight: FontWeight.w900,
                            color: serverMode == isServer ? const Color(0xff003d39) : const Color(0xfffff0c7))),
                      ))),
                    ),
                  ),
                ]),
              ),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      borderRadius: const BorderRadius.horizontal(
                        left: Radius.circular(40),
                      ),
                      onTap: () => setState(() {
                        auto = true;
                        serverMode = false;
                      }),
                      child: const SizedBox.expand(),
                    ),
                  ),
                  Expanded(
                    child: InkWell(
                      borderRadius: const BorderRadius.horizontal(
                        right: Radius.circular(40),
                      ),
                      onTap: () => setState(() {
                        auto = false;
                        serverMode = true;
                      }),
                      child: const SizedBox.expand(),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (!serverMode)
          Positioned(
            left: size.maxWidth * .16,
            right: size.maxWidth * .16,
            top: size.maxHeight * .557,
            height: size.maxHeight * .035,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: const Color(0xcc003d39),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xff82e8d2), width: 2),
              ),
              child: Row(
                children: [
                  for (final difficulty in BotDifficulty.values)
                    Expanded(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => setState(() => botDifficulty = difficulty),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: botDifficulty == difficulty
                                ? const Color(0xffffca20)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              switch (difficulty) {
                                BotDifficulty.soft => 'SOFT',
                                BotDifficulty.medium => 'MEDIUM',
                                BotDifficulty.hard => 'HARD',
                              },
                              style: TextStyle(
                                color: botDifficulty == difficulty
                                    ? const Color(0xff003d39)
                                    : const Color(0xfffff0c7),
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        Positioned(
          left: size.maxWidth * .08,
          right: size.maxWidth * .08,
          top: size.maxHeight * .635,
          height: size.maxHeight * .115,
          child: Semantics(
            button: true,
            label: 'Játék indítása',
            child: InkWell(
              borderRadius: BorderRadius.circular(45),
              onTap: () {
                showGameOptions = false;
                if (serverMode) {
                  setState(() {});
                  Future<void>.microtask(openServerLobby);
                } else {
                  auto = true;
                  start();
                }
              },
            ),
          ),
        ),
        Positioned(
          left: size.maxWidth * .32,
          right: size.maxWidth * .32,
          top: size.maxHeight * .78,
          height: size.maxHeight * .08,
          child: InkWell(onTap: () => setState(() => showGameOptions = false)),
        ),
      ],
    ),
  );

  Future<bool> showGoogleLogin() async {
    if (api.isAuthenticated) return true;
    var loading = false;
    var status = 'A szerverjátékhoz jelentkezz be a Google-fiókoddal.';

    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => StatefulBuilder(
            builder: (context, setModalState) => AlertDialog(
              backgroundColor: const Color(0xff07534d),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: const BorderSide(color: Color(0xff8ff1d7), width: 3),
              ),
              title: const Text(
                'BEJELENTKEZÉS',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xffffd33f),
                  fontWeight: FontWeight.w900,
                ),
              ),
              content: SizedBox(
                width: 340,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.account_circle,
                      size: 72,
                      color: Color(0xfffff0c7),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      status,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Color(0xfffff0c7)),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: loading
                            ? null
                            : () async {
                                setModalState(() => loading = true);
                                try {
                                  if (googleWebClientId.isEmpty) {
                                    throw const TrioApiException(
                                      'A Google kliensazonosítót még be kell állítani.',
                                    );
                                  }
                                  if (!googleSignInInitialized) {
                                    await GoogleSignIn.instance.initialize(
                                      serverClientId: googleWebClientId,
                                    );
                                    googleSignInInitialized = true;
                                  }
                                  final account = await GoogleSignIn.instance
                                      .authenticate();
                                  final idToken =
                                      account.authentication.idToken;
                                  if (idToken == null || idToken.isEmpty) {
                                    throw const TrioApiException(
                                      'A Google nem adott azonosító tokent.',
                                    );
                                  }
                                  await api.createGoogleSession(idToken);
                                  if (mounted) {
                                    setState(() => coins = api.coins);
                                  }
                                  googleAccount = account;
                                  if (dialogContext.mounted) {
                                    Navigator.pop(dialogContext, true);
                                  }
                                } on GoogleSignInException catch (error) {
                                  setModalState(
                                    () => status =
                                        'A Google-belépés nem sikerült: ${error.code.name}',
                                  );
                                } on TrioApiException catch (error) {
                                  setModalState(() => status = error.message);
                                } on TimeoutException {
                                  setModalState(
                                    () => status =
                                        'A szerver nem válaszolt időben.',
                                  );
                                } catch (_) {
                                  setModalState(
                                    () => status =
                                        'Nem sikerült bejelentkezni. Próbáld újra!',
                                  );
                                } finally {
                                  if (context.mounted) {
                                    setModalState(() => loading = false);
                                  }
                                }
                              },
                        icon: const Icon(Icons.login),
                        label: const Text('BELÉPÉS GOOGLE-FIÓKKAL'),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: loading
                      ? null
                      : () => Navigator.pop(dialogContext, false),
                  child: const Text('VISSZA'),
                ),
              ],
            ),
          ),
        ) ??
        false;
  }

  Future<void> openServerLobby() async {
    if (!api.isAuthenticated && !await showGoogleLogin()) {
      if (mounted) setState(() => showGameOptions = true);
      return;
    }
    final codeController = TextEditingController();
    var loading = false;
    var waitingForMatch = false;
    var status = '';
    TrioRoom? room;
    Timer? matchmakingTimer;
    ModalRoute<dynamic>? serverDialogRoute;

    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setModalState) {
          serverDialogRoute = ModalRoute.of(context);
          Future<void> run(Future<void> Function() action) async {
            if (loading) return;
            setModalState(() => loading = true);
            try {
              await action();
            } on TimeoutException {
              status = 'A szerver nem válaszolt időben. Próbáld újra!';
            } on TrioApiException catch (error) {
              status = error.message;
            } catch (_) {
              status = 'Nem sikerült kapcsolódni a szerverhez.';
            } finally {
              if (context.mounted) setModalState(() => loading = false);
            }
          }

          void launchNetworkGame(TrioRoom readyRoom) {
            matchmakingTimer?.cancel();
            waitingForMatch = false;
            if (dialogContext.mounted) Navigator.pop(dialogContext);
            Future<void>.microtask(() => startNetworkGame(readyRoom));
          }

          void startRoomPolling() {
            matchmakingTimer?.cancel();
            matchmakingTimer = Timer.periodic(const Duration(seconds: 3), (
              timer,
            ) async {
              if (!context.mounted || room == null) {
                timer.cancel();
                return;
              }
              try {
                final updatedRoom = await api.getRoom(room!.code);
                if (!context.mounted) return;
                final ready =
                    updatedRoom.status == 'playing' ||
                    updatedRoom.status == 'finished';
                setModalState(() {
                  room = updatedRoom;
                  waitingForMatch = !ready;
                  status = !ready
                      ? 'Várunk a következő játékosra…'
                      : 'Megvan minden játékos!';
                });
                if (ready) launchNetworkGame(updatedRoom);
              } catch (_) {
                // A következő automatikus frissítésnél újra próbáljuk.
              }
            });
          }

          void startMatchmakingPolling() {
            matchmakingTimer?.cancel();
            matchmakingTimer = Timer.periodic(const Duration(seconds: 3), (
              timer,
            ) async {
              if (!context.mounted || !waitingForMatch) {
                timer.cancel();
                return;
              }
              try {
                final result = await api.getMatchmakingStatus();
                if (!context.mounted) return;
                final matchedRoom = result.room;
                if (matchedRoom != null &&
                    (result.status == 'matched' ||
                        matchedRoom.status == 'playing' ||
                        matchedRoom.status == 'finished')) {
                  launchNetworkGame(matchedRoom);
                  return;
                }
                setModalState(() {
                  room = matchedRoom;
                  status = 'Várunk ellenfélre…';
                });
              } catch (_) {
                // A következő automatikus frissítésnél újra próbáljuk.
              }
            });
          }

          if (room == null && !waitingForMatch) {
            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.all(14),
              child: SingleChildScrollView(
                child: AspectRatio(
                  aspectRatio: 1119 / 1398,
                  child: LayoutBuilder(builder: (context, box) {
                    Widget area(double top, double height, Widget child) => Positioned(
                      left: box.maxWidth * .055,
                      right: box.maxWidth * .055,
                      top: box.maxHeight * top,
                      height: box.maxHeight * height,
                      child: child,
                    );
                    return Stack(children: [
                      Positioned.fill(child: Image.asset('assets/design/server_panel.png', fit: BoxFit.fill)),
                      area(.315, .075, Row(children: [
                        const SizedBox(width: 12),
                        Expanded(child: TextField(
                        controller: codeController,
                        textAlign: TextAlign.center,
                        textAlignVertical: TextAlignVertical.center,
                        enabled: !loading,
                        maxLength: 6,
                        onChanged: (_) => setModalState(() {}),
                        textCapitalization: TextCapitalization.characters,
                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]'))],
                        style: const TextStyle(color: Color(0xfffff0c7), fontSize: 22, fontWeight: FontWeight.bold),
                        decoration: InputDecoration(
                          filled: false,
                          fillColor: Colors.transparent,
                          border: InputBorder.none,
                          counterText: '',
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                        ),
                      )),
                        Container(
                          width: box.maxWidth * .13,
                          height: box.maxHeight * .055,
                          alignment: Alignment.center,
                          color: const Color(0xff003d39),
                          child: Text('${codeController.text.length}/6', style: const TextStyle(color: Color(0xfffff0c7), fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 8),
                      ])),
                      area(.415, .10, InkWell(onTap: loading ? null : () => run(() async {
                        room = await api.createRoom(count);
                        waitingForMatch = true;
                        status = 'Szoba elkészült. Oszd meg a kódot a játékosokkal!';
                        startRoomPolling();
                      }))),
                      area(.55, .10, InkWell(
                        onTap: loading ? null : () => run(() async {
                          if (codeController.text.trim().isNotEmpty) {
                            if (codeController.text.trim().length != 6) {
                              throw const TrioApiException('A szobakód pontosan 6 karakter.');
                            }
                            room = await api.joinRoom(codeController.text.trim());
                            if (room!.status == 'playing') {
                              launchNetworkGame(room!);
                            } else {
                              waitingForMatch = true;
                              status = 'Várunk a következő játékosra…';
                              startRoomPolling();
                            }
                          } else {
                            final result = await api.joinMatchmaking(count);
                            room = result.room;
                            waitingForMatch = result.status != 'matched';
                            if (waitingForMatch) {
                              status = 'Várunk ellenfélre…';
                              startMatchmakingPolling();
                            } else if (room != null) {
                              launchNetworkGame(room!);
                            }
                          }
                        }),
                        child: Padding(
                          padding: EdgeInsets.only(left: box.maxWidth * .23, right: 12),
                          child: Center(child: FittedBox(child: Text(
                            codeController.text.trim().isEmpty ? 'Csatlakozás ($count fő)' : 'Belépés a szobába',
                            style: const TextStyle(color: Color(0xfffff0c7), fontSize: 22, fontFamily: 'serif', fontWeight: FontWeight.w900, shadows: [Shadow(color: Colors.black54, offset: Offset(0, 2), blurRadius: 2)]),
                          ))),
                        ),
                      )),
                      if (loading) area(.79, .04, const Center(child: CircularProgressIndicator())),
                      if (!loading && status.isNotEmpty) area(.79, .04, Center(child: Text(status, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xffffd33f), fontSize: 11)))),
                      Positioned(left: box.maxWidth * .62, right: box.maxWidth * .08, top: box.maxHeight * .835, height: box.maxHeight * .09,
                        child: InkWell(onTap: loading ? null : () {
                          FocusScope.of(context).unfocus();
                          Navigator.pop(dialogContext);
                          if (mounted) setState(() => showGameOptions = true);
                        })),
                    ]);
                  }),
                ),
              ),
            );
          }

          return AlertDialog(
            backgroundColor: const Color(0xff07534d),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: const BorderSide(color: Color(0xff8ff1d7), width: 3),
            ),
            title: Text(
              room == null ? 'SZERVERJÁTÉK' : 'SZOBA: ${room!.code}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xffffd33f),
                fontWeight: FontWeight.w900,
              ),
            ),
            content: SingleChildScrollView(
              child: SizedBox(
                width: 360,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (room == null) ...[
                      if (googleAccount != null)
                        ListTile(
                          leading: const Icon(Icons.verified_user),
                          title: Text(
                            googleAccount!.displayName ?? 'Google-játékos',
                          ),
                          subtitle: Text(googleAccount!.email),
                        ),
                      TextField(
                        controller: codeController,
                        enabled: !loading,
                        maxLength: 6,
                        textCapitalization: TextCapitalization.characters,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp('[A-Za-z0-9]'),
                          ),
                          LengthLimitingTextInputFormatter(6),
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Szobakód',
                          prefixIcon: Icon(Icons.key),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: loading
                                  ? null
                                  : () => run(() async {
                                      room = await api.createRoom(count);
                                      waitingForMatch = true;
                                      status =
                                          'Szoba elkészült. Oszd meg a kódot a játékosokkal!';
                                      startRoomPolling();
                                    }),
                              icon: const Icon(Icons.add_circle),
                              label: const Text('SZOBA'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: loading
                                  ? null
                                  : () => run(() async {
                                      if (codeController.text.trim().length !=
                                          6) {
                                        throw const TrioApiException(
                                          'A szobakód pontosan 6 karakter.',
                                        );
                                      }
                                      room = await api.joinRoom(
                                        codeController.text,
                                      );
                                      if (room!.status == 'playing') {
                                        launchNetworkGame(room!);
                                      } else {
                                        waitingForMatch = true;
                                        status =
                                            'Sikeresen beléptél a szobába.';
                                        startRoomPolling();
                                      }
                                    }),
                              icon: const Icon(Icons.login),
                              label: const Text('BELÉPÉS'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: loading
                              ? null
                              : () => run(() async {
                                  final result = await api.joinMatchmaking(
                                    count,
                                  );
                                  room = result.room;
                                  waitingForMatch = result.status != 'matched';
                                  if (waitingForMatch) {
                                    status = 'Várunk ellenfélre…';
                                    startMatchmakingPolling();
                                  } else {
                                    status = 'Megvan minden játékos!';
                                    if (room != null) {
                                      launchNetworkGame(room!);
                                    } else {
                                      throw const TrioApiException(
                                        'A szerver nem adta vissza a létrejött szobát.',
                                      );
                                    }
                                  }
                                }),
                          icon: const Icon(Icons.groups),
                          label: Text('VÉLETLEN KERESÉS ($count FŐ)'),
                        ),
                      ),
                    ] else ...[
                      Text(
                        '${room!.joinedPlayers}/${room!.playerCount} játékos',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      for (
                        int playerIndex = 0;
                        playerIndex < room!.playerNames.length;
                        playerIndex++
                      )
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              ClipOval(
                                child: Image.asset(
                                  'assets/avatars/portraits/${room!.playerAvatarIds[playerIndex]}.png',
                                  width: 30,
                                  height: 30,
                                  fit: BoxFit.contain,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                room!.playerNames[playerIndex],
                                style: const TextStyle(
                                  color: Color(0xfffff0c7),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: loading
                            ? null
                            : () => run(() async {
                                room = await api.getRoom(room!.code);
                                if (room!.status == 'playing') {
                                  launchNetworkGame(room!);
                                } else {
                                  status = 'Még várunk a többiekre…';
                                }
                              }),
                        icon: const Icon(Icons.refresh),
                        label: const Text('FRISSÍTÉS'),
                      ),
                    ],
                    const SizedBox(height: 14),
                    if (loading)
                      const CircularProgressIndicator()
                    else
                      Text(
                        status,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Color(0xfffff0c7)),
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: loading
                    ? null
                    : () async {
                        matchmakingTimer?.cancel();
                        if (waitingForMatch) {
                          try {
                            await api.leaveMatchmaking();
                          } catch (_) {
                            // Hálózati hiba esetén is bezárjuk az ablakot.
                          }
                        }
                        if (room != null) {
                          try {
                            await api.leaveRoom(room!.code);
                          } catch (_) {
                            // A bezárást hálózati hiba esetén sem akadályozzuk.
                          }
                        }
                        if (!dialogContext.mounted) return;
                        Navigator.pop(dialogContext);
                        if (mounted) {
                          setState(() => showGameOptions = true);
                        }
                      },
                child: const Text('VISSZA'),
              ),
            ],
          );
        },
      ),
    );
    matchmakingTimer?.cancel();
    // showDialog resolves before the closing animation removes its TextField.
    await serverDialogRoute?.completed;
    codeController.dispose();
  }

  void openPicker() {
    if (busy || turn != 0 || gameOver) return;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xff073f3b),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Kártya felfedése',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 9,
                runSpacing: 9,
                alignment: WrapAlignment.center,
                children: [
                  for (int i = 0; i < table.length; i++)
                    if (table[i] != null)
                      back(
                        w: 42,
                        tap: () {
                          Navigator.pop(sheetContext);
                          Future<void>.microtask(() => pickTable(i));
                        },
                      ),
                ],
              ),
              const SizedBox(height: 14),
              for (int p = 1; p < ps.length; p++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(child: Text(ps[p].name)),
                      FilledButton(
                        onPressed: live(ps[p]).isEmpty
                            ? null
                            : () {
                                final slot = live(ps[p]).first;
                                Navigator.pop(sheetContext);
                                Future<void>.microtask(() => pickHand(p, slot));
                              },
                        child: const Text('MIN'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: live(ps[p]).isEmpty
                            ? null
                            : () {
                                final slot = live(ps[p]).last;
                                Navigator.pop(sheetContext);
                                Future<void>.microtask(() => pickHand(p, slot));
                              },
                        child: const Text('MAX'),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void openHand() {
    if (busy || turn != 0 || gameOver) return;
    final slots = live(ps[0]);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xff073f3b),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'A te kezed',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 6,
                children: [
                  for (final slot in slots)
                    InkWell(
                      onTap: slot == slots.first || slot == slots.last
                          ? () {
                              Navigator.pop(sheetContext);
                              Future<void>.microtask(() => pickHand(0, slot));
                            }
                          : null,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(9),
                          border: slot == slots.first || slot == slots.last
                              ? Border.all(
                                  color: const Color(0xffffd21f),
                                  width: 3,
                                )
                              : null,
                        ),
                        child: face(ps[0].hand[slot]!, w: 48),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget playerNameBadge(String name) => Positioned(
    left: 3,
    right: 3,
    bottom: 10,
    height: 38,
    child: Stack(
      fit: StackFit.expand,
      children: [
        Image.asset('assets/avatars/name_badge.png', fit: BoxFit.fill),
        Align(
          alignment: const Alignment(0, -.38),
          child: FractionallySizedBox(
            widthFactor: .72,
            heightFactor: .42,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                name,
                style: const TextStyle(
                  color: Color(0xff24170b),
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );

  Widget trioCounter(int amount) => SizedBox(
    width: 72,
    height: 86,
    child: Image.asset(
      'assets/avatars/trio_count_${amount.clamp(0, 3)}.png',
      fit: BoxFit.contain,
    ),
  );

  Widget activeTurnMarker({required bool me}) => Positioned(
    left: 20,
    right: 20,
    top: -12,
    height: 25,
    child: IgnorePointer(
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xffffc928),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xfffff1a6), width: 2),
          boxShadow: const [
            BoxShadow(
              color: Color(0xccffcf25),
              blurRadius: 12,
              spreadRadius: 3,
            ),
          ],
        ),
        child: Text(
          me ? 'TE JÖSSZ' : 'Ő JÖN',
          style: const TextStyle(
            color: Color(0xff073f3b),
            fontSize: 11,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    ),
  );

  Widget portraitOpponent(int p) {
    final slots = live(ps[p]);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        if (turn == p)
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                margin: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(70),
                  border: Border.all(color: const Color(0xffffd21f), width: 4),
                  boxShadow: const [
                    BoxShadow(color: Color(0xaaffd21f), blurRadius: 18),
                  ],
                ),
              ),
            ),
          ),
        Positioned.fill(
          child: Image.asset(
            'assets/avatars/player_frame.png',
            fit: BoxFit.contain,
          ),
        ),
        Positioned(left: -18, top: 20, child: trioCounter(ps[p].trios.length)),
        Align(
          alignment: const Alignment(0, .46),
          child: FractionallySizedBox(
            widthFactor: .62,
            heightFactor: .62,
            child: ClipOval(
              child: Image.asset(
                'assets/avatars/portraits/${avatarIds[p]}.png',
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
        Align(
          alignment: const Alignment(0, -.65),
          child: FractionallySizedBox(
            widthFactor: .72,
            heightFactor: .20,
            child: Image.asset(
              'assets/avatars/lo_hi_large.png',
              fit: BoxFit.fill,
            ),
          ),
        ),
        playerNameBadge(ps[p].name),
        for (int slot = 0; slot < ps[p].hand.length; slot++)
          Positioned(
            left: 48,
            top: 34,
            child: SizedBox(key: handSlotKeys[p][slot], width: 2, height: 2),
          ),
        Align(
          alignment: const Alignment(0, -.65),
          child: FractionallySizedBox(
            widthFactor: .72,
            heightFactor: .20,
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: !busy && turn == 0 && slots.isNotEmpty
                        ? () => pickHand(p, slots.first)
                        : null,
                  ),
                ),
                Expanded(
                  child: InkWell(
                    onTap: !busy && turn == 0 && slots.isNotEmpty
                        ? () => pickHand(p, slots.last)
                        : null,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (turn == p) activeTurnMarker(me: false),
      ],
    );
  }

  List<Offset> opponentLayout(int playerCount) => switch (playerCount) {
    3 => const [Offset(.055, .10), Offset(.655, .10)],
    4 => const [Offset(.355, .06), Offset(.035, .25), Offset(.675, .25)],
    5 => const [
      Offset(.055, .08),
      Offset(.655, .08),
      Offset(.035, .28),
      Offset(.675, .28),
    ],
    _ => const [
      Offset(.355, .035),
      Offset(.015, .18),
      Offset(.695, .18),
      Offset(.02, .39),
      Offset(.69, .39),
    ],
  };

  Widget boardCornerButton({
    required String asset,
    required String label,
    required VoidCallback onTap,
  }) => Semantics(
    button: true,
    label: label,
    child: Material(
      color: const Color(0xff003b37),
      shape: const CircleBorder(
        side: BorderSide(color: Color(0xff6fe3ce), width: 3),
      ),
      elevation: 8,
      shadowColor: Colors.black87,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Image.asset(asset, fit: BoxFit.contain),
        ),
      ),
    ),
  );

  void openSettings() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xff07534d),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: Color(0xff8ff1d7), width: 3),
        ),
        title: const Text(
          'Beállítások',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Color(0xfffff0c7),
            fontWeight: FontWeight.w900,
          ),
        ),
        content: const Text(
          'A játék beállításai hamarosan itt lesznek elérhetők.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xffffc928),
              foregroundColor: const Color(0xff073f3b),
            ),
            child: const Text('RENDBEN'),
          ),
        ],
      ),
    );
  }

  Widget board() => LayoutBuilder(
    builder: (context, size) {
      final meSlots = live(ps[0]);
      final opponentOffsets = opponentLayout(ps.length);
      return Stack(
        fit: StackFit.expand,
        children: [
          designPanel(game: true),
          Positioned(
            left: 12,
            top: 12,
            width: 72,
            height: 72,
            child: boardCornerButton(
              asset: 'assets/design/home_button.png',
              label: 'Vissza a kezdőképernyőre',
              onTap: () {
                networkTimer?.cancel();
                networkRoomCode = null;
                setState(() {
                  playing = false;
                  showGameOptions = false;
                });
              },
            ),
          ),
          Positioned(
            right: 12,
            top: 12,
            width: 72,
            height: 72,
            child: boardCornerButton(
              asset: 'assets/design/settings_button.png',
              label: 'Beállítások',
              onTap: openSettings,
            ),
          ),
          for (int p = 1; p < ps.length; p++)
            Positioned(
              left: size.maxWidth * opponentOffsets[p - 1].dx,
              top: size.maxHeight * opponentOffsets[p - 1].dy,
              width: size.maxWidth * .29,
              height: size.maxHeight * .19,
              child: portraitOpponent(p),
            ),
          Positioned(
            left:
                size.maxWidth *
                (table.length == 9 ? .16 : (table.length == 8 ? .20 : .285)),
            right:
                size.maxWidth *
                (table.length == 9 ? .16 : (table.length == 8 ? .20 : .285)),
            top: size.maxHeight * (table.length == 8 ? .34 : .31),
            height: size.maxHeight * (table.length == 8 ? .19 : .22),
            child: LayoutBuilder(
              builder: (_, gridSize) {
                const gap = 7.0;
                const backRatio = 152 / 271;
                final columnCount = table.length == 9
                    ? 5
                    : (table.length == 8 ? 5 : (ps.length == 5 ? 2 : 3));
                final rowCount = (table.length / columnCount).ceil();
                final cardWidth = min(
                  (gridSize.maxWidth - gap * (columnCount - 1)) / columnCount,
                  ((gridSize.maxHeight - gap * (rowCount - 1)) / rowCount) *
                      backRatio,
                );
                final cardHeight = cardWidth / backRatio;
                final gridHeight = cardHeight * rowCount + gap * (rowCount - 1);
                final startY = (gridSize.maxHeight - gridHeight) / 2;
                return Stack(
                  children: [
                    for (int i = 0; i < table.length; i++)
                      Positioned(
                        left: () {
                          final row = table.length == 8
                              ? (i < 3 ? 0 : 1)
                              : i ~/ columnCount;
                          final column = table.length == 8
                              ? (i < 3 ? i : i - 3)
                              : i % columnCount;
                          final itemsInRow = table.length == 8
                              ? (row == 0 ? 3 : 5)
                              : min(
                                  columnCount,
                                  table.length - row * columnCount,
                                );
                          final rowWidth =
                              cardWidth * itemsInRow + gap * (itemsInRow - 1);
                          final rowStartX = (gridSize.maxWidth - rowWidth) / 2;
                          return rowStartX + column * (cardWidth + gap);
                        }(),
                        top:
                            startY +
                            (table.length == 8
                                    ? (i < 3 ? 0 : 1)
                                    : i ~/ columnCount) *
                                (cardHeight + gap),
                        width: cardWidth,
                        height: cardHeight,
                        child: KeyedSubtree(
                          key: tableSlotKeys[i],
                          child: table[i] == null
                              ? const SizedBox.expand()
                              : Center(
                                  child: back(
                                    w: cardWidth,
                                    tap: !busy && turn == 0
                                        ? () => pickTable(i)
                                        : null,
                                  ),
                                ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
          Positioned(
            left: size.maxWidth * .20,
            right: size.maxWidth * .20,
            top: size.maxHeight * .54,
            height: size.maxHeight * .09,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                for (int i = 0; i < 3; i++)
                  SizedBox(
                    key: revealSlotKeys[i],
                    width: size.maxWidth * .13,
                    child: revealSlot(i),
                  ),
              ],
            ),
          ),
          Positioned(
            left: size.maxWidth * .355,
            top: size.maxHeight * .64,
            width: size.maxWidth * .29,
            height: size.maxHeight * .19,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                if (turn == 0)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Container(
                        margin: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(70),
                          border: Border.all(
                            color: const Color(0xffffd21f),
                            width: 4,
                          ),
                          boxShadow: const [
                            BoxShadow(color: Color(0xaaffd21f), blurRadius: 18),
                          ],
                        ),
                      ),
                    ),
                  ),
                Positioned.fill(
                  child: Image.asset(
                    'assets/avatars/player_frame.png',
                    fit: BoxFit.contain,
                  ),
                ),
                Positioned(left: -18, top: 20, child: trioCounter(ps[0].trios.length)),
                Align(
                  alignment: const Alignment(0, .46),
                  child: FractionallySizedBox(
                    widthFactor: .62,
                    heightFactor: .62,
                    child: ClipOval(
                      child: Image.asset(
                        'assets/avatars/portraits/${avatarIds[0]}.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
                Align(
                  alignment: const Alignment(0, -.65),
                  child: FractionallySizedBox(
                    widthFactor: .72,
                    heightFactor: .20,
                    child: Image.asset(
                      'assets/avatars/lo_hi_large.png',
                      fit: BoxFit.fill,
                    ),
                  ),
                ),
                playerNameBadge(ps[0].name),
                Align(
                  alignment: const Alignment(0, -.65),
                  child: FractionallySizedBox(
                    widthFactor: .72,
                    heightFactor: .20,
                    child: Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: !busy && turn == 0 && meSlots.isNotEmpty
                                ? () => pickHand(0, meSlots.first)
                                : null,
                          ),
                        ),
                        Expanded(
                          child: InkWell(
                            onTap: !busy && turn == 0 && meSlots.isNotEmpty
                                ? () => pickHand(0, meSlots.last)
                                : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (turn == 0) activeTurnMarker(me: true),
              ],
            ),
          ),
          Positioned(
            left: 52,
            right: 52,
            bottom: 48,
            height: 150,
            child: LayoutBuilder(
              builder: (_, handSize) => Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.bottomCenter,
                children: [
                  for (int slot = 0; slot < ps[0].hand.length; slot++)
                    Positioned(
                      left:
                          4 +
                          slot *
                              ((handSize.maxWidth - 86) /
                                  max(1, ps[0].hand.length - 1)),
                      bottom:
                          5 +
                          (18 *
                              (1 -
                                  ((slot - (ps[0].hand.length - 1) / 2).abs() /
                                      max(1, ps[0].hand.length / 2)))),
                      child: Transform.rotate(
                        angle: (slot - (ps[0].hand.length - 1) / 2) * .045,
                        alignment: Alignment.bottomCenter,
                        child: KeyedSubtree(
                          key: handSlotKeys[0][slot],
                          child: ps[0].hand[slot] == null
                              ? const SizedBox(width: 76, height: 103)
                              : InkWell(
                                  onTap:
                                      !busy &&
                                          turn == 0 &&
                                          meSlots.isNotEmpty &&
                                          (slot == meSlots.first ||
                                              slot == meSlots.last)
                                      ? () => pickHand(0, slot)
                                      : null,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8),
                                      border:
                                          meSlots.isNotEmpty &&
                                              (slot == meSlots.first ||
                                                  slot == meSlots.last)
                                          ? Border.all(
                                              color: const Color(0xffffd21f),
                                              width: 3,
                                            )
                                          : null,
                                    ),
                                    child: face(ps[0].hand[slot]!, w: 76),
                                  ),
                                ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (turnTimeoutRemaining != null) timeoutWarning(),
          if (gameOver) victoryOverlay(),
        ],
      );
    },
  );

  Widget legacySetup() => Center(
    child: SizedBox(
      width: 700,
      child: Card(
        color: const Color(0xff1a1e2d),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'TRIO',
                style: TextStyle(
                  fontSize: 38,
                  fontWeight: FontWeight.w900,
                  color: Color(0xffff6b57),
                ),
              ),
              const Text('Android kártyajáték', style: TextStyle(fontSize: 20)),
              const SizedBox(height: 16),
              SegmentedButton<int>(
                segments: [
                  for (int n = 3; n <= 6; n++)
                    ButtonSegment(value: n, label: Text(n.toString())),
                ],
                selected: {count},
                onSelectionChanged: (s) => setState(() => count = s.first),
              ),
              SwitchListTile(
                title: const Text('Automata mód'),
                subtitle: const Text('Gépi ellenfelek, rejtett lapokkal'),
                value: auto,
                onChanged: (v) => setState(() => auto = v),
              ),
              FilledButton.icon(
                onPressed: start,
                icon: const Icon(Icons.play_arrow),
                label: const Text('Játék indítása'),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget opp(int i) {
    final l = live(ps[i]);
    return Container(
      width: 130,
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        color: const Color(0xff171b29),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: turn == i ? const Color(0xffff6b57) : const Color(0xff30364a),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(ps[i].name, style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(
            l.length.toString() +
                ' lap · ' +
                ps[i].trios.length.toString() +
                ' TRIO',
            style: const TextStyle(fontSize: 9, color: Color(0xfff6cf5b)),
          ),
          SizedBox(
            height: 28,
            child: Stack(
              children: [
                for (int slot = 0; slot < ps[i].hand.length; slot++)
                  Positioned(
                    left: slot * min(10.0, 82 / max(1, ps[i].hand.length - 1)),
                    child: KeyedSubtree(
                      key: handSlotKeys[i][slot],
                      child: ps[i].hand[slot] == null
                          ? const SizedBox(width: 20, height: 31)
                          : back(
                              w: 20,
                              tap:
                                  (!busy &&
                                      turn == 0 &&
                                      (slot == l.first || slot == l.last))
                                  ? () => pickHand(i, slot)
                                  : null,
                            ),
                    ),
                  ),
              ],
            ),
          ),
          if (!busy && turn == 0 && l.isNotEmpty)
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: () => pickHand(i, l.first),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 28),
                      padding: EdgeInsets.zero,
                      backgroundColor: const Color(0xff2a6657),
                    ),
                    child: const Text('MIN', style: TextStyle(fontSize: 10)),
                  ),
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: FilledButton(
                    onPressed: () => pickHand(i, l.last),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 28),
                      padding: EdgeInsets.zero,
                      backgroundColor: const Color(0xff2a6657),
                    ),
                    child: const Text('MAX', style: TextStyle(fontSize: 10)),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget legacyBoard() {
    final me = ps[0], l = live(me);
    return Stack(
      children: [
        Positioned.fill(
          child: Container(
            margin: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: const RadialGradient(
                colors: [Color(0xff1b3040), Color(0xff10131f)],
              ),
            ),
          ),
        ),
        Positioned(
          left: 16,
          top: 12,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'KÖVETKEZIK',
                style: TextStyle(fontSize: 9, color: Color(0xfff6cf5b)),
              ),
              Text(
                ps[turn].name,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        Positioned(left: 8, top: 130, child: opp(1)),
        Positioned(right: 8, top: 130, child: opp(2)),
        if (ps.length > 3)
          Positioned(
            top: 5,
            left: 150,
            right: 150,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (int i = 3; i < ps.length; i++)
                  Padding(padding: const EdgeInsets.all(3), child: opp(i)),
              ],
            ),
          ),
        Align(
          alignment: const Alignment(0, -.35),
          child: SizedBox(
            width: 360,
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5,
                childAspectRatio: 245 / 332,
                crossAxisSpacing: 6,
                mainAxisSpacing: 6,
              ),
              itemCount: table.length,
              itemBuilder: (_, i) => KeyedSubtree(
                key: tableSlotKeys[i],
                child: table[i] == null
                    ? const SizedBox.expand()
                    : back(tap: () => pickTable(i)),
              ),
            ),
          ),
        ),
        Align(
          alignment: const Alignment(0, .48),
          child: Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: const Color(0xff171b29),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'FELFORDÍTOTT\nLAPOK',
                  style: TextStyle(fontSize: 8, color: Color(0xff9ea2b3)),
                ),
                const SizedBox(width: 8),
                for (int i = 0; i < 3; i++)
                  Padding(
                    padding: const EdgeInsets.all(2),
                    child: SizedBox(
                      key: revealSlotKeys[i],
                      width: 31,
                      height: 48,
                      child: revealSlot(i),
                    ),
                  ),
              ],
            ),
          ),
        ),
        Positioned(
          left: 160,
          right: 160,
          bottom: 8,
          child: Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: const Color(0xff171b29),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                const Text(
                  'A TE KEZED',
                  style: TextStyle(fontSize: 8, color: Color(0xfff6cf5b)),
                ),
                SizedBox(
                  height: 56,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (int i = 0; i < me.hand.length; i++)
                        KeyedSubtree(
                          key: handSlotKeys[0][i],
                          child: me.hand[i] == null
                              ? const SizedBox(width: 43, height: 56)
                              : Semantics(
                                  button: true,
                                  enabled:
                                      l.isNotEmpty &&
                                      (i == l.first || i == l.last),
                                  label: i == l.first
                                      ? 'Saját legkisebb lap'
                                      : i == l.last
                                      ? 'Saját legnagyobb lap'
                                      : 'Saját lap',
                                  child: SizedBox(
                                    width: 43,
                                    height: 56,
                                    child: TextButton(
                                      onPressed:
                                          l.isNotEmpty &&
                                              (i == l.first || i == l.last) &&
                                              !busy &&
                                              turn == 0
                                          ? () => pickHand(0, i)
                                          : null,
                                      style: TextButton.styleFrom(
                                        padding: const EdgeInsets.all(2),
                                        minimumSize: const Size(43, 56),
                                        tapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          side:
                                              !busy &&
                                                  turn == 0 &&
                                                  l.isNotEmpty &&
                                                  (i == l.first || i == l.last)
                                              ? const BorderSide(
                                                  color: Color(0xff61d8b0),
                                                  width: 3,
                                                )
                                              : BorderSide.none,
                                        ),
                                      ),
                                      child: IgnorePointer(
                                        child: face(me.hand[i]!, w: 35),
                                      ),
                                    ),
                                  ),
                                ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          right: 10,
          bottom: 8,
          width: 175,
          child: Text(
            message,
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 10),
          ),
        ),
        if (turnTimeoutRemaining != null) timeoutWarning(),
        if (gameOver) victoryOverlay(),
        Positioned(
          left: 8,
          bottom: 4,
          child: IconButton(
            onPressed: () => setState(() => playing = false),
            icon: const Icon(Icons.refresh),
          ),
        ),
      ],
    );
  }
}
