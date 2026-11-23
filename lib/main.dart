import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video_player_media_kit/video_player_media_kit.dart';

import 'app_profile.dart';
import 'home_page.dart';
import 'login_page.dart';
import 'supabase_config.dart';
import 'supabase_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!SupabaseConfig.isConfigured) {
    runApp(const MyApp(configurationError: 'missing'));
    return;
  }

  try {
    await Supabase.initialize(
      url: SupabaseConfig.projectUrl,
      publishableKey: SupabaseConfig.publishableKey,
    );
    VideoPlayerMediaKit.ensureInitialized(
      android: true,
      windows: true,
      linux: true,
    );
  } on Exception catch (error) {
    runApp(MyApp(configurationError: error.toString()));
    return;
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({this.configurationError, super.key});

  final String? configurationError;

  @override
  Widget build(BuildContext context) {
    const seedColor = Color(0xFF6750A4);
    return MaterialApp(
      title: "Reyaansh's Things",
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: seedColor),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: seedColor,
          brightness: Brightness.dark,
        ),
      ),
      home: configurationError == null
          ? const _AuthGate()
          : _SupabaseSetupPage(error: configurationError!),
    );
  }
}

class _AuthGate extends StatefulWidget {
  const _AuthGate();

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  final _service = SupabaseService();
  StreamSubscription<AuthState>? _authSubscription;
  User? _user;
  AppProfile? _profile;
  Future<AppProfile>? _profileFuture;
  String? _connectionError;
  bool _isCheckingSupabase = true;

  @override
  void initState() {
    super.initState();
    unawaited(_checkSupabase());
    _user = _service.client.auth.currentUser;
    if (_user != null) _profileFuture = _service.loadProfile(_user!.id);
    _authSubscription = _service.client.auth.onAuthStateChange.listen((state) {
      final nextUser = _service.client.auth.currentUser;
      if (nextUser == null) {
        if (_user == null) return;
        setState(() {
          _user = null;
          _profile = null;
          _profileFuture = null;
        });
        return;
      }
      if (_user == null && state.event != AuthChangeEvent.initialSession) {
        return;
      }
      if (nextUser.id == _user?.id) return;
      setState(() {
        _user = nextUser;
        _profile = null;
        _profileFuture = _service.loadProfile(nextUser.id);
      });
    });
  }

  Future<void> _checkSupabase() async {
    if (mounted) {
      setState(() {
        _isCheckingSupabase = true;
        _connectionError = null;
      });
    }
    try {
      await _service.checkConnection(
        projectUrl: SupabaseConfig.projectUrl,
        publishableKey: SupabaseConfig.publishableKey,
      );
      if (!mounted) return;
      setState(() {
        _isCheckingSupabase = false;
        _connectionError = null;
      });
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() {
        _isCheckingSupabase = false;
        _connectionError = error.toString();
      });
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  void _updateProfile(AppProfile profile) {
    setState(() {
      _profile = profile;
      _profileFuture = Future.value(profile);
    });
  }

  void _onAuthenticated(AppProfile profile) {
    setState(() {
      _user = _service.client.auth.currentUser;
      _profile = profile;
      _profileFuture = Future.value(profile);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingSupabase) return const _SupabaseCheckingPage();
    if (_connectionError != null) {
      return _SupabaseConnectionError(
        error: _connectionError!,
        onRetry: _checkSupabase,
      );
    }
    if (_user == null) {
      return LoginPage(service: _service, onAuthenticated: _onAuthenticated);
    }
    if (_profile != null) {
      return HomePage(
        profile: _profile!,
        onProfileUpdated: _updateProfile,
        onSignOut: _service.signOut,
      );
    }

    return FutureBuilder<AppProfile>(
      future: _profileFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return _LoadProfileError(
            error: snapshot.error.toString(),
            onRetry: () {
              setState(() {
                _profileFuture = _service.loadProfile(_user!.id);
              });
            },
            onSignOut: _service.signOut,
          );
        }

        final profile = snapshot.data;
        if (profile == null) {
          return _LoadProfileError(
            error: 'Supabase did not return a profile.',
            onRetry: () {
              setState(() {
                _profileFuture = _service.loadProfile(_user!.id);
              });
            },
            onSignOut: _service.signOut,
          );
        }
        return HomePage(
          profile: profile,
          onProfileUpdated: _updateProfile,
          onSignOut: _service.signOut,
        );
      },
    );
  }
}

class _SupabaseCheckingPage extends StatelessWidget {
  const _SupabaseCheckingPage();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Checking Supabase connection…'),
          ],
        ),
      ),
    );
  }
}

class _SupabaseConnectionError extends StatelessWidget {
  const _SupabaseConnectionError({
    required this.error,
    required this.onRetry,
  });

  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.cloud_off_rounded,
                  size: 48,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(height: 16),
                Text(
                  'Could not connect to Supabase',
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                SelectableText(error, textAlign: TextAlign.center),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 12,
                  children: [
                    FilledButton.icon(
                      onPressed: onRetry,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Try again'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _copyErrorToClipboard(context, error),
                      icon: const Icon(Icons.copy_rounded),
                      label: const Text('Copy error'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> _copyErrorToClipboard(
  BuildContext context,
  String error,
) async {
  try {
    await Clipboard.setData(ClipboardData(text: error));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error copied to clipboard.')),
      );
    }
  } on Exception catch (copyError) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not copy error: $copyError')),
      );
    }
  }
}

class _LoadProfileError extends StatelessWidget {
  const _LoadProfileError({
    required this.error,
    required this.onRetry,
    required this.onSignOut,
  });

  final String error;
  final VoidCallback onRetry;
  final Future<void> Function() onSignOut;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off_rounded, size: 44),
                const SizedBox(height: 16),
                Text(
                  'Could not load your Supabase profile.',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                SelectableText(error, textAlign: TextAlign.center),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 12,
                  children: [
                    FilledButton(
                      onPressed: onRetry,
                      child: const Text('Try again'),
                    ),
                    OutlinedButton(
                      onPressed: onSignOut,
                      child: const Text('Sign out'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SupabaseSetupPage extends StatelessWidget {
  const _SupabaseSetupPage({required this.error});

  final String error;

  @override
  Widget build(BuildContext context) {
    final missing = error == 'missing';
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Connect Supabase',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      missing
                          ? 'Add your project URL and public key to '
                                'lib/supabase_config.dart, then restart the app.'
                          : 'Supabase could not be initialized.',
                    ),
                    if (!missing) ...[
                      const SizedBox(height: 8),
                      SelectableText(error),
                    ],
                    const SizedBox(height: 18),
                    const SelectableText(
                      'SupabaseConfig.projectUrl = '
                      '\'https://YOUR_PROJECT_ID.supabase.co\'\n'
                      'SupabaseConfig.publishableKey = \'YOUR_PUBLIC_KEY\'',
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Never put a service-role or secret key in this app. '
                      'Run supabase/schema.sql in the Supabase SQL Editor first.',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
