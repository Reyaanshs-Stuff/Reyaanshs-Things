import 'dart:convert';

import 'package:http/http.dart' as http;

import 'app_update_downloader_stub.dart'
    if (dart.library.io) 'app_update_downloader_io.dart'
    as downloader;

class AppUpdateRelease {
  const AppUpdateRelease({
    required this.version,
    required this.assetName,
    required this.downloadUrl,
  });

  final String version;
  final String assetName;
  final Uri downloadUrl;
}

class AppUpdater {
  static final Uri _latestReleaseUri = Uri.https(
    'api.github.com',
    '/repos/Reyaanshs-Stuff/Reyaanshs-Things/releases/latest',
  );

  Future<AppUpdateRelease> fetchLatestRelease() async {
    final response = await http
        .get(
          _latestReleaseUri,
          headers: const {
            'Accept': 'application/vnd.github+json',
            'User-Agent': 'Reyaanshs-Things-Updater',
            'X-GitHub-Api-Version': '2022-11-28',
          },
        )
        .timeout(const Duration(seconds: 20));

    if (response.statusCode == 404) {
      throw const AppUpdateException(
        'No published GitHub release was found yet.',
      );
    }
    if (response.statusCode != 200) {
      throw AppUpdateException('GitHub returned HTTP ${response.statusCode}.');
    }

    final payload = jsonDecode(response.body);
    if (payload is! Map<String, dynamic>) {
      throw const AppUpdateException('GitHub returned an invalid release.');
    }

    final version = payload['tag_name'];
    final assets = payload['assets'];
    if (version is! String || assets is! List) {
      throw const AppUpdateException('The latest release is missing details.');
    }

    Map<String, dynamic>? apkAsset;
    for (final asset in assets) {
      if (asset is Map<String, dynamic> &&
          asset['name'] is String &&
          (asset['name'] as String).toLowerCase().endsWith('.apk')) {
        apkAsset = asset;
        break;
      }
    }

    if (apkAsset == null || apkAsset['browser_download_url'] is! String) {
      throw const AppUpdateException(
        'The latest GitHub release does not include an APK.',
      );
    }

    final downloadUrl = Uri.tryParse(
      apkAsset['browser_download_url'] as String,
    );
    if (downloadUrl == null ||
        downloadUrl.scheme != 'https' ||
        downloadUrl.host != 'github.com') {
      throw const AppUpdateException(
        'The latest release has an invalid APK download link.',
      );
    }

    return AppUpdateRelease(
      version: version,
      assetName: apkAsset['name'] as String,
      downloadUrl: downloadUrl,
    );
  }

  static int compareVersions(String left, String right) {
    final leftParts = _parseVersion(left);
    final rightParts = _parseVersion(right);
    for (var index = 0; index < leftParts.length; index++) {
      final comparison = leftParts[index].compareTo(rightParts[index]);
      if (comparison != 0) return comparison;
    }
    return 0;
  }

  Future<void> downloadAndInstall(
    AppUpdateRelease release, {
    required void Function(double? progress) onProgress,
  }) {
    return downloader.downloadAndInstallApk(
      release.downloadUrl,
      release.assetName,
      onProgress: onProgress,
    );
  }

  static List<int> _parseVersion(String version) {
    final normalized = version.trim().replaceFirst(RegExp(r'^[vV]'), '');
    final match = RegExp(r'^(\d+)\.(\d+)\.(\d+)(?:\+(\d+))?$')
        .firstMatch(normalized);
    if (match == null) {
      throw FormatException('Unsupported app version: $version');
    }

    return [
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
      int.parse(match.group(4) ?? '0'),
    ];
  }
}

class AppUpdateException implements Exception {
  const AppUpdateException(this.message);

  final String message;

  @override
  String toString() => message;
}
