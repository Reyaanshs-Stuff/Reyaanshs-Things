import 'dart:convert';
import 'dart:math';

enum UtilityUnitCategory { length, weight, temperature, volume }

class UtilityTools {
  static double calculate(String expression) =>
      _ExpressionParser(expression).parse();

  static String formatJson(String input, {bool pretty = true}) {
    final value = jsonDecode(input);
    return pretty
        ? const JsonEncoder.withIndent('  ').convert(value)
        : jsonEncode(value);
  }

  static String encodeBase64(String input) =>
      base64Encode(utf8.encode(input));

  static String decodeBase64(String input) =>
      utf8.decode(base64Decode(input.trim()));

  static String encodeUrl(String input) => Uri.encodeComponent(input);

  static String decodeUrl(String input) => Uri.decodeComponent(input);

  static double convertUnit(
    double value,
    UtilityUnitCategory category,
    String from,
    String to,
  ) {
    if (category == UtilityUnitCategory.temperature) {
      final celsius = switch (from) {
        'Celsius' => value,
        'Fahrenheit' => (value - 32) * 5 / 9,
        'Kelvin' => value - 273.15,
        _ => throw ArgumentError.value(from, 'from'),
      };
      return switch (to) {
        'Celsius' => celsius,
        'Fahrenheit' => celsius * 9 / 5 + 32,
        'Kelvin' => celsius + 273.15,
        _ => throw ArgumentError.value(to, 'to'),
      };
    }

    final factors = switch (category) {
      UtilityUnitCategory.length => const {
        'Millimeters': 0.001,
        'Centimeters': 0.01,
        'Meters': 1.0,
        'Kilometers': 1000.0,
        'Inches': 0.0254,
        'Feet': 0.3048,
        'Miles': 1609.344,
      },
      UtilityUnitCategory.weight => const {
        'Milligrams': 0.000001,
        'Grams': 0.001,
        'Kilograms': 1.0,
        'Ounces': 0.028349523125,
        'Pounds': 0.45359237,
      },
      UtilityUnitCategory.volume => const {
        'Milliliters': 0.001,
        'Liters': 1.0,
        'Cups (US)': 0.2365882365,
        'Pints (US)': 0.473176473,
        'Gallons (US)': 3.785411784,
      },
      UtilityUnitCategory.temperature => const <String, double>{},
    };

    final fromFactor = factors[from];
    final toFactor = factors[to];
    if (fromFactor == null || toFactor == null) {
      throw ArgumentError('The selected units are not valid for this category.');
    }
    return value * fromFactor / toFactor;
  }

  static int countWords(String text) =>
      RegExp(r'\S+').allMatches(text).length;

  static String titleCase(String text) => text
      .split(RegExp(r'(\s+)'))
      .map(
        (part) => part.trim().isEmpty
            ? part
            : '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}',
      )
      .join();

  static int parseColor(String input) {
    var hex = input.trim().replaceFirst('#', '');
    if (hex.length == 3) {
      hex = hex.split('').map((digit) => '$digit$digit').join();
    }
    if (hex.length != 6 || !RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(hex)) {
      throw const FormatException('Enter a color as #RGB or #RRGGBB.');
    }
    return int.parse('FF$hex', radix: 16);
  }

  static String generatePassword({
    int length = 20,
    bool includeSymbols = true,
  }) {
    const letters = 'abcdefghijkmnopqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ';
    const digits = '23456789';
    const symbols = '!@#\$%^&*()-_=+[]{}?';
    final characters = '$letters$digits${includeSymbols ? symbols : ''}';
    final random = Random.secure();
    return List.generate(
      length,
      (_) => characters[random.nextInt(characters.length)],
    ).join();
  }

  static DateTime unixTimestampToDateTime(String input) {
    final trimmed = input.trim();
    final value = int.parse(trimmed);
    final digits = trimmed.startsWith('-') || trimmed.startsWith('+')
        ? trimmed.length - 1
        : trimmed.length;
    final milliseconds = digits > 10 ? value : value * 1000;
    return DateTime.fromMillisecondsSinceEpoch(milliseconds, isUtc: true);
  }
}

class _ExpressionParser {
  _ExpressionParser(this.input);

  final String input;
  int _position = 0;

  double parse() {
    final result = _parseExpression();
    _skipWhitespace();
    if (_position != input.length) {
      throw const FormatException('Unexpected character in expression.');
    }
    return result;
  }

  double _parseExpression() {
    var value = _parseTerm();
    while (true) {
      _skipWhitespace();
      if (_take('+')) {
        value += _parseTerm();
      } else if (_take('-')) {
        value -= _parseTerm();
      } else {
        return value;
      }
    }
  }

  double _parseTerm() {
    var value = _parseFactor();
    while (true) {
      _skipWhitespace();
      if (_take('*')) {
        value *= _parseFactor();
      } else if (_take('/')) {
        final divisor = _parseFactor();
        if (divisor == 0) {
          throw const FormatException('Cannot divide by zero.');
        }
        value /= divisor;
      } else {
        return value;
      }
    }
  }

  double _parseFactor() {
    _skipWhitespace();
    if (_take('+')) return _parseFactor();
    if (_take('-')) return -_parseFactor();
    if (_take('(')) {
      final value = _parseExpression();
      _skipWhitespace();
      if (!_take(')')) {
        throw const FormatException('Missing closing parenthesis.');
      }
      return value;
    }

    final start = _position;
    var hasDigit = false;
    while (_position < input.length &&
        RegExp(r'[0-9.]').hasMatch(input[_position])) {
      if (input[_position] != '.') hasDigit = true;
      _position++;
    }
    if (!hasDigit) {
      throw const FormatException('Enter a valid arithmetic expression.');
    }
    final number = double.tryParse(input.substring(start, _position));
    if (number == null) {
      throw const FormatException('Enter a valid number.');
    }
    return number;
  }

  bool _take(String character) {
    if (_position >= input.length || input[_position] != character) {
      return false;
    }
    _position++;
    return true;
  }

  void _skipWhitespace() {
    while (_position < input.length &&
        input[_position].trim().isEmpty) {
      _position++;
    }
  }
}

