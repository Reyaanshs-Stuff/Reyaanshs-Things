import 'package:flutter/material.dart';

import 'app_profile.dart';
import 'home_page.dart';
import 'login_page.dart';
import 'profile_store.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _profileStore = ProfileStore();
  late Future<AppProfile?> _savedProfileFuture;
  AppProfile? _profile;

  @override
  void initState() {
    super.initState();
    _savedProfileFuture = _profileStore.load();
  }

  Future<void> _saveProfile(String displayName, String profilePictureUrl) async {
    final profile = AppProfile(
      displayName: displayName,
      profilePictureUrl: profilePictureUrl,
    );
    await _profileStore.save(profile);
    if (!mounted) return;
    setState(() {
      _profile = profile;
    });
  }

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
      home: _profile != null
          ? HomePage(profile: _profile!)
          : FutureBuilder<AppProfile?>(
              future: _savedProfileFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                }

                if (snapshot.hasError) {
                  return _ProfileLoadError(
                    onRetry: () {
                      setState(() {
                        _savedProfileFuture = _profileStore.load();
                      });
                    },
                  );
                }

                final savedProfile = snapshot.data;
                if (savedProfile != null) {
                  return HomePage(profile: savedProfile);
                }

                return LoginPage(onStartUsing: _saveProfile);
              },
            ),
    );
  }
}

class _ProfileLoadError extends StatelessWidget {
  const _ProfileLoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Could not load your saved profile.'),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: onRetry,
                child: const Text('Try again'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
