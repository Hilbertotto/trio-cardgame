import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:trio_android/main.dart';

void main() {
  test('a 7-es trió azonnal megnyeri a játékot', () {
    expect(isWinningTrio(7, 1), isTrue);
  });

  test('három megszerzett trió megnyeri a játékot', () {
    expect(isWinningTrio(4, 3), isTrue);
    expect(isWinningTrio(4, 2), isFalse);
  });

  testWidgets('TRIO kezdőképernyő megjelenik', (tester) async {
    await tester.pumpWidget(const TrioApp());
    expect(find.bySemanticsLabel('Játék indítása'), findsOneWidget);
    expect(find.bySemanticsLabel('Bejelentkezés'), findsOneWidget);
  });

  testWidgets('a trió lapjai sorban kerülnek a nyertes paklijára', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const TrioApp());
    final dynamic game = tester.state(find.byType(TrioGame));
    game.count = 3;
    game.start();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    game.turn = 1;
    game.shown = [for (int slot = 0; slot < 3; slot++) R(7, 'table', -1, slot)];
    final Future<void> resolution = game.resolve();
    await tester.pump();
    expect(game.collectedRevealCount, 0);

    await tester.pump(const Duration(milliseconds: 350));
    expect(game.collectedRevealCount, 1);
    for (int collected = 2; collected <= 3; collected++) {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 340));
      expect(game.collectedRevealCount, collected);
      expect(game.ps[1].trios, isEmpty);
      expect(game.gameOver, isFalse);
    }
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 340));
    await resolution;

    expect(game.ps[0].trios, isEmpty);
    expect(game.ps[1].trios, [7]);
    expect(game.winner, game.ps[1].name);
    expect(game.gameOver, isTrue);
  });
}
