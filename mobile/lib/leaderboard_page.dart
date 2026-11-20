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
  int selected = 0;
  Future<Map<String, dynamic>> load() => widget.api.getLeaderboard(country: selected.isOdd, daily: selected >= 2);
  void select(int index) => setState(() { selected = index; data = load(); });

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
    if (mounted) setState(() => data = load());
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
    backgroundColor: Colors.transparent,
    body: Center(child: AspectRatio(aspectRatio: 941 / 1672, child: LayoutBuilder(builder: (context, box) => Stack(children: [
      Positioned.fill(child: Image.asset('assets/design/leaderboard_panel.png', fit: BoxFit.fill)),
      Positioned(right: 12, top: 12, child: IconButton(tooltip: 'Profil szerkesztése', onPressed: updateProfile, icon: const Icon(Icons.person, color: Colors.amber))),
      Positioned(left: box.maxWidth * .05, top: box.maxHeight * .065, width: box.maxWidth * .11, height: box.maxHeight * .055,
        child: Semantics(button: true, label: 'Vissza', child: InkWell(onTap: () => Navigator.pop(context)))),
      Positioned(left: box.maxWidth * .17, right: box.maxWidth * .17, top: box.maxHeight * .195, height: box.maxHeight * .04,
        child: DecoratedBox(decoration: BoxDecoration(color: const Color(0xff003d39), borderRadius: BorderRadius.circular(12)), child: Center(child: FittedBox(child: Text(const ['GLOBÁLIS RANGLISTA', 'ORSZÁGOS RANGLISTA', 'NAPI GLOBÁLIS', 'NAPI ORSZÁGOS'][selected], style: const TextStyle(color: Color(0xfffff0c7), fontFamily: 'serif', fontSize: 25, fontWeight: FontWeight.w900)))))),
      for (int i = 0; i < 4; i++) Positioned(
        left: box.maxWidth * (i.isEven ? .065 : .51),
        top: box.maxHeight * (i < 2 ? .28 : .331),
        width: box.maxWidth * .43, height: box.maxHeight * .043,
        child: Semantics(button: true, selected: selected == i, label: const ['Globális', 'Országos', 'Napi globális', 'Napi országos'][i],
          child: InkWell(onTap: () => select(i), child: DecoratedBox(decoration: BoxDecoration(
            color: selected == i ? const Color(0xffffcc38) : const Color(0xff003d39), borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xffffcf40), width: selected == i ? 2 : 1)),
            child: Center(child: FittedBox(child: Text(const ['Globális', 'Országos', 'Napi globális', 'Napi országos'][i], style: TextStyle(color: selected == i ? const Color(0xff002f2c) : const Color(0xfffff0c7), fontFamily: 'serif', fontSize: 19, fontWeight: FontWeight.w900))))))),
      ),
      FutureBuilder<Map<String, dynamic>>(future: data, builder: (context, snapshot) {
        if (snapshot.hasError) return Positioned(left: 35, right: 35, top: box.maxHeight * .43, child: Column(children: [
          Text(snapshot.error is TrioApiException ? (snapshot.error as TrioApiException).message : 'Nem sikerült betölteni a ranglistát.', style: const TextStyle(color: Colors.white)),
          TextButton(onPressed: () => setState(() => data = load()), child: const Text('Újrapróbálás')),
        ]));
        if (snapshot.connectionState != ConnectionState.done || !snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Colors.amber));
        final top = (snapshot.data!['top'] as List).cast<Map<String, dynamic>>();
        final me = snapshot.data!['me'] as Map<String, dynamic>?;
        return Stack(children: [
          for (int i = 0; i < 5; i++) Positioned(
            left: box.maxWidth * .20, right: box.maxWidth * .065,
            top: box.maxHeight * const [.407, .468, .526, .586, .636][i],
            height: box.maxHeight * .043,
            child: i < top.length ? entry(top[i]) : const Center(child: Text('Még nincs játékos', style: TextStyle(color: Colors.white54))),
          ),
          Positioned(left: box.maxWidth * .07, right: box.maxWidth * .065, top: box.maxHeight * .797, height: box.maxHeight * .065,
            child: me != null ? entry(me, mine: true) : const Center(child: Text('Még nincs helyezésed', style: TextStyle(color: Colors.white)))),
        ]);
      }),
    ])))),
  );
}
