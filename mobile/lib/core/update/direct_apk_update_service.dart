import 'package:package_info_plus/package_info_plus.dart';
import '../api.dart';
import '../constants.dart';

/// Service responsible for GitHub direct APK releases (for sideloaded installations).
class DirectApkUpdateService {
  DirectApkUpdateService._();
  static final DirectApkUpdateService instance = DirectApkUpdateService._();

  /// Checks GitHub releases for updates.
  /// Returns a Map with 'status' and optionally 'latestTag', 'downloadUrl', 'installedVersion'.
  /// 'status' can be: 'error', 'timeout', 'no_internet', 'up_to_date', 'update_available'.
  Future<Map<String, dynamic>> checkForUpdates() async {
    try {
      final release = await ApiService.fetchLatestGithubRelease();

      if (release['status'] == 'timeout' ||
          release['status'] == 'no_internet' ||
          release['status'] == 'error' ||
          release['status'] == 'no_release') {
        return release;
      }

      final String latestTag = release['tag_name'] as String? ?? '';
      if (latestTag.isEmpty) {
        return {'status': 'error', 'message': 'Invalid release data'};
      }

      final String htmlUrl =
          release['html_url'] as String? ?? 'https://github.com/${AppConstants.githubRepo}';

      String? downloadUrl;
      final assets = release['assets'] as List<dynamic>?;
      if (assets != null && assets.isNotEmpty) {
        for (final asset in assets) {
          final name = asset['name'] as String? ?? '';
          if (name.endsWith('.apk')) {
            downloadUrl = asset['browser_download_url'] as String?;
            break;
          }
        }
      }

      final targetUrl = downloadUrl ?? htmlUrl;

      final packageInfo = await PackageInfo.fromPlatform();
      final String installedVersion = packageInfo.version;

      if (isNewerVersion(installedVersion, latestTag)) {
        return {
          'status': 'update_available',
          'latestTag': latestTag,
          'downloadUrl': targetUrl,
          'installedVersion': installedVersion,
        };
      } else {
        return {
          'status': 'up_to_date',
          'installedVersion': installedVersion,
          'latestTag': latestTag,
        };
      }
    } catch (e) {
      return {'status': 'error', 'message': e.toString()};
    }
  }

  /// Compares two semantic version strings (e.g. '3.1.1', 'v3.1.2', '3.1.1+32', '3.1.2+33').
  /// Returns:
  ///   < 0 if [v1] < [v2]
  ///   0   if [v1] == [v2]
  ///   > 0 if [v1] > [v2]
  static int compareSemanticVersions(String v1, String v2) {
    try {
      final List<int> v1Parts = _extractVersionParts(v1);
      final List<int> v2Parts = _extractVersionParts(v2);

      final int maxLen = v1Parts.length > v2Parts.length ? v1Parts.length : v2Parts.length;
      for (int i = 0; i < maxLen; i++) {
        final int part1 = i < v1Parts.length ? v1Parts[i] : 0;
        final int part2 = i < v2Parts.length ? v2Parts[i] : 0;
        if (part1 < part2) return -1;
        if (part1 > part2) return 1;
      }
      return 0;
    } catch (_) {
      return 0;
    }
  }

  static List<int> _extractVersionParts(String version) {
    final clean = version.trim().replaceAll(RegExp(r'^[vV]'), '');
    final tokens = clean.split(RegExp(r'[+\-\.]'));
    final List<int> parts = [];
    for (final token in tokens) {
      final digits = RegExp(r'^\d+').stringMatch(token);
      if (digits != null && digits.isNotEmpty) {
        parts.add(int.parse(digits));
      }
    }
    return parts;
  }

  /// Normalizes and compares versions strictly.
  /// Example: isNewerVersion('3.1.1', 'v3.1.2') -> true
  static bool isNewerVersion(String current, String latest) {
    return compareSemanticVersions(current, latest) < 0;
  }
}
