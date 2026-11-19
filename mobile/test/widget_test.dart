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
}
