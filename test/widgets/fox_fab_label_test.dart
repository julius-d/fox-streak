// FoxFabLabel (issue #133): an extended FAB's label never pushes the FAB
// off-screen, and a label that fits is left alone.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fox_streak_app/src/theme/fox_streak_theme.dart';
import 'package:fox_streak_app/src/widgets/widgets.dart';

import 'edge_to_edge_view.dart';

const _fab = Key('fab');

Future<void> _pumpFab(WidgetTester tester, String label) => tester.pumpWidget(
  MaterialApp(
    theme: FoxStreakTheme.light(),
    home: Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        key: _fab,
        onPressed: () {},
        icon: const Icon(Icons.add),
        label: FoxFabLabel(label),
      ),
    ),
  ),
);

void main() {
  testWidgets('a label that fits is the same size as a plain Text label', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: FoxStreakTheme.light(),
        home: Scaffold(
          floatingActionButton: FloatingActionButton.extended(
            key: _fab,
            onPressed: () {},
            icon: const Icon(Icons.add),
            label: const Text('New set'),
          ),
        ),
      ),
    );
    final plain = tester.getRect(find.byKey(_fab));

    await _pumpFab(tester, 'New set');
    expect(tester.getRect(find.byKey(_fab)), plain);
  });

  testWidgets(
    'a long label at 2x text on a narrow phone scales down instead of '
    'pushing the FAB past the screen edge, still fully readable',
    (tester) async {
      simulateEdgeToEdgeView(tester, size: const Size(360, 780), textScale: 2);
      await _pumpFab(tester, 'Marktplatz hinzufügen');

      final fab = tester.getRect(find.byKey(_fab));
      expect(fab.left, greaterThanOrEqualTo(kFloatingActionButtonMargin));
      expect(fab.right, lessThanOrEqualTo(viewSize(tester).width));
      expect(find.text('Marktplatz hinzufügen'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
