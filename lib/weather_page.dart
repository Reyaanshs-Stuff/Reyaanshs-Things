import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'weather_service.dart';

class WeatherPage extends StatefulWidget {
  const WeatherPage({required this.isWide, required this.onBack, super.key});

  final bool isWide;
  final VoidCallback onBack;

  @override
  State<WeatherPage> createState() => _WeatherPageState();
}

class _WeatherPageState extends State<WeatherPage> {
  static const _savedLocationKey = 'weather.saved_location';

  final _service = WeatherService();
  final _cityController = TextEditingController();
  WeatherForecast? _forecast;
  List<WeatherPlace> _places = const [];
  bool _isLoading = false;
  bool _isSearching = false;
  bool _isHeroHovered = false;
  int? _hoveredHourIndex;
  int? _hoveredDayIndex;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_restoreSavedLocation());
  }

  @override
  void dispose() {
    _cityController.dispose();
    _service.close();
    super.dispose();
  }

  Future<void> _restoreSavedLocation() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final saved = preferences.getString(_savedLocationKey);
      if (saved == null) return;

      final decoded = jsonDecode(saved);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Saved location has an invalid format.');
      }
      final place = WeatherPlace.fromJson(decoded);
      _cityController.text = place.name;
      await _loadForecast(place, persistLocation: false);
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() => _error = 'Could not restore the saved location: $error');
    }
  }

  Future<void> _saveLocation(WeatherPlace place) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _savedLocationKey,
      jsonEncode({
        'name': place.name,
        'latitude': place.latitude,
        'longitude': place.longitude,
        'admin1': place.region,
        'country': place.country,
      }),
    );
  }

  Future<void> _useDeviceLocation() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _places = const [];
    });
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission != LocationPermission.whileInUse &&
          permission != LocationPermission.always) {
        throw const _WeatherPageException(
          'Location access was denied. Allow it in your device settings or search for a city.',
        );
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 25),
        ),
      );
      await _loadForecast(
        WeatherPlace(
          name: 'Current location',
          latitude: position.latitude,
          longitude: position.longitude,
        ),
        manageLoading: false,
      );
    } on LocationServiceDisabledException {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'Location services are turned off. Enable them or search for a city.';
      });
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = error is _WeatherPageException
            ? error.message
            : 'Could not get your location: $error';
      });
    }
  }

  Future<void> _searchCity() async {
    setState(() {
      _isSearching = true;
      _error = null;
      _places = const [];
    });
    try {
      final places = await _service.searchPlaces(_cityController.text);
      if (!mounted) return;
      setState(() {
        _isSearching = false;
        _places = places;
        if (places.isEmpty) {
          _error = 'No matching places found. Try another name.';
        }
      });
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() {
        _isSearching = false;
        _error = 'Location search failed: $error';
      });
    }
  }

  Future<void> _loadForecast(
    WeatherPlace place, {
    bool manageLoading = true,
    bool persistLocation = true,
  }) async {
    if (manageLoading && mounted) {
      setState(() {
        _isLoading = true;
        _error = null;
        _places = const [];
      });
    }
    String? saveWarning;
    if (persistLocation) {
      try {
        await _saveLocation(place);
      } on Exception catch (error) {
        saveWarning = 'Could not save this location: $error';
      }
    }

    try {
      final forecast = await _service.getForecast(place);
      if (!mounted) return;
      setState(() {
        _forecast = forecast;
        _isLoading = false;
        _error = saveWarning;
        _cityController.text = place.name;
      });
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = [
          ?saveWarning,
          'Weather could not be loaded: $error',
        ].join('\n');
      });
    }
  }

  List<Color> _weatherGradient(WeatherForecast forecast) {
    final isDay = forecast.isDay;
    if (forecast.daily.isNotEmpty) {
      final today = forecast.daily.first;
      final nearSunrise =
          today.sunrise != null &&
          forecast.currentTime.difference(today.sunrise!).inMinutes.abs() <= 60;
      final nearSunset =
          today.sunset != null &&
          forecast.currentTime.difference(today.sunset!).inMinutes.abs() <= 60;
      if (nearSunrise || nearSunset) {
        return const [Color(0xFF69569B), Color(0xFFE8938A), Color(0xFFFFC56C)];
      }
    }
    return switch (forecast.condition.kind) {
      WeatherKind.clear =>
        isDay
            ? const [Color(0xFF1689C9), Color(0xFF56C3D7), Color(0xFFF3B45B)]
            : const [Color(0xFF111B3D), Color(0xFF334B78), Color(0xFF6760A4)],
      WeatherKind.cloudy =>
        isDay
            ? const [Color(0xFF4F7894), Color(0xFF789EAF), Color(0xFFBBC9C6)]
            : const [Color(0xFF1E2D43), Color(0xFF40536B), Color(0xFF617080)],
      WeatherKind.fog =>
        isDay
            ? const [Color(0xFF607D8B), Color(0xFF9AAEB4), Color(0xFFD0D1C8)]
            : const [Color(0xFF222D3B), Color(0xFF45535C), Color(0xFF677174)],
      WeatherKind.rain => const [
        Color(0xFF182A49),
        Color(0xFF315579),
        Color(0xFF537F9A),
      ],
      WeatherKind.snow =>
        isDay
            ? const [Color(0xFF6397B6), Color(0xFFA8CDD9), Color(0xFFE1EAF1)]
            : const [Color(0xFF1C3455), Color(0xFF547D9B), Color(0xFFA5C2D2)],
      WeatherKind.thunderstorm => const [
        Color(0xFF17162D),
        Color(0xFF332B55),
        Color(0xFF51466F),
      ],
    };
  }

  String _weekday(DateTime date, {bool today = false}) {
    if (today) return 'Today';
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return names[date.weekday - 1];
  }

  Widget _weatherIcon(
    WeatherCondition condition, {
    required bool isDay,
    double size = 56,
    Color color = Colors.white,
  }) {
    final icon = switch (condition.kind) {
      WeatherKind.clear =>
        isDay ? Icons.wb_sunny_rounded : Icons.nightlight_round,
      WeatherKind.cloudy => Icons.cloud_rounded,
      WeatherKind.fog => Icons.cloud_queue_rounded,
      WeatherKind.rain => Icons.grain_rounded,
      WeatherKind.snow => Icons.ac_unit_rounded,
      WeatherKind.thunderstorm => Icons.flash_on_rounded,
    };
    return Icon(
      icon,
      key: ValueKey('${condition.kind}-$isDay'),
      size: size,
      color: color,
    );
  }

  Widget _heroCard(WeatherForecast forecast) {
    final colors = _weatherGradient(forecast);
    return MouseRegion(
      onEnter: (_) => setState(() => _isHeroHovered = true),
      onExit: (_) => setState(() => _isHeroHovered = false),
      child: AnimatedScale(
        scale: _isHeroHovered ? 1.008 : 1,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 1000),
          curve: Curves.easeInOut,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: colors,
            ),
            boxShadow: [
              BoxShadow(
                color: colors.first.withValues(
                  alpha: _isHeroHovered ? 0.42 : 0.3,
                ),
                blurRadius: _isHeroHovered ? 44 : 35,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: Stack(
              children: [
                Positioned(
                  right: -40,
                  top: -72,
                  child: Container(
                    width: 230,
                    height: 230,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                ),
                Positioned(
                  left: -80,
                  bottom: -150,
                  child: Container(
                    width: 290,
                    height: 290,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.07),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            color: Colors.white70,
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              forecast.place.displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Refresh forecast',
                            onPressed: _isLoading
                                ? null
                                : () => _loadForecast(forecast.place),
                            icon: const Icon(
                              Icons.refresh_rounded,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            flex: 5,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${forecast.temperature.round()}°',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 86,
                                    height: 0.98,
                                    fontWeight: FontWeight.w300,
                                    letterSpacing: -6,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  forecast.condition.description,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 21,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Feels like ${forecast.feelsLike.round()}°  ·  '
                                  '${forecast.isDay ? 'Daytime' : 'Night'}',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            flex: 4,
                            child: Center(
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 350),
                                child: _weatherIcon(
                                  forecast.condition,
                                  isDay: forecast.isDay,
                                  size: 112,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          _heroMetric(
                            Icons.water_drop_outlined,
                            '${forecast.humidity}%',
                            'Humidity',
                          ),
                          const SizedBox(width: 24),
                          _heroMetric(
                            Icons.air_rounded,
                            '${forecast.windSpeed.round()} km/h',
                            'Wind',
                          ),
                          const SizedBox(width: 24),
                          _heroMetric(
                            Icons.umbrella_outlined,
                            '${forecast.precipitation} mm',
                            'Precip.',
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Local time · ${forecast.timezone.replaceAll('_', ' ')}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _heroMetric(IconData icon, String value, String label) => Expanded(
    child: Row(
      children: [
        Icon(icon, color: Colors.white70, size: 20),
        const SizedBox(width: 8),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                label,
                style: const TextStyle(color: Colors.white70, fontSize: 11),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _sectionTitle(String title, {Widget? trailing}) => Padding(
    padding: const EdgeInsets.fromLTRB(2, 24, 2, 12),
    child: Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        ?trailing,
      ],
    ),
  );

  Widget _hourlyForecast(WeatherForecast forecast) {
    return SizedBox(
      height: 142,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: forecast.hourly.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final item = forecast.hourly[index];
          final isHovered = _hoveredHourIndex == index;
          return MouseRegion(
            onEnter: (_) => setState(() => _hoveredHourIndex = index),
            onExit: (_) => setState(() => _hoveredHourIndex = null),
            child: AnimatedScale(
              scale: isHovered ? 1.06 : 1,
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              child: Container(
                width: 76,
                padding: const EdgeInsets.symmetric(
                  vertical: 14,
                  horizontal: 8,
                ),
                decoration: BoxDecoration(
                  color: isHovered
                      ? Theme.of(context).colorScheme.primaryContainer
                      : Theme.of(context).colorScheme.surface
                            .withValues(alpha: index == 0 ? 0.94 : 0.68),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isHovered
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.outlineVariant,
                  ),
                  boxShadow: isHovered
                      ? [
                          BoxShadow(
                            color: Theme.of(context).colorScheme.primary
                                .withValues(alpha: 0.16),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ]
                      : const [],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      index == 0
                          ? 'Now'
                          : item.time.hour == 0
                          ? '12 AM'
                          : item.time.hour < 12
                          ? '${item.time.hour} AM'
                          : item.time.hour == 12
                          ? '12 PM'
                          : '${item.time.hour - 12} PM',
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                    _weatherIcon(
                      item.condition,
                      isDay: item.time.hour >= 6 && item.time.hour < 19,
                      size: 28,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    Text(
                      '${item.temperature.round()}°',
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      '${item.precipitationProbability}% rain',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _dailyForecast(WeatherForecast forecast) {
    return Card(
      margin: EdgeInsets.zero,
      color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.78),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: Column(
        children: [
          for (var index = 0; index < forecast.daily.length; index++) ...[
            if (index > 0)
              Divider(
                height: 1,
                indent: 16,
                endIndent: 16,
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            MouseRegion(
              onEnter: (_) => setState(() => _hoveredDayIndex = index),
              onExit: (_) => setState(() => _hoveredDayIndex = null),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: _hoveredDayIndex == index
                      ? Theme.of(context).colorScheme.primaryContainer
                      : Colors.transparent,
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 54,
                      child: Text(
                        _weekday(forecast.daily[index].date, today: index == 0),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(width: 4),
                    _weatherIcon(
                      forecast.daily[index].condition,
                      isDay: true,
                      size: 26,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        forecast.daily[index].condition.description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                    Text(
                      '${forecast.daily[index].low.round()}°',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 38,
                      child: Text(
                        '${forecast.daily[index].high.round()}°',
                        textAlign: TextAlign.end,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _sunTimes(WeatherForecast forecast) {
    final today = forecast.daily.isEmpty ? null : forecast.daily.first;
    if (today == null || today.sunrise == null || today.sunset == null) {
      return const SizedBox.shrink();
    }
    return Row(
      children: [
        Expanded(
          child: _sunCard(
            Icons.wb_twilight_rounded,
            'Sunrise',
            _formatTime(today.sunrise!),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _sunCard(
            Icons.wb_twilight_rounded,
            'Sunset',
            _formatTime(today.sunset!),
          ),
        ),
      ],
    );
  }

  String _formatTime(DateTime time) {
    final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute ${time.hour < 12 ? 'AM' : 'PM'}';
  }

  Widget _sunCard(IconData icon, String label, String value) => Card(
    margin: EdgeInsets.zero,
    color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.78),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.labelMedium),
              Text(value, style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
        ],
      ),
    ),
  );

  Widget _locationSearch() => Row(
    children: [
      Expanded(
        child: TextField(
          controller: _cityController,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => _searchCity(),
          decoration: InputDecoration(
            hintText: 'Search a city or postal code',
            prefixIcon: const Icon(Icons.search_rounded),
            filled: true,
            fillColor: Theme.of(context).colorScheme.surface
                .withValues(alpha: 0.84),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ),
      const SizedBox(width: 8),
      IconButton.filledTonal(
        tooltip: 'Search city',
        onPressed: _isSearching ? null : _searchCity,
        icon: _isSearching
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.arrow_forward_rounded),
      ),
    ],
  );

  Widget _emptyState() {
    final colors = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      color: colors.surface.withValues(alpha: 0.82),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(26),
        side: BorderSide(color: colors.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(Icons.my_location_rounded, size: 40, color: colors.primary),
            const SizedBox(height: 12),
            Text(
              'Your forecast, your way',
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              'Allow location access for local weather, or search for any city.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _isLoading ? null : _useDeviceLocation,
              icon: const Icon(Icons.near_me_rounded),
              label: const Text('Use my location'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final forecast = _forecast;
    return Stack(
      children: [
        Positioned.fill(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 1100),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: forecast == null
                    ? [
                        Theme.of(context).colorScheme.surface,
                        Theme.of(context).colorScheme.primaryContainer
                            .withValues(alpha: 0.45),
                      ]
                    : [
                        _weatherGradient(forecast).first
                            .withValues(alpha: 0.42),
                        Theme.of(context).colorScheme.surface,
                        _weatherGradient(forecast).last.withValues(alpha: 0.26),
                      ],
              ),
            ),
          ),
        ),
        Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 24, 8),
              child: Row(
                children: [
                  if (!widget.isWide)
                    IconButton(
                      tooltip: 'Back',
                      onPressed: widget.onBack,
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                  Expanded(
                    child: Text(
                      'Weather',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  if (widget.isWide) ...[
                    const Icon(Icons.cloud_outlined),
                    const SizedBox(width: 8),
                    Text(
                      'Open-Meteo',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 8, 24, 28),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 900),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _locationSearch(),
                        if (_places.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Card(
                            margin: EdgeInsets.zero,
                            child: Column(
                              children: [
                                for (final place in _places)
                                  ListTile(
                                    leading: const Icon(
                                      Icons.location_on_outlined,
                                    ),
                                    title: Text(place.name),
                                    subtitle: Text(place.displayName),
                                    onTap: () => _loadForecast(place),
                                  ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: _isLoading ? null : _useDeviceLocation,
                          icon: const Icon(Icons.my_location_rounded),
                          label: const Text('Use current device location'),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          Material(
                            color: Theme.of(context).colorScheme.errorContainer,
                            borderRadius: BorderRadius.circular(16),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.info_outline_rounded,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onErrorContainer,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      _error!,
                                      style: TextStyle(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onErrorContainer,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                        if (_isLoading) ...[
                          const SizedBox(height: 18),
                          const LinearProgressIndicator(),
                        ],
                        if (forecast == null) ...[
                          const SizedBox(height: 16),
                          _emptyState(),
                        ] else ...[
                          const SizedBox(height: 18),
                          _heroCard(forecast),
                          _sectionTitle('Next 24 hours'),
                          _hourlyForecast(forecast),
                          _sectionTitle('7-day forecast'),
                          _dailyForecast(forecast),
                          _sectionTitle('Sunrise & sunset'),
                          _sunTimes(forecast),
                          const SizedBox(height: 18),
                          Text(
                            'Weather data by Open-Meteo. Forecast times are local to ${forecast.place.displayName}.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _WeatherPageException implements Exception {
  const _WeatherPageException(this.message);

  final String message;

  @override
  String toString() => message;
}
