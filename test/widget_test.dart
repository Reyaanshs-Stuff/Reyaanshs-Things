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
    final aboutButton = find.byKey(const Key('sidebar-about'));
    final sidebarProfile = find.byKey(const Key('sidebar-profile'));
    expect(aboutButton, findsOneWidget);
    expect(
      tester.getTopLeft(aboutButton).dy,
      lessThan(tester.getTopLeft(sidebarProfile).dy),
    );
    expect(find.byKey(const Key('sidebar-profile')), findsOneWidget);
    expect(find.text('My Profile'), findsOneWidget);

    await tester.tap(aboutButton);
    await tester.pumpAndSettle();
    expect(find.text('About App'), findsOneWidget);
    expect(find.text("Reyaansh's Things"), findsOneWidget);
    expect(find.text('Reyaanshs-Stuff'), findsOneWidget);
    expect(find.byKey(const Key('about-info-author')), findsOneWidget);
    expect(find.byKey(const Key('about-info-version')), findsOneWidget);
    expect(find.text('Project URL'), findsNothing);

    final appLogoTapTarget = find.byKey(const Key('about-app-logo'));
    for (var tap = 0; tap < 3; tap++) {
      await tester.tap(appLogoTapTarget);
    }
    await tester.pump();
    expect(find.byKey(const Key('physics-board')), findsNothing);
    await tester.tap(appLogoTapTarget);
    await tester.pump();
    expect(find.byKey(const Key('physics-board')), findsOneWidget);
    final physicsAppName = find.byKey(const ValueKey('physics-app-name'));
    final initialPosition = tester.getTopLeft(physicsAppName);
    await tester.drag(physicsAppName, const Offset(30, 36));
    await tester.pump();
    expect(tester.getTopLeft(physicsAppName), isNot(initialPosition));
    await tester.tap(find.byKey(const ValueKey('physics-app-logo')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const Key('physics-board')), findsNothing);

    final brandScale = find.byKey(const Key('about-brand-scale'));
    final appLogo = find.byType(Image).first;
    final appName = find.byKey(const Key('about-app-name'));
    final brandMouse = await tester.createGesture(
      kind: PointerDeviceKind.mouse,
    );
    await brandMouse.addPointer(location: tester.getCenter(appLogo));
    await brandMouse.moveTo(tester.getCenter(appLogo));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.widget<AnimatedScale>(brandScale).scale, 1.04);
    await brandMouse.moveTo(tester.getCenter(appName));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.widget<AnimatedScale>(brandScale).scale, 1.04);
    await brandMouse.moveTo(
      tester.getCenter(find.byKey(const Key('about-info-author'))),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.widget<AnimatedScale>(brandScale).scale, 1);
    await brandMouse.removePointer();
    await tester.tap(find.byKey(const Key('about-back')));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Open sidebar'));
    await tester.pumpAndSettle();
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
