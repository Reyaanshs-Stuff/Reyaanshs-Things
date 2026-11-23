import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

Future<void> downloadAndInstallApk(
  Uri downloadUrl,
  String assetName, {
  required void Function(double? progress) onProgress,
}) async {
  final safeFileName = assetName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
  if (!safeFileName.toLowerCase().endsWith('.apk')) {
    throw Exception('The release asset is not an APK.');
  }

  final directory = await getTemporaryDirectory();
  final file = File('${directory.path}${Platform.pathSeparator}$safeFileName');
  final client = http.Client();

  try {
    final response = await client
        .send(http.Request('GET', downloadUrl))
        .timeout(const Duration(seconds: 30));
    if (response.statusCode != 200) {
      throw Exception('APK download failed (HTTP ${response.statusCode}).');
    }

    final totalBytes = response.contentLength;
    var receivedBytes = 0;
    final output = file.openWrite();
    try {
      await for (final chunk in response.stream.timeout(
        const Duration(seconds: 30),
      )) {
        output.add(chunk);
        receivedBytes += chunk.length;
        onProgress(
          totalBytes != null && totalBytes > 0
              ? (receivedBytes / totalBytes).clamp(0, 1).toDouble()
              : null,
        );
      }
      await output.flush();
    } on Exception {
      await output.close();
      if (await file.exists()) {
        await file.delete();
      }
      rethrow;
    }
    await output.close();

    if (!await file.exists() || await file.length() == 0) {
      throw Exception('The downloaded APK is empty.');
    }

    onProgress(1);
    final openResult = await OpenFilex.open(
      file.path,
      type: 'application/vnd.android.package-archive',
    );
    if (openResult.type != ResultType.done) {
      final installWasBlocked =
          openResult.type == ResultType.permissionDenied ||
          openResult.type == ResultType.error;
      final message = installWasBlocked
          ? 'Allow this app to install unknown apps in Android settings, '
                'then try again. ${openResult.message}'
          : openResult.message;
      throw Exception('Could not open the Android package installer: $message');
    }
  } finally {
    client.close();
  }
}
