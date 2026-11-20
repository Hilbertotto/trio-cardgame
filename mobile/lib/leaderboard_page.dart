import 'package:flutter/material.dart';
import 'trio_api.dart';
import 'profile_dialog.dart';

class LeaderboardPage extends StatefulWidget {
  const LeaderboardPage({super.key, required this.api});
  final TrioApi api;
  @override
  State<LeaderboardPage> createState() => _LeaderboardPageState();
}

class _LeaderboardPageState extends State<LeaderboardPage> {
  late Future<Map<String, dynamic>> data = widget.api.getLeaderboard();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await widget.api.refreshProfile();
        if (mounted && widget.api.countryCode == null) await updateProfile();
      } catch (_) {}
    });
  }

  Future<void> updateProfile() async {
    await editPlayerProfile(context, widget.api);
    if (mounted) setState(() => data = widget.api.getLeaderboard());
  }

  Widget entry(Map<String, dynamic> player, {bool mine = false}) => Row(children: [
    if (mine) SizedBox(width: 48, child: FittedBox(child: Text('${player['rank']}.', style: const TextStyle(fontSize: 25, color: Color(0xfffff0c7), fontWeight: FontWeight.bold)))),
    ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.asset('assets/avatars/portraits/${player['avatar_id']}.png', width: 44, height: 44, fit: BoxFit.contain)),
    const SizedBox(width: 8),
    Expanded(child: Text('${player['name']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontFamily: 'serif', fontSize: 17, color: Color(0xfffff0c7), fontWeight: FontWeight.bold))),
    const SizedBox(width: 8),
    if (player['country_code'] is String) Text(String.fromCharCodes((player['country_code'] as String).codeUnits.map((c) => c + 127397)), style: const TextStyle(fontSize: 18)),
    const SizedBox(width: 6),
    Text('${player['points']}', style: const TextStyle(fontFamily: 'serif', fontSize: 18, color: Color(0xfffff0c7), fontWeight: FontWeight.bold)),
  ]);

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xff003d39),
    body: Center(child: AspectRatio(aspectRatio: 1024 / 1536, child: LayoutBuilder(builder: (context, box) => Stack(children: [
      Positioned.fill(child: Image.asset('assets/design/leaderboard_panel.png', fit: BoxFit.fill)),
      Positioned(right: 12, top: 12, child: IconButton(tooltip: 'Profil szerkesztése', onPressed: updateProfile, icon: const Icon(Icons.person, color: Colors.amber))),
      Positioned(left: box.maxWidth * .04, top: box.maxHeight * .025, width: box.maxWidth * .11, height: box.maxHeight * .07,
        child: Semantics(button: true, label: 'Vissza', child: InkWell(onTap: () => Navigator.pop(context)))),
      FutureBuilder<Map<String, dynamic>>(future: data, builder: (context, snapshot) {
        if (snapshot.hasError) return Positioned(left: 35, right: 35, top: box.maxHeight * .4, child: Column(children: [
          const Text('Nem sikerült betölteni a ranglistát.', style: TextStyle(color: Colors.white)),
          TextButton(onPressed: () => setState(() => data = widget.api.getLeaderboard()), child: const Text('Újrapróbálás')),
        ]));
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Colors.amber));
        final top = (snapshot.data!['top'] as List).cast<Map<String, dynamic>>();
        final me = snapshot.data!['me'] as Map<String, dynamic>?;
        return Stack(children: [
          for (int i = 0; i < 5; i++) Positioned(
            left: box.maxWidth * .20, right: box.maxWidth * .065,
            top: box.maxHeight * const [.287, .382, .477, .574, .654][i],
            height: box.maxHeight * (i < 3 ? .073 : .06),
            child: i < top.length ? entry(top[i]) : const Center(child: Text('Még nincs játékos', style: TextStyle(color: Colors.white54))),
          ),
          Positioned(left: box.maxWidth * .07, right: box.maxWidth * .065, top: box.maxHeight * .818, height: box.maxHeight * .075,
            child: me != null ? entry(me, mine: true) : const Center(child: Text('Még nincs helyezésed', style: TextStyle(color: Colors.white)))),
        ]);
      }),
    ])))),
  );
}
