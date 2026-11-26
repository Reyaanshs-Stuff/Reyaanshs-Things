import 'package:flutter_test/flutter_test.dart';
import 'package:reyaanshs_things/utility_tools.dart';

void main() {
  group('UtilityTools', () {
    test('calculates arithmetic with precedence and parentheses', () {
      expect(UtilityTools.calculate('(12 + 8) / 4'), 5);
      expect(UtilityTools.calculate('2 + 3 * 4'), 14);
    });

    test('rejects invalid expressions and division by zero', () {
      expect(() => UtilityTools.calculate('1 / 0'), throwsFormatException);
      expect(() => UtilityTools.calculate('2 +'), throwsFormatException);
    });

    test('converts measurements and temperatures', () {
      expect(
        UtilityTools.convertUnit(
          1000,
          UtilityUnitCategory.length,
          'Meters',
          'Kilometers',
        ),
        1,
      );
      expect(
        UtilityTools.convertUnit(
          32,
          UtilityUnitCategory.temperature,
          'Fahrenheit',
          'Celsius',
        ),
        closeTo(0, 0.000001),
      );
    });

    test('formats JSON and round-trips text encodings', () {
      expect(UtilityTools.formatJson('{"a":1}'), contains('\n'));
      expect(
        UtilityTools.decodeBase64(UtilityTools.encodeBase64('hello')),
        'hello',
      );
      expect(
        UtilityTools.decodeUrl(UtilityTools.encodeUrl('hello world')),
        'hello world',
      );
    });

    test('parses short and full hex colors', () {
      expect(UtilityTools.parseColor('#abc'), 0xFFAABBCC);
      expect(UtilityTools.parseColor('6750A4'), 0xFF6750A4);
      expect(() => UtilityTools.parseColor('bad-color'), throwsFormatException);
    });

    test('creates passwords with the requested length', () {
      expect(
        UtilityTools.generatePassword(length: 32, includeSymbols: false),
        hasLength(32),
      );
    });
  });
}
