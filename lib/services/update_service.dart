import 'dart:io';

import 'package:dio/dio.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:xml/xml.dart';

class UpdateService {
  static const String _appcastUrl =
      'https://hajorda.github.io/popodoro/appcast.xml';
  static final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ));

  // pub_semver's Version.parse requires MAJOR.MINOR.PATCH and throws on anything
  // else. Pad short versions and strip stray whitespace + `+build` suffixes so a
  // malformed appcast or pubspec version doesn't silently kill the update check.
  static Version? _tryParseVersion(String? raw) {
    if (raw == null) return null;
    var v = raw.trim();
    if (v.isEmpty) return null;
    final plus = v.indexOf('+');
    if (plus != -1) v = v.substring(0, plus);
    final parts = v.split('.');
    if (parts.length == 1) v = '$v.0.0';
    if (parts.length == 2) v = '$v.0';
    try {
      return Version.parse(v);
    } catch (_) {
      return null;
    }
  }

  /// Returns true if a newer version is available.
  static Future<UpdateInfo?> checkForUpdate() async {
    try {
      final response = await _dio.get(_appcastUrl);
      if (response.statusCode == 200) {
        final xml = XmlDocument.parse(response.data.toString());
        final item = xml.findAllElements('item').firstOrNull;
        if (item != null) {
          final versionStr = item
              .findElements('version')
              .firstOrNull
              ?.innerText;
          final macosUrl = item
              .findElements('url_macos')
              .firstOrNull
              ?.innerText;
          final windowsUrl = item
              .findElements('url_windows')
              .firstOrNull
              ?.innerText;
          final releaseNotes = item
              .findElements('release_notes')
              .firstOrNull
              ?.innerText;

          if (versionStr == null) return null;

          final remoteVersion = _tryParseVersion(versionStr);
          if (remoteVersion == null) return null;

          final packageInfo = await PackageInfo.fromPlatform();
          final currentVersion = _tryParseVersion(packageInfo.version);
          if (currentVersion == null) return null;

          if (remoteVersion > currentVersion) {
            String? downloadUrl;
            if (Platform.isMacOS) {
              downloadUrl = macosUrl;
            } else if (Platform.isWindows) {
              downloadUrl = windowsUrl;
            }

            if (downloadUrl != null && downloadUrl.isNotEmpty) {
              return UpdateInfo(
                version: versionStr,
                downloadUrl: downloadUrl,
                releaseNotes: releaseNotes,
              );
            }
          }
        }
      }
    } catch (e) {
      // Fail silently for background checks to not annoy the user
      // if they are offline.
      print('Update check failed: $e');
    }
    return null;
  }
}

class UpdateInfo {
  final String version;
  final String downloadUrl;
  final String? releaseNotes;

  const UpdateInfo({
    required this.version,
    required this.downloadUrl,
    this.releaseNotes,
  });
}
