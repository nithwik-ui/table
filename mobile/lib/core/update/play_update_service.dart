import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:in_app_update/in_app_update.dart';
import 'app_update_policy.dart';

/// State of an in-flight in-app update.
enum InAppUpdateState {
  idle,
  checking,
  updateAvailable,
  downloading,
  downloaded, // Ready to restart
  installing,
  upToDate,
  cancelled,
  failed,
  unsupported,
}

/// Result of checking for updates with Google Play.
class PlayUpdateCheckResult {
  final bool isAvailable;
  final int priority;
  final int? availableVersionCode;
  final int? stalenessDays;
  final bool flexibleAllowed;
  final bool immediateAllowed;
  final UpdateDecision decision;
  final AppUpdateInfo? rawInfo;
  final String? errorMessage;

  const PlayUpdateCheckResult({
    required this.isAvailable,
    this.priority = 0,
    this.availableVersionCode,
    this.stalenessDays,
    this.flexibleAllowed = false,
    this.immediateAllowed = false,
    this.decision = UpdateDecision.noUpdate,
    this.rawInfo,
    this.errorMessage,
  });

  factory PlayUpdateCheckResult.none([String? error]) => PlayUpdateCheckResult(
        isAvailable: false,
        errorMessage: error,
      );
}

/// Production-grade Google Play In-App Update Service for SRU Timetable.
///
/// Follows official Google Play Core In-App Updates specifications:
/// - Supports both Flexible and Immediate update flows.
/// - Reads authoritative updatePriority (0-5) from Google Play.
/// - Resumes interrupted immediate updates on application resume.
/// - Handles flexible download completion and provides restart triggers.
/// - Completely non-blocking and failure-safe.
class PlayUpdateService {
  PlayUpdateService._();
  static final PlayUpdateService instance = PlayUpdateService._();

  bool _isChecking = false;
  bool _isUpdating = false;
  AppUpdateInfo? _cachedInfo;
  InAppUpdateState _state = InAppUpdateState.idle;

  final ValueNotifier<InAppUpdateState> stateNotifier =
      ValueNotifier<InAppUpdateState>(InAppUpdateState.idle);

  InAppUpdateState get state => _state;
  AppUpdateInfo? get cachedInfo => _cachedInfo;

  void _setState(InAppUpdateState newState) {
    _state = newState;
    stateNotifier.value = newState;
  }

  /// Whether In-App Updates are supported on this platform.
  bool get isSupported {
    if (kIsWeb) return false;
    return Platform.isAndroid;
  }

  /// Queries Google Play for available update information.
  ///
  /// Protected against concurrent checks and guaranteed never to throw.
  Future<PlayUpdateCheckResult> checkForUpdate() async {
    if (!isSupported) {
      _setState(InAppUpdateState.unsupported);
      return PlayUpdateCheckResult.none('Platform does not support Google Play In-App Updates.');
    }

    if (_isChecking) {
      debugPrint('[PlayUpdateService] Check already in progress, skipping duplicate.');
      if (_cachedInfo != null) {
        return _buildResultFromInfo(_cachedInfo!);
      }
      return PlayUpdateCheckResult.none();
    }

    _isChecking = true;
    _setState(InAppUpdateState.checking);

    try {
      final info = await InAppUpdate.checkForUpdate();
      _cachedInfo = info;

      // Check if flexible download is already completed and waiting for install
      if (info.installStatus == InstallStatus.downloaded) {
        _setState(InAppUpdateState.downloaded);
      } else if (info.updateAvailability == UpdateAvailability.developerTriggeredUpdateInProgress) {
        // Interrupted immediate update detected! Resume immediately.
        _setState(InAppUpdateState.installing);
        resumeIfImmediateInProgress();
      } else if (info.updateAvailability == UpdateAvailability.updateAvailable) {
        _setState(InAppUpdateState.updateAvailable);
      } else {
        _setState(InAppUpdateState.upToDate);
      }

      final result = _buildResultFromInfo(info);
      debugPrint(
        '[PlayUpdateService] Checked Play Store: available=${result.isAvailable}, '
        'priority=${result.priority}, decision=${result.decision}, staleness=${result.stalenessDays}',
      );
      return result;
    } on PlatformException catch (e) {
      debugPrint('[PlayUpdateService] Non-fatal Play API error: ${e.code} - ${e.message}');
      _setState(InAppUpdateState.failed);
      return PlayUpdateCheckResult.none(e.message ?? e.code);
    } catch (e) {
      debugPrint('[PlayUpdateService] Non-fatal error during update check: $e');
      _setState(InAppUpdateState.failed);
      return PlayUpdateCheckResult.none(e.toString());
    } finally {
      _isChecking = false;
    }
  }

