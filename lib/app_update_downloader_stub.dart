Future<void> downloadAndInstallApk(
  Uri downloadUrl,
  String assetName, {
  required void Function(double? progress) onProgress,
}) {
  throw UnsupportedError('APK installation is only available on Android.');
}
