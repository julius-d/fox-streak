import 'package:flutter_test/flutter_test.dart';
import 'package:fox_streak_app/main.dart';

void main() {
  testWidgets('Bootstrap home renders', (WidgetTester tester) async {
    await tester.pumpWidget(const FoxStreakApp());

    expect(find.text('FoxStreak'), findsOneWidget);
    expect(find.textContaining('bootstrap OK'), findsOneWidget);
  });
}
