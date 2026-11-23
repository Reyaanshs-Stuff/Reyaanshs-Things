class AppProfile {
  const AppProfile({
    required this.userId,
    required this.displayName,
    required this.profilePictureUrl,
  });

  final String userId;
  final String displayName;
  final String? profilePictureUrl;
}
