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

  /// Normalizes and compares versions strictly.
  /// Example: isNewerVersion('1.0.3', 'v1.0.4') -> true
  static bool isNewerVersion(String current, String latest) {
    try {
      final cleanCurrent = current.replaceAll('v', '').replaceAll('+', '.');
      final cleanLatest = latest.replaceAll('v', '').replaceAll('+', '.');

      final currentParts = cleanCurrent.split('.').map(int.parse).toList();
      final latestParts = cleanLatest.split('.').map(int.parse).toList();

      for (int i = 0; i < latestParts.length; i++) {
        if (i >= currentParts.length) {
          return true; // Latest has more parts (e.g. 1.0 vs 1.0.1)
        }
        if (latestParts[i] > currentParts[i]) {
          return true;
        } else if (latestParts[i] < currentParts[i]) {
          return false;
        }
      }
    } catch (_) {}
    return false;
  }
}
