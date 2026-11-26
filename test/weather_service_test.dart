import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:reyaanshs_things/weather_service.dart';

void main() {
  group('WeatherCondition', () {
    test('maps Open-Meteo weather codes to conditions', () {
      expect(WeatherCondition.fromCode(0).kind, WeatherKind.clear);
      expect(WeatherCondition.fromCode(61).description, 'Rain');
      expect(WeatherCondition.fromCode(95).kind, WeatherKind.thunderstorm);
    });
  });

  test('parses current, hourly, and daily forecast data', () {
    final place = WeatherPlace(
      name: 'Wellington',
      latitude: -41.2865,
      longitude: 174.7762,
      country: 'New Zealand',
    );
    final payload = jsonDecode(
      jsonEncode({
        'timezone': 'Pacific/Auckland',
        'current': {
          'time': '2026-11-26T13:00',
          'temperature_2m': 18.5,
          'apparent_temperature': 17.2,
          'relative_humidity_2m': 66,
          'wind_speed_10m': 12.4,
          'precipitation': 0.1,
          'weather_code': 2,
          'is_day': 1,
        },
        'hourly': {
          'time': ['2026-11-26T13:00', '2026-11-26T14:00'],
          'temperature_2m': [18.5, 19.0],
          'precipitation_probability': [10, 15],
          'weather_code': [2, 1],
        },
        'daily': {
          'time': ['2026-11-26'],
          'weather_code': [2],
          'temperature_2m_max': [21.0],
          'temperature_2m_min': [13.0],
          'sunrise': ['2026-11-26T05:55'],
          'sunset': ['2026-11-26T20:30'],
        },
      }),
    ) as Map<String, dynamic>;
    final forecast = WeatherService.parseForecast(place, payload);

    expect(forecast.place.displayName, 'Wellington, New Zealand');
    expect(forecast.temperature, 18.5);
    expect(forecast.humidity, 66);
    expect(forecast.isDay, isTrue);
    expect(forecast.hourly, hasLength(2));
    expect(forecast.hourly.first.precipitationProbability, 10);
    expect(forecast.daily.single.high, 21);
    expect(forecast.daily.single.sunrise, isNotNull);
  });
}
