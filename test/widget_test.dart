import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:reyaanshs_things/main.dart';

void main() {
  testWidgets('A saved profile opens the home page and survives a restart', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(find.text("Reyaansh's Things"), findsOneWidget);
    expect(find.text('Profile picture URL'), findsOneWidget);
    expect(find.text('Display name'), findsOneWidget);
    expect(find.text('Start Using The App'), findsOneWidget);
    expect(find.text('Login'), findsNothing);
    expect(
      tester.getTopLeft(find.text('Profile picture URL')).dy,
      lessThan(tester.getTopLeft(find.text('Display name')).dy),
    );

    await tester.tap(find.text('Start Using The App'));
    await tester.pump();

    expect(find.text('Enter a display name.'), findsOneWidget);
    expect(find.text('Enter a profile picture URL.'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('display-name')),
      'Reyaansh',
    );
    await tester.enterText(
      find.byKey(const Key('profile-picture-url')),
      'https://example.com/profile.png',
    );
    await tester.pump();

    expect(find.text('Enter a display name.'), findsNothing);
    expect(find.text('Enter a profile picture URL.'), findsNothing);

    await tester.tap(find.text('Start Using The App'));
    await tester.pumpAndSettle();

    expect(find.text('This Page Is Work In Progress :>'), findsOneWidget);
    expect(find.text('My Profile'), findsOneWidget);
    expect(find.text('Reyaansh'), findsOneWidget);

    await tester.tap(find.byTooltip('Open sidebar'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Collapse sidebar'), findsOneWidget);

    await tester.tap(find.byTooltip('Collapse sidebar'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Expand sidebar'), findsOneWidget);

    await tester.tap(find.byTooltip('Expand sidebar'));
    await tester.pumpAndSettle();
    expect(find.text('My Profile'), findsOneWidget);

    tester.view.physicalSize = const Size(1280, 900);
    await tester.pumpAndSettle();
    expect(find.byTooltip('Collapse sidebar'), findsOneWidget);

    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();
    expect(find.text('This Page Is Work In Progress :>'), findsOneWidget);
    expect(find.text('Reyaansh'), findsOneWidget);
  });
}
