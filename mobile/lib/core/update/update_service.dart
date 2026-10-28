import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'app_update_policy.dart';
import 'play_update_service.dart';
import 'direct_apk_update_service.dart';
import 'web_update_service.dart';

/// Unified update result returned by the central [UpdateService].
class UnifiedUpdateResult {
  final DistributionSource source;
  final bool updateAvailable;
  final AppUpdateClassification classification;
  final UpdateDecision decision;
  final String? versionTag;
  final String? downloadUrl;
  final String? message;
  final PlayUpdateCheckResult? playResult;

  const UnifiedUpdateResult({
    required this.source,
    required this.updateAvailable,
    this.classification = AppUpdateClassification.none,
    this.decision = UpdateDecision.noUpdate,
    this.versionTag,
    this.downloadUrl,
    this.message,
    this.playResult,
  });

  /// True if the user should be prompted or presented with an immediate update.
  bool get isCriticalImmediate => decision == UpdateDecision.requiredImmediate;

  /// True if flexible update is available to start.
  bool get isFlexibleAvailable =>
      decision == UpdateDecision.optionalFlexible ||
      decision == UpdateDecision.recommendedFlexible;
}

/// Central unified Update Service orchestrating Google Play In-App Updates,
/// direct APK (GitHub) updates, and Web/PWA updates.
class UpdateService {
  UpdateService._();
  static final UpdateService instance = UpdateService._();

  DistributionSource? _detectedSource;
  bool _isChecking = false;

  /// Exposes the reactive download/install state for flexible updates.
  ValueNotifier<InAppUpdateState> get playStateNotifier =>
      PlayUpdateService.instance.stateNotifier;

  /// Detects the distribution source of the running application.
  Future<DistributionSource> detectDistributionSource() async {
    if (_detectedSource != null) return _detectedSource!;

    if (kIsWeb) {
      _detectedSource = DistributionSource.web;
      return _detectedSource!;
    }

    if (Platform.isAndroid) {
      try {
        final packageInfo = await PackageInfo.fromPlatform();
        final installer = packageInfo.installerStore?.toLowerCase() ?? '';

        // Standard Google Play Store installer package names
        if (installer == 'com.android.vending' ||
            installer == 'com.google.android.feedback') {
          _detectedSource = DistributionSource.googlePlay;
          return _detectedSource!;
        }

        // If installer is empty/sideloaded, check if Google Play In-App Updates API is operational
        if (PlayUpdateService.instance.isSupported) {
          final playCheck = await PlayUpdateService.instance.checkForUpdate();
          if (playCheck.rawInfo != null) {
            _detectedSource = DistributionSource.googlePlay;
            return _detectedSource!;
          }
        }

        // Fallback to direct APK (GitHub release) for sideloaded installations
        _detectedSource = DistributionSource.directApk;
        return _detectedSource!;
      } catch (_) {
        _detectedSource = DistributionSource.directApk;
        return _detectedSource!;
      }
    }

    _detectedSource = DistributionSource.unknown;
    return _detectedSource!;
  }

  /// Unified check for updates across distribution channels.
  ///
  /// Concurrency-protected and guaranteed non-blocking.
  Future<UnifiedUpdateResult> checkUnifiedUpdate({bool isManual = false}) async {
    if (_isChecking) {
      debugPrint('[UpdateService] Update check already in-flight.');
      return const UnifiedUpdateResult(
        source: DistributionSource.unknown,
        updateAvailable: false,
        message: 'Check already in progress',
      );
    }

    _isChecking = true;

    try {
      final source = await detectDistributionSource();

      if (source == DistributionSource.googlePlay) {
        final playResult = await PlayUpdateService.instance.checkForUpdate();
        return UnifiedUpdateResult(
          source: DistributionSource.googlePlay,
          updateAvailable: playResult.isAvailable,
          classification: AppUpdatePolicy.classifyPriority(playResult.priority),
          decision: playResult.decision,
          versionTag: playResult.availableVersionCode?.toString(),
          playResult: playResult,
          message: playResult.errorMessage,
        );
      }

      if (source == DistributionSource.directApk) {
        final directResult = await DirectApkUpdateService.instance.checkForUpdates();
        final bool available = directResult['status'] == 'update_available';
        return UnifiedUpdateResult(
          source: DistributionSource.directApk,
          updateAvailable: available,
          classification: available ? AppUpdateClassification.normal : AppUpdateClassification.none,
          decision: available ? UpdateDecision.optionalFlexible : UpdateDecision.noUpdate,
          versionTag: directResult['latestTag'] as String?,
          downloadUrl: directResult['downloadUrl'] as String?,
          message: directResult['message'] as String?,
        );
      }

      if (source == DistributionSource.web) {
        final webAvailable = await WebUpdateService.instance.checkForWebUpdate();
        return UnifiedUpdateResult(
          source: DistributionSource.web,
          updateAvailable: webAvailable,
          classification: webAvailable ? AppUpdateClassification.normal : AppUpdateClassification.none,
          decision: webAvailable ? UpdateDecision.optionalFlexible : UpdateDecision.noUpdate,
        );
      }

      return const UnifiedUpdateResult(
        source: DistributionSource.unknown,
        updateAvailable: false,
      );
    } finally {
      _isChecking = false;
    }
  }

  /// Starts flexible update if available.
  Future<bool> startFlexibleUpdate() async {
    return await PlayUpdateService.instance.startFlexibleUpdate();
  }

  /// Completes flexible update and restarts the app.
  Future<void> completeFlexibleUpdate() async {
    await PlayUpdateService.instance.completeFlexibleUpdate();
  }

  /// Starts immediate native update UI for Google Play.
  Future<bool> performImmediateUpdate() async {
    return await PlayUpdateService.instance.performImmediateUpdate();
  }

  /// Resumes an in-progress immediate update if the app was suspended.
  Future<void> resumeIfImmediateInProgress() async {
    await PlayUpdateService.instance.resumeIfImmediateInProgress();
  }

  // -------------------------------------------------------------
  // Backward Compatibility API for existing callers
  // -------------------------------------------------------------
  /// Legacy wrapper preserving [UpdateService.checkForUpdates()] contract.
  static Future<Map<String, dynamic>> checkForUpdates() async {
    final result = await instance.checkUnifiedUpdate();

    if (result.source == DistributionSource.googlePlay) {
      if (result.updateAvailable) {
        return {
          'status': 'update_available',
          'source': 'google_play',
          'decision': result.decision.name,
          'latestTag': result.versionTag ?? '',
          'downloadUrl': '',
        };
      } else {
        return {
          'status': 'up_to_date',
          'source': 'google_play',
        };
      }
    }

    if (result.source == DistributionSource.directApk) {
      if (result.updateAvailable) {
        return {
          'status': 'update_available',
          'source': 'direct_apk',
          'latestTag': result.versionTag ?? '',
          'downloadUrl': result.downloadUrl ?? '',
        };
      } else {
        return {
          'status': 'up_to_date',
          'source': 'direct_apk',
        };
      }
    }

    return {
      'status': 'up_to_date',
      'source': result.source.name,
    };
  }
}
