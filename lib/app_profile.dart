class AppProfile {
  const AppProfile({
    required this.displayName,
    required this.profilePictureUrl,
  });

  final String displayName;
  final String profilePictureUrl;

  static bool isValidPictureUrl(String value) {
    final uri = Uri.tryParse(value.trim());
    return uri != null &&
        uri.host.isNotEmpty &&
        (uri.scheme.toLowerCase() == 'http' ||
            uri.scheme.toLowerCase() == 'https');
  }
}
