import 'package:flutter/gestures.dart';
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

    await tester.enterText(find.byKey(const Key('display-name')), 'Reyaansh');
    await tester.enterText(
      find.byKey(const Key('profile-picture-url')),
      'https://example.com/profile.png',
    );
    await tester.pump();

    expect(find.text('Enter a display name.'), findsNothing);
    expect(find.text('Enter a profile picture URL.'), findsNothing);

    await tester.tap(find.text('Start Using The App'));
    await tester.pumpAndSettle();

    expect(find.text("Welcome To Reyaansh's Things :>"), findsOneWidget);
    expect(find.text('This Page Is Work In Progress :>'), findsNothing);
    expect(find.text('Reyaansh'), findsOneWidget);
    final homeAvatar = find.byKey(const Key('home-profile-avatar'));
    expect(homeAvatar, findsOneWidget);
    expect(tester.getTopRight(homeAvatar).dx, greaterThan(300));

    final welcomeCard = find.byKey(const Key('home-welcome-card'));
    final welcomeTitle = find.byKey(const Key('home-welcome-title'));
    expect(
      tester.getTopLeft(homeAvatar).dy,
      lessThan(tester.getTopLeft(welcomeTitle).dy),
    );
    final transparentCard = tester.widget<Card>(
      find.descendant(of: welcomeCard, matching: find.byType(Card)),
    );
    expect(transparentCard.color, Colors.transparent);
    expect(transparentCard.elevation, 0);

    final titleMouse = await tester.createGesture(
      kind: PointerDeviceKind.mouse,
    );
    await titleMouse.addPointer(location: tester.getCenter(welcomeTitle));
    await titleMouse.moveTo(tester.getCenter(welcomeTitle));
    await tester.pump(const Duration(milliseconds: 350));
    final appTheme = tester.widget<MaterialApp>(find.byType(MaterialApp)).theme;
    expect(
      tester.widget<AnimatedDefaultTextStyle>(welcomeTitle).style.color,
      appTheme!.colorScheme.primary,
    );
    await titleMouse.removePointer();

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: tester.getCenter(welcomeCard));
    await mouse.moveTo(tester.getCenter(welcomeCard));
    await tester.pump(const Duration(milliseconds: 350));
    final hoveredDecoration =
        tester.widget<AnimatedContainer>(welcomeCard).decoration!
            as BoxDecoration;
    expect(hoveredDecoration.boxShadow!.single.blurRadius, 40);
    await mouse.removePointer();

    await tester.tap(find.byTooltip('Open sidebar'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Collapse sidebar'), findsOneWidget);
    expect(find.byKey(const Key('sidebar-profile')), findsOneWidget);
    expect(find.text('My Profile'), findsOneWidget);

    await tester.tap(find.byTooltip('Collapse sidebar'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Expand sidebar'), findsOneWidget);

    await tester.tap(find.byTooltip('Expand sidebar'));
    await tester.pumpAndSettle();
    expect(find.text('My Profile'), findsOneWidget);

    tester.view.physicalSize = const Size(1280, 900);
    await tester.pumpAndSettle();
    expect(find.byTooltip('Collapse sidebar'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();
    expect(find.text("Welcome To Reyaansh's Things :>"), findsOneWidget);
    expect(find.text('Reyaansh'), findsOneWidget);
  });
}