  /// Evaluates AppUpdateInfo against AppUpdatePolicy to build the result.
  PlayUpdateCheckResult _buildResultFromInfo(AppUpdateInfo info) {
    final isAvailable = info.updateAvailability == UpdateAvailability.updateAvailable;
    final priority = info.updatePriority;
    final staleness = info.clientVersionStalenessDays;
    final flexibleAllowed = info.flexibleUpdateAllowed;
    final immediateAllowed = info.immediateUpdateAllowed;

    final decision = AppUpdatePolicy.evaluate(
      updateAvailable: isAvailable,
      priority: priority,
      stalenessDays: staleness,
      flexibleAllowed: flexibleAllowed,
      immediateAllowed: immediateAllowed,
      distributionSource: DistributionSource.googlePlay,
    );

    return PlayUpdateCheckResult(
      isAvailable: isAvailable,
      priority: priority,
      availableVersionCode: info.availableVersionCode,
      stalenessDays: staleness,
      flexibleAllowed: flexibleAllowed,
      immediateAllowed: immediateAllowed,
      decision: decision,
      rawInfo: info,
    );
  }

  /// Starts a Google Play Flexible Update flow.
  ///
  /// The user can continue using the application while Google Play
  /// downloads the update in the background.
  Future<bool> startFlexibleUpdate() async {
    if (!isSupported) return false;
    if (_isUpdating) return false;

    _isUpdating = true;
    _setState(InAppUpdateState.downloading);

    try {
      final result = await InAppUpdate.startFlexibleUpdate();
      if (result == AppUpdateResult.success) {
        // Download succeeded, ready to complete
        _setState(InAppUpdateState.downloaded);
        debugPrint('[PlayUpdateService] Flexible update downloaded successfully.');
        return true;
      } else if (result == AppUpdateResult.userDeniedUpdate) {
        _setState(InAppUpdateState.cancelled);
        debugPrint('[PlayUpdateService] User cancelled flexible update.');
        return false;
      } else {
        _setState(InAppUpdateState.failed);
        return false;
      }
    } on PlatformException catch (e) {
      debugPrint('[PlayUpdateService] Flexible update failed: ${e.code} - ${e.message}');
      _setState(InAppUpdateState.failed);
      return false;
    } catch (e) {
      debugPrint('[PlayUpdateService] Flexible update caught unexpected error: $e');
      _setState(InAppUpdateState.failed);
      return false;
    } finally {
      _isUpdating = false;
    }
  }

  /// Completes a downloaded flexible update and restarts the app.
  Future<void> completeFlexibleUpdate() async {
    if (!isSupported) return;

    try {
      _setState(InAppUpdateState.installing);
      await InAppUpdate.completeFlexibleUpdate();
    } on PlatformException catch (e) {
      debugPrint('[PlayUpdateService] Complete flexible update failed: ${e.code} - ${e.message}');
      _setState(InAppUpdateState.failed);
    } catch (e) {
      debugPrint('[PlayUpdateService] Unexpected complete update failure: $e');
      _setState(InAppUpdateState.failed);
    }
  }

  /// Starts a Google Play Immediate Update flow.
  ///
  /// Displays Google Play's full-screen native update UI.
  /// The user cannot dismiss the update screen until completion or exit.
  Future<bool> performImmediateUpdate() async {
    if (!isSupported) return false;
    if (_isUpdating) return false;

    _isUpdating = true;
    _setState(InAppUpdateState.installing);

    try {
      final result = await InAppUpdate.performImmediateUpdate();
      if (result == AppUpdateResult.success) {
        debugPrint('[PlayUpdateService] Immediate update completed.');
        return true;
      } else if (result == AppUpdateResult.userDeniedUpdate) {
        _setState(InAppUpdateState.cancelled);
        debugPrint('[PlayUpdateService] User cancelled immediate update.');
        return false;
      } else {
        _setState(InAppUpdateState.failed);
        return false;
      }
    } on PlatformException catch (e) {
      debugPrint('[PlayUpdateService] Immediate update failed: ${e.code} - ${e.message}');
      _setState(InAppUpdateState.failed);
      return false;
    } catch (e) {
      debugPrint('[PlayUpdateService] Immediate update caught unexpected error: $e');
      _setState(InAppUpdateState.failed);
      return false;
    } finally {
      _isUpdating = false;
    }
  }

  /// Resumes an interrupted immediate update if the user exited or put
  /// the app in the background while the immediate update was in progress.
  Future<void> resumeIfImmediateInProgress() async {
    if (!isSupported) return;

    try {
      final info = await InAppUpdate.checkForUpdate();
      if (info.updateAvailability == UpdateAvailability.developerTriggeredUpdateInProgress) {
        debugPrint('[PlayUpdateService] Resuming in-progress immediate update.');
        await InAppUpdate.performImmediateUpdate();
      }
    } catch (e) {
      debugPrint('[PlayUpdateService] Non-fatal check during resume: $e');
    }
  }
}
