import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reyaanshs_things/main.dart';

void main() {
  testWidgets('The profile setup adapts to phones and wide screens', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const MyApp());

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
      'not-a-url',
    );
    await tester.pump();

    expect(find.text('Enter a display name.'), findsNothing);
    expect(find.text('Enter a valid image URL.'), findsOneWidget);

    tester.view.physicalSize = const Size(1280, 900);
    await tester.pumpAndSettle();

    expect(find.text('Profile picture URL'), findsOneWidget);
    expect(find.text('Display name'), findsOneWidget);
    expect(find.text('Start Using The App'), findsOneWidget);
  });
}
