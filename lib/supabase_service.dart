import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_profile.dart';

class SupabaseService {
  SupabaseService([SupabaseClient? client])
    : client = client ?? Supabase.instance.client;

  final SupabaseClient client;

  Future<void> checkConnection({
    required String projectUrl,
    required String publishableKey,
  }) async {
    final baseUrl = projectUrl.replaceFirst(RegExp(r'/+$'), '');
    final response = await http
        .get(
          Uri.parse('$baseUrl/auth/v1/settings'),
          headers: {
            'apikey': publishableKey,
            'Authorization': 'Bearer $publishableKey',
          },
        )
        .timeout(const Duration(seconds: 12));
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw SupabaseServiceException(
        'Supabase rejected the API key (HTTP ${response.statusCode}).',
      );
    }
    throw SupabaseServiceException(
      'Supabase startup check failed (HTTP ${response.statusCode}).',
    );
  }

  Future<SignInResult> signInOrCreateAccount({
    required String email,
    required String password,
    required String username,
    Uint8List? avatarBytes,
    String? avatarFileName,
    String? avatarMimeType,
  }) async {
    User? user;

    try {
      final response = await client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      user = response.user;
    } on AuthException catch (error) {
      if (error.statusCode != '400') rethrow;
      if (error.code == 'email_not_confirmed') {
        throw const SupabaseServiceException(
          'Your account was created, but its email is not confirmed yet. '
          'Confirm the email from your inbox, then try signing in again.',
        );
      }
      if (username.trim().isEmpty) {
        throw SupabaseServiceException(
          'Sign-in failed: ${error.message}. If you already created this '
          'account, check your password. To create a new account in the app, '
          'enter a username and tap Continue.',
        );
      }

      final response = await client.auth.signUp(
        email: email,
        password: password,
        data: {'username': username.trim()},
      );
      user = response.user;

      if (user == null) {
        throw SupabaseServiceException(
          'Supabase did not return a user after sign-up.',
        );
      }
      if (user.identities?.isEmpty ?? false) {
        throw SupabaseServiceException(
          'Unable to sign in or create an account with those details. '
          'Check your password and try again.',
        );
      }
      if (response.session == null) {
        return const SignInResult(emailConfirmationRequired: true);
      }
    }

    if (user == null) {
      throw SupabaseServiceException(
        'Supabase did not return a signed-in user.',
      );
    }

    if (avatarBytes != null && avatarFileName != null) {
      await uploadAvatar(
        avatarBytes,
        fileName: avatarFileName,
        mimeType: avatarMimeType,
      );
    }

    return SignInResult(profile: await loadProfile(user.id));
  }

  Future<AppProfile> loadProfile(String userId) async {
    final row = await client
        .from('profiles')
        .select('id, username, avatar_path')
        .eq('id', userId)
        .maybeSingle();

    if (row == null) {
      throw SupabaseServiceException(
        'Your Supabase profile is missing. Apply the setup SQL and try again.',
      );
    }

    final avatarPath = row['avatar_path'] as String?;
    return AppProfile(
      userId: row['id'] as String,
      displayName: row['username'] as String,
      profilePictureUrl: avatarPath == null
          ? null
          : client.storage.from('profile-avatars').getPublicUrl(avatarPath),
    );
  }

  Future<AppProfile> updateProfile({
    required String username,
    Uint8List? avatarBytes,
    String? avatarFileName,
    String? avatarMimeType,
  }) async {
    final user = client.auth.currentUser;
    if (user == null) {
      throw SupabaseServiceException('You must be signed in.');
    }

    final updatedName = username.trim();
    if (updatedName.isEmpty) {
      throw SupabaseServiceException('Username cannot be empty.');
    }

    String? avatarPath;
    if (avatarBytes != null && avatarFileName != null) {
      avatarPath = await uploadAvatar(
        avatarBytes,
        fileName: avatarFileName,
        mimeType: avatarMimeType,
      );
    }

    final updates = <String, dynamic>{'username': updatedName};
    if (avatarPath != null) updates['avatar_path'] = avatarPath;
    await client.from('profiles').update(updates).eq('id', user.id);
    return loadProfile(user.id);
  }

  Future<String> uploadAvatar(
    Uint8List bytes, {
    required String fileName,
    String? mimeType,
  }) async {
    final user = client.auth.currentUser;
    if (user == null) {
      throw SupabaseServiceException('You must be signed in.');
    }
    if (bytes.isEmpty || bytes.length > 5 * 1024 * 1024) {
      throw const SupabaseServiceException(
        'Profile photos must be smaller than 5 MB.',
      );
    }
    if (!const {'image/jpeg', 'image/png', 'image/webp'}.contains(mimeType)) {
      throw const SupabaseServiceException(
        'Profile photos must be JPG, PNG, or WebP images.',
      );
    }

    final extension = _safeExtension(fileName);
    final path =
        '${user.id}/${DateTime.now().microsecondsSinceEpoch}.$extension';
    await client.storage
        .from('profile-avatars')
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            contentType: mimeType ?? 'image/$extension',
            upsert: false,
          ),
        );
    try {
      await client
          .from('profiles')
          .update({'avatar_path': path})
          .eq('id', user.id);
    } on Exception catch (error, stackTrace) {
      try {
        await client.storage.from('profile-avatars').remove([path]);
      } on Exception catch (cleanupError) {
        throw SupabaseServiceException(
          'Profile photo update failed: $error. The uploaded photo could not '
          'be removed: $cleanupError',
        );
      }
      Error.throwWithStackTrace(error, stackTrace);
    }
    return path;
  }

  Future<void> signOut() => client.auth.signOut();
}

class SignInResult {
  const SignInResult({this.profile, this.emailConfirmationRequired = false});

  final AppProfile? profile;
  final bool emailConfirmationRequired;
}

String _safeExtension(String fileName) {
  final extension = fileName.split('.').last.toLowerCase();
  if (extension.isEmpty ||
      extension.length > 8 ||
      !RegExp(r'^[a-z0-9]+$').hasMatch(extension)) {
    return 'jpg';
  }
  return extension;
}

class SupabaseServiceException implements Exception {
  const SupabaseServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}
