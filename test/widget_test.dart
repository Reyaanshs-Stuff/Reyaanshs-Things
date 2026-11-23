import 'package:flutter_test/flutter_test.dart';
import 'package:reyaanshs_things/main.dart';

void main() {
  testWidgets('Supabase setup is required before the app can be used', (
    tester,
  ) async {
    await tester.pumpWidget(const MyApp(configurationError: 'missing'));

    expect(find.text('Connect Supabase'), findsOneWidget);
    expect(find.textContaining('SUPABASE_URL'), findsOneWidget);
    expect(find.textContaining('service-role or secret key'), findsOneWidget);
  });
}
