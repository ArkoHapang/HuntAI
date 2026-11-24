import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huntai/main.dart';

void main() {
  group('Settings navigation and details', () {
    testWidgets('can navigate to Data Source details and back', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1440, 900);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(const HuntAiApp());
      await tester.pumpAndSettle();

      // Navigate to Settings
      await tester.tap(find.text('Settings').first);
      await tester.pumpAndSettle();

      expect(find.text('Data source'), findsOneWidget);
      expect(find.text('Local demo'), findsOneWidget);

      // Tap Data Source card
      await tester.tap(find.text('Data source'));
      await tester.pumpAndSettle();

      // Verify Data Source details page is displayed
      expect(find.byType(DataSourceDetailsScreen), findsOneWidget);
      expect(find.text('Data source details'), findsOneWidget);

      // Tap Back button
      await tester.tap(find.byTooltip('Back to settings'));
      await tester.pumpAndSettle();

      // Verify back on Settings main view
      expect(find.byType(DataSourceDetailsScreen), findsNothing);
      expect(find.text('Data source'), findsOneWidget);
      expect(find.text('External services'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('displays complete Data Source information and disclosures',
        (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1440, 900);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(const HuntAiApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Settings').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Data source'));
      await tester.pumpAndSettle();

      final screenFinder = find.byType(DataSourceDetailsScreen);
      final detailsScrollable = find.descendant(
        of: screenFinder,
        matching: find.byType(Scrollable),
      );

      // 1. Current source (at top)
      expect(find.text('Local synthetic demo fixtures'), findsOneWidget);

      // 2. Telemetry status (at top)
      expect(
        find.text('Not connected (no active agent or stream)'),
        findsOneWidget,
      );

      // 3. Persistence (at top)
      expect(
        find.text('In-memory / volatile demo data'),
        findsOneWidget,
      );

      // 4. Not monitoring real systems disclosure (at top)
      expect(
        find.textContaining('not monitoring real systems'),
        findsWidgets,
      );

      // 5. Available categories (top items)
      expect(
        find.descendant(of: screenFinder, matching: find.text('Alerts')),
        findsOneWidget,
      );
      expect(
        find.descendant(
            of: screenFinder, matching: find.text('Security events')),
        findsOneWidget,
      );

      // 6. Progressive scroll to lower categories
      await tester.scrollUntilVisible(
        find.descendant(
            of: screenFinder, matching: find.text('Graph entities')),
        200,
        scrollable: detailsScrollable.first,
      );
      expect(
        find.descendant(
            of: screenFinder, matching: find.text('Graph entities')),
        findsOneWidget,
      );

      await tester.scrollUntilVisible(
        find.descendant(
            of: screenFinder, matching: find.text('Graph relationships')),
        200,
        scrollable: detailsScrollable.first,
      );
      expect(
        find.descendant(
            of: screenFinder, matching: find.text('Graph relationships')),
        findsOneWidget,
      );

      // 7. Data provenance & persistence disclosures
      await tester.scrollUntilVisible(
        find.text('Data provenance & synthetic-data disclosure'),
        300,
        scrollable: detailsScrollable.first,
      );
      expect(
        find.text('Data provenance & synthetic-data disclosure'),
        findsOneWidget,
      );
      expect(
        find.textContaining(
            'synthetic demonstration fixtures created specifically'),
        findsOneWidget,
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('can navigate to External Services catalogue and back',
        (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1440, 900);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(const HuntAiApp());
      await tester.pumpAndSettle();

      // Navigate to Settings
      await tester.tap(find.text('Settings').first);
      await tester.pumpAndSettle();

      expect(find.text('External services'), findsOneWidget);
      expect(find.text('Not configured'), findsOneWidget);

      // Tap External services card
      await tester.tap(find.text('External services'), warnIfMissed: false);
      await tester.pumpAndSettle();

      // Verify External services catalogue is displayed
      expect(find.byType(ExternalServicesCatalogueScreen), findsOneWidget);
      expect(find.text('External services catalogue'), findsOneWidget);

      // Tap Back button
      await tester.tap(find.byTooltip('Back to settings'));
      await tester.pumpAndSettle();

      // Verify back on Settings main view
      expect(find.byType(ExternalServicesCatalogueScreen), findsNothing);
      expect(find.text('Data source'), findsOneWidget);
      expect(find.text('External services'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'catalogue lists all four services with purposes and limitations',
        (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1440, 900);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(const HuntAiApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Settings').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('External services'), warnIfMissed: false);
      await tester.pumpAndSettle();

      final catalogueScrollable = find.descendant(
        of: find.byType(ExternalServicesCatalogueScreen),
        matching: find.byType(Scrollable),
      );

      // MITRE ATT&CK
      expect(find.text('MITRE ATT&CK'), findsOneWidget);
      expect(find.text('ATT&CK technique references.'), findsOneWidget);
      expect(find.text('Reference support exists'), findsWidgets);
      expect(find.text('Default verification is unavailable.'), findsOneWidget);

      // VirusTotal
      expect(find.text('VirusTotal'), findsOneWidget);
      expect(find.text('Threat-intelligence enrichment.'), findsOneWidget);
      expect(find.text('No API integration or live lookups.'), findsOneWidget);

      // Scroll to External AI provider
      await tester.scrollUntilVisible(
        find.text('External AI provider'),
        300,
        scrollable: catalogueScrollable.first,
      );
      expect(find.text('External AI provider'), findsOneWidget);
      expect(
        find.text('External AI-powered hypothesis generation.'),
        findsOneWidget,
      );
      expect(
        find.text('Current hypothesis generation is deterministic and local.'),
        findsOneWidget,
      );

      // Scroll to Live SIEM integration
      await tester.scrollUntilVisible(
        find.text('Live SIEM integration'),
        300,
        scrollable: catalogueScrollable.first,
      );
      expect(find.text('Live SIEM integration'), findsOneWidget);
      expect(find.text('Import real security events.'), findsOneWidget);
      expect(find.text('No live SIEM connection.'), findsOneWidget);

      // Scroll to Security & credential boundary
      await tester.scrollUntilVisible(
        find.text('Integration security & credential boundary'),
        300,
        scrollable: catalogueScrollable.first,
      );
      expect(
        find.text('Integration security & credential boundary'),
        findsOneWidget,
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('responsive layout on mobile, tablet, and desktop widths',
        (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      for (final width in [390.0, 768.0, 1199.0, 1440.0]) {
        tester.view.physicalSize = Size(width, 900);

        // Test Data Source Details Screen standalone
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: const Scaffold(
              body: DataSourceDetailsScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Data source details'), findsOneWidget);
        expect(tester.takeException(), isNull,
            reason: 'Data Source Details width $width');

        // Test External Services Catalogue Screen standalone
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: const Scaffold(
              body: ExternalServicesCatalogueScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('External services catalogue'), findsOneWidget);
        expect(tester.takeException(), isNull,
            reason: 'External Services Catalogue width $width');
      }
    });

    testWidgets('preserves existing Settings behavior and theme switching',
        (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1440, 900);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(const HuntAiApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Settings').first);
      await tester.pumpAndSettle();

      expect(find.text('Dark theme'), findsOneWidget);
      final switchFinder = find.byType(Switch).first;
      expect(tester.widget<Switch>(switchFinder).value, isTrue);

      // Toggle theme off
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();
      expect(tester.widget<Switch>(switchFinder).value, isFalse);

      // Toggle theme back on
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();
      expect(tester.widget<Switch>(switchFinder).value, isTrue);

      expect(tester.takeException(), isNull);
    });

    testWidgets('mobile navigation drawer reaches settings and subpages',
        (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(const HuntAiApp());
      await tester.pumpAndSettle();

      // Open navigation drawer
      await tester.tap(find.byTooltip('Open navigation'));
      await tester.pumpAndSettle();

      // Tap Settings inside drawer
      await tester.tap(find.descendant(
        of: find.byType(Drawer),
        matching: find.text('Settings'),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Data source'), findsOneWidget);
      await tester.tap(find.text('Data source'));
      await tester.pumpAndSettle();
      expect(find.byType(DataSourceDetailsScreen), findsOneWidget);

      await tester.tap(find.byTooltip('Back to settings'));
      await tester.pumpAndSettle();
      expect(find.byType(DataSourceDetailsScreen), findsNothing);

      // Scroll settings list on mobile so External services is built and above bottom nav
      final settingsScrollable = find.descendant(
        of: find.byType(SettingsPage),
        matching: find.byType(Scrollable),
      );
      await tester.scrollUntilVisible(
        find.text('External services'),
        100,
        scrollable: settingsScrollable.first,
      );
      await tester.drag(settingsScrollable.first, const Offset(0, -100));
      await tester.pumpAndSettle();

      await tester.tap(find.text('External services'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.byType(ExternalServicesCatalogueScreen), findsOneWidget);

      await tester.tap(find.byTooltip('Back to settings'));
      await tester.pumpAndSettle();
      expect(find.byType(ExternalServicesCatalogueScreen), findsNothing);

      expect(tester.takeException(), isNull);
    });
  });
}
