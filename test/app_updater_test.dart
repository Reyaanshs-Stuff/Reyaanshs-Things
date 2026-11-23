import 'package:flutter_test/flutter_test.dart';
import 'package:reyaanshs_things/app_updater.dart';

void main() {
  group('AppUpdater.compareVersions', () {
    test('compares semantic version components before build numbers', () {
      expect(
        AppUpdater.compareVersions('1.0.10+1', '1.0.9+999'),
        greaterThan(0),
      );
    });

    test('uses the build number when semantic versions match', () {
      expect(AppUpdater.compareVersions('1.0.3+4', '1.0.3+3'), greaterThan(0));
      expect(AppUpdater.compareVersions('v1.0.3+4', '1.0.3+4'), 0);
    });

    test('rejects versions that cannot be compared', () {
      expect(
        () => AppUpdater.compareVersions('1.0.3+4', 'latest'),
        throwsFormatException,
      );
    });
  });
}
