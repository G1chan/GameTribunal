import 'package:flutter_test/flutter_test.dart';
import 'package:game_tribunal/main.dart';

void main() {
  testWidgets('shows the Game Tribunal login screen', (tester) async {
    await tester.pumpWidget(const GameTribunalApp());
    expect(find.text('겜문철'), findsOneWidget);
  });
}
