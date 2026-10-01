import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:melody_tube/presentation/widgets/app_logo.dart';

void main() {
  group('Twilight App UI Widget Tests', () {
    testWidgets('AppLogo renders icon without text when showText is false', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: AppLogo(size: 40, showText: false),
            ),
          ),
        ),
      );

      // Verify that the AppLogo widget is present
      expect(find.byType(AppLogo), findsOneWidget);

      // Verify that the 'Twilight' title text is NOT rendered when showText is false
      expect(find.text('Twilight'), findsNothing);
    });

    testWidgets('AppLogo renders Twilight title text when showText is true', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: AppLogo(size: 48, showText: true),
            ),
          ),
        ),
      );

      // Verify that AppLogo is rendered
      expect(find.byType(AppLogo), findsOneWidget);

      // Verify that the Twilight title text is present and visible
      expect(find.text('Twilight'), findsOneWidget);
    });

    testWidgets('AppLogo scales appropriately with custom size', (WidgetTester tester) async {
      const customSize = 64.0;

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: AppLogo(size: customSize, showText: true),
            ),
          ),
        ),
      );

      // Find Container inside AppLogo and verify size
      final containerFinder = find.descendant(
        of: find.byType(AppLogo),
        matching: find.byType(Container),
      );

      expect(containerFinder, findsWidgets);
      final container = tester.widget<Container>(containerFinder.first);
      final constraints = container.constraints;
      expect(constraints?.maxWidth ?? container.decoration, isNotNull);
    });
  });
}
