import 'dart:convert';

import 'package:http/http.dart' as http;

enum WeatherKind { clear, cloudy, fog, rain, snow, thunderstorm }

class WeatherCondition {
  const WeatherCondition({
    required this.description,
    required this.kind,
    required this.dayIcon,
    required this.nightIcon,
  });

  final String description;
  final WeatherKind kind;
  final String dayIcon;
  final String nightIcon;

  String get icon => dayIcon;

  static WeatherCondition fromCode(int code) => switch (code) {
    0 => const WeatherCondition(
      description: 'Clear sky',
      kind: WeatherKind.clear,
      dayIcon: '☀️',
      nightIcon: '🌙',
    ),
    1 => const WeatherCondition(
      description: 'Mainly clear',
      kind: WeatherKind.clear,
      dayIcon: '🌤️',
      nightIcon: '☁️',
    ),
    2 => const WeatherCondition(
      description: 'Partly cloudy',
      kind: WeatherKind.cloudy,
      dayIcon: '⛅',
      nightIcon: '☁️',
    ),
    3 => const WeatherCondition(
      description: 'Overcast',
      kind: WeatherKind.cloudy,
      dayIcon: '☁️',
      nightIcon: '☁️',
    ),
    45 || 48 => const WeatherCondition(
      description: 'Fog',
      kind: WeatherKind.fog,
      dayIcon: '🌫️',
      nightIcon: '🌫️',
    ),
    51 || 53 || 55 || 56 || 57 => const WeatherCondition(
      description: 'Drizzle',
      kind: WeatherKind.rain,
      dayIcon: '🌦️',
      nightIcon: '🌧️',
    ),
    61 || 63 || 65 || 66 || 67 || 80 || 81 || 82 => const WeatherCondition(
      description: 'Rain',
      kind: WeatherKind.rain,
      dayIcon: '🌧️',
      nightIcon: '🌧️',
    ),
    71 || 73 || 75 || 77 || 85 || 86 => const WeatherCondition(
      description: 'Snow',
      kind: WeatherKind.snow,
      dayIcon: '❄️',
      nightIcon: '❄️',
    ),
    95 || 96 || 99 => const WeatherCondition(
      description: 'Thunderstorm',
      kind: WeatherKind.thunderstorm,
      dayIcon: '⛈️',
      nightIcon: '⛈️',
    ),
    _ => const WeatherCondition(
      description: 'Conditions unavailable',
      kind: WeatherKind.cloudy,
      dayIcon: '☁️',
      nightIcon: '☁️',
    ),
  };
}

class WeatherPlace {
  const WeatherPlace({
    required this.name,
    required this.latitude,
    required this.longitude,
    this.region,
    this.country,
  });

  final String name;
  final double latitude;
  final double longitude;
  final String? region;
  final String? country;

  String get displayName => [
    name,
    if (region != null && region!.isNotEmpty && region != name) region,
    if (country != null && country!.isNotEmpty) country,
  ].join(', ');

  factory WeatherPlace.fromJson(Map<String, dynamic> json) => WeatherPlace(
    name: json['name'] as String? ?? 'Unknown location',
    latitude: (json['latitude'] as num).toDouble(),
    longitude: (json['longitude'] as num).toDouble(),
    region: json['admin1'] as String?,
    country: json['country'] as String?,
  );
}

class HourlyWeather {
  const HourlyWeather({
    required this.time,
    required this.temperature,
    required this.precipitationProbability,
    required this.condition,
  });

  final DateTime time;
  final double temperature;
  final int precipitationProbability;
  final WeatherCondition condition;
}

class DailyWeather {
  const DailyWeather({
    required this.date,
    required this.high,
    required this.low,
    required this.condition,
    required this.sunrise,
    required this.sunset,
  });

  final DateTime date;
  final double high;
  final double low;
  final WeatherCondition condition;
  final DateTime? sunrise;
  final DateTime? sunset;
}

class WeatherForecast {
  const WeatherForecast({
    required this.place,
    required this.timezone,
    required this.currentTime,
    required this.temperature,
    required this.feelsLike,
    required this.humidity,
    required this.windSpeed,
    required this.precipitation,
    required this.isDay,
    required this.condition,
    required this.hourly,
    required this.daily,
  });

  final WeatherPlace place;
  final String timezone;
  final DateTime currentTime;
  final double temperature;
  final double feelsLike;
  final int humidity;
  final double windSpeed;
  final double precipitation;
  final bool isDay;
  final WeatherCondition condition;
  final List<HourlyWeather> hourly;
  final List<DailyWeather> daily;
}

