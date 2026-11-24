import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:huntai/main.dart';

void main() {
  testWidgets('shows SOC dashboard and synthetic sample data', (tester) async {
    await tester.pumpWidget(const HuntAiApp());
    final dashboardScrollable = find.descendant(
      of: find.byType(ListView).first,
      matching: find.byType(Scrollable),
    );

    expect(find.text('Security Operations Center'), findsOneWidget);
    expect(find.text('DEMO'), findsWidgets);
    expect(find.text('Security events'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('No vulnerability data available'),
      300,
      scrollable: dashboardScrollable.first,
    );
    expect(find.text('No vulnerability data available'), findsOneWidget);
  });

  testWidgets('can navigate to alerts and mark an alert reviewed',
      (tester) async {
    await tester.pumpWidget(const HuntAiApp());

    await tester.tap(find.byTooltip('Alerts').first);
    await tester.pumpAndSettle();
    expect(find.text('Review suspicious activity and keep track of decisions.'),
        findsOneWidget);

    await tester.tap(find.widgetWithText(FilterChip, 'Critical'));
    await tester.pumpAndSettle();
    expect(find.text('Repeated SSH login failures'), findsOneWidget);
    expect(find.text('Unusual after-hours sign-in'), findsNothing);
    await tester.tap(find.widgetWithText(FilterChip, 'All'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Mark reviewed').first);
    await tester.pumpAndSettle();
    expect(find.text('REVIEWED'), findsOneWidget);
    await tester.tap(find.text('Reopen').first);
    await tester.pumpAndSettle();
    expect(find.text('REVIEWED'), findsNothing);
  });

  testWidgets('dashboard severity filters update sample incidents',
      (tester) async {
    await tester.pumpWidget(const HuntAiApp());
    final dashboardScrollable = find.descendant(
      of: find.byType(ListView).first,
      matching: find.byType(Scrollable),
    );

    await tester.tap(find.widgetWithText(ChoiceChip, 'Critical'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<ChoiceChip>(
            find.widgetWithText(ChoiceChip, 'Critical'),
          )
          .selected,
      isTrue,
    );
    await tester.tap(find.widgetWithText(ChoiceChip, 'Medium'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<ChoiceChip>(
            find.widgetWithText(ChoiceChip, 'Medium'),
          )
          .selected,
      isTrue,
    );
    await tester.scrollUntilVisible(
      find.text('Recent security incidents'),
      300,
      scrollable: dashboardScrollable.first,
    );
    expect(find.text('Unexpected command sequence'), findsOneWidget);
    expect(find.text('Repeated SSH login failures'), findsNothing);
  });

  testWidgets('dashboard fits mobile, tablet, and desktop widths',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    for (final width in [390.0, 768.0, 1199.0, 1440.0]) {
      tester.view.physicalSize = Size(width, 900);
      await tester.pumpWidget(const HuntAiApp());
      await tester.pumpAndSettle();
      expect(find.text('Security Operations Center'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'width $width');
    }
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  testWidgets('search filters local sample alerts', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 900);
    await tester.pumpWidget(const HuntAiApp());

    await tester.enterText(find.byType(TextField), 'ALT-2048');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(find.text('Repeated SSH login failures'), findsOneWidget);
    expect(find.text('Unusual after-hours sign-in'), findsNothing);

    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  testWidgets('mobile sample search can close without controller errors',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpWidget(const HuntAiApp());

    await tester.tap(find.byTooltip('Search sample alerts'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField),
      'ALT-2048',
    );
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  testWidgets('mobile navigation drawer opens existing attack chain page',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpWidget(const HuntAiApp());

    await tester.tap(find.byTooltip('Open navigation'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Attack chain').first);
    await tester.pumpAndSettle();
    expect(
        find.text('See how related sample alerts can form an investigation.'),
        findsOneWidget);

    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  testWidgets('investigations is reachable from mobile navigation',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpWidget(const HuntAiApp());

    await tester.tap(find.byIcon(Icons.folder_open_outlined).last);
    await tester.pumpAndSettle();
    expect(find.text('No investigations yet'), findsOneWidget);
    expect(
      find.textContaining('disappear when this process ends'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);

    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  testWidgets('telemetry, attack chain, settings, and theme remain available',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 900);
    await tester.pumpWidget(const HuntAiApp());

    await tester.tap(find.text('Telemetry').first);
    await tester.pumpAndSettle();
    expect(find.text('A sample feed of normalized security events.'),
        findsOneWidget);

    await tester.tap(find.text('Attack chain').first);
    await tester.pumpAndSettle();
    expect(
        find.text('CHAIN-001 · Possible account compromise'), findsOneWidget);

    await tester.tap(find.text('Settings').first);
    await tester.pumpAndSettle();
    expect(find.text('Data source'), findsOneWidget);
    expect(find.text('Local demo'), findsOneWidget);
    expect(find.text('External services'), findsOneWidget);
    expect(find.text('Not configured'), findsOneWidget);
    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();
    expect(tester.widget<Switch>(find.byType(Switch).first).value, isFalse);
    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();
    expect(tester.widget<Switch>(find.byType(Switch).first).value, isTrue);

    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}
