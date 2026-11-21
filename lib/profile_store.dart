import 'package:shared_preferences/shared_preferences.dart';

import 'app_profile.dart';

class ProfileStore {
  static const _displayNameKey = 'profile.displayName';
  static const _profilePictureUrlKey = 'profile.pictureUrl';

  Future<AppProfile?> load() async {
    final preferences = await SharedPreferences.getInstance();
    final displayName = preferences.getString(_displayNameKey)?.trim();
    final profilePictureUrl = preferences.getString(_profilePictureUrlKey);

    if (displayName == null ||
        displayName.isEmpty ||
        profilePictureUrl == null ||
        !AppProfile.isValidPictureUrl(profilePictureUrl)) {
      return null;
    }

    return AppProfile(
      displayName: displayName,
      profilePictureUrl: profilePictureUrl,
    );
  }

  Future<void> save(AppProfile profile) async {
    final preferences = await SharedPreferences.getInstance();
    final savedName = await preferences.setString(
      _displayNameKey,
      profile.displayName,
    );
    if (!savedName) {
      throw StateError('Could not save the display name.');
    }

    final savedPicture = await preferences.setString(
      _profilePictureUrlKey,
      profile.profilePictureUrl,
    );
    if (!savedPicture) {
      throw StateError('Could not save the profile picture URL.');
    }
  }
}
