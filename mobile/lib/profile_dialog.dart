import 'package:flutter/material.dart';
import 'trio_api.dart';

Future<void> editPlayerProfile(BuildContext context, TrioApi api) async {
  var name = api.playerName ?? '';
  var country = api.countryCode ?? '';
  var saving = false;
  var error = '';
  await showDialog<void>(context: context, builder: (dialogContext) => StatefulBuilder(builder: (_, update) => AlertDialog(
    title: const Text('Játékosprofil'),
    content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
      TextFormField(initialValue: name, maxLength: 255, decoration: const InputDecoration(labelText: 'Teljes név', helperText: 'A ranglistán nyilvánosan megjelenik.'), onChanged: (value) => name = value),
      TextFormField(initialValue: country, maxLength: 2, textCapitalization: TextCapitalization.characters, decoration: const InputDecoration(labelText: 'Országkód', helperText: 'HU: Magyarország, AT: Ausztria, DE: Németország'), onChanged: (value) => country = value.toUpperCase()),
      if (error.isNotEmpty) Text(error, style: const TextStyle(color: Colors.redAccent)),
    ])),
    actions: [
      TextButton(onPressed: saving ? null : () => Navigator.pop(dialogContext), child: const Text('Mégse')),
      TextButton(onPressed: saving ? null : () async {
        if (name.trim().isEmpty || !RegExp(r'^[A-Z]{2}$').hasMatch(country)) { update(() => error = 'Add meg a teljes neved és a kétbetűs országkódot.'); return; }
        update(() { saving = true; error = ''; });
        try {
          await api.saveProfile(name, country);
          if (dialogContext.mounted) Navigator.pop(dialogContext);
        } catch (_) { if (dialogContext.mounted) update(() { saving = false; error = 'A mentés nem sikerült. Próbáld újra!'; }); }
      }, child: Text(saving ? 'Mentés…' : 'Mentés')),
    ],
  )));
}