class WeatherApiException implements Exception {
  const WeatherApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class WeatherService {
  WeatherService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  void close() => _client.close();

  Future<List<WeatherPlace>> searchPlaces(String query) async {
    final trimmed = query.trim();
    if (trimmed.length < 2) return const [];
    final uri = Uri.https(
      'geocoding-api.open-meteo.com',
      '/v1/search',
      {'name': trimmed, 'count': '6', 'language': 'en', 'format': 'json'},
    );
    final response = await _client.get(uri).timeout(
      const Duration(seconds: 15),
    );
    if (response.statusCode != 200) {
      throw WeatherApiException(
        'Location search failed (HTTP ${response.statusCode}).',
      );
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final results = payload['results'] as List<dynamic>? ?? const [];
    return results
        .whereType<Map<String, dynamic>>()
        .map(WeatherPlace.fromJson)
        .toList();
  }

  Future<WeatherForecast> getForecast(WeatherPlace place) async {
    final uri = Uri.https('api.open-meteo.com', '/v1/forecast', {
      'latitude': place.latitude.toString(),
      'longitude': place.longitude.toString(),
      'current':
          'temperature_2m,relative_humidity_2m,apparent_temperature,is_day,precipitation,weather_code,wind_speed_10m',
      'hourly': 'temperature_2m,precipitation_probability,weather_code',
      'daily':
          'weather_code,temperature_2m_max,temperature_2m_min,sunrise,sunset',
      'forecast_days': '7',
      'timezone': 'auto',
    });
    final response = await _client.get(uri).timeout(
      const Duration(seconds: 15),
    );
    if (response.statusCode != 200) {
      throw WeatherApiException(
        'Weather request failed (HTTP ${response.statusCode}).',
      );
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    return parseForecast(place, payload);
  }

  static WeatherForecast parseForecast(
    WeatherPlace place,
    Map<String, dynamic> payload,
  ) {
    final current = payload['current'] as Map<String, dynamic>;
    final hourly = payload['hourly'] as Map<String, dynamic>;
    final daily = payload['daily'] as Map<String, dynamic>;
    final hourlyTimes = _list<String>(hourly, 'time');
    final hourlyTemperatures = _list<num>(hourly, 'temperature_2m');
    final hourlyRainChances = _list<num>(
      hourly,
      'precipitation_probability',
    );
    final hourlyCodes = _list<num>(hourly, 'weather_code');
    final currentTime = DateTime.parse(current['time'] as String);
    final currentHour = hourlyTimes.indexWhere((time) {
      final parsed = DateTime.parse(time);
      return parsed.year == currentTime.year &&
          parsed.month == currentTime.month &&
          parsed.day == currentTime.day &&
          parsed.hour == currentTime.hour;
    });
    final firstHour = currentHour < 0 ? 0 : currentHour;
    final hourlyForecast = <HourlyWeather>[];
    for (var index = firstHour;
        index < hourlyTimes.length && hourlyForecast.length < 24;
        index++) {
      hourlyForecast.add(
        HourlyWeather(
          time: DateTime.parse(hourlyTimes[index]),
          temperature: hourlyTemperatures[index].toDouble(),
          precipitationProbability: hourlyRainChances[index].toInt(),
          condition: WeatherCondition.fromCode(hourlyCodes[index].toInt()),
        ),
      );
    }

    final dailyForecast = <DailyWeather>[];
    final dailyDates = _list<String>(daily, 'time');
    final dailyCodes = _list<num>(daily, 'weather_code');
    final highs = _list<num>(daily, 'temperature_2m_max');
    final lows = _list<num>(daily, 'temperature_2m_min');
    final sunrises = _list<String>(daily, 'sunrise');
    final sunsets = _list<String>(daily, 'sunset');
    for (var index = 0; index < dailyDates.length; index++) {
      dailyForecast.add(
        DailyWeather(
          date: DateTime.parse(dailyDates[index]),
          high: highs[index].toDouble(),
          low: lows[index].toDouble(),
          condition: WeatherCondition.fromCode(dailyCodes[index].toInt()),
          sunrise: DateTime.tryParse(sunrises[index]),
          sunset: DateTime.tryParse(sunsets[index]),
        ),
      );
    }

    return WeatherForecast(
      place: place,
      timezone: payload['timezone'] as String? ?? 'Local time',
      currentTime: currentTime,
      temperature: (current['temperature_2m'] as num).toDouble(),
      feelsLike: (current['apparent_temperature'] as num).toDouble(),
      humidity: (current['relative_humidity_2m'] as num).toInt(),
      windSpeed: (current['wind_speed_10m'] as num).toDouble(),
      precipitation: (current['precipitation'] as num).toDouble(),
      isDay: (current['is_day'] as num).toInt() == 1,
      condition: WeatherCondition.fromCode(
        (current['weather_code'] as num).toInt(),
      ),
      hourly: hourlyForecast,
      daily: dailyForecast,
    );
  }

  static List<T> _list<T>(Map<String, dynamic> values, String key) {
    final value = values[key];
    if (value is! List) {
      throw WeatherApiException('Weather data is missing "$key".');
    }
    return value.map((item) {
      if (item is! T) {
        throw WeatherApiException('Weather data contains an invalid "$key".');
      }
      return item;
    }).toList();
  }
}
