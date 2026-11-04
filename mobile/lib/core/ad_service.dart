import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

enum AdSdkStatus {
  uninitialized,
  initializing,
  ready,
  unavailable,
  disabled,
}

class InMobiBannerResult {
  final bool loaded;
  final String instanceId;
  final String placementId;
  final int width;
  final int height;
  final int loadLatencyMs;
  final double ecpm;
  final String? errorMessage;

  bool get isSuccess => loaded;

  const InMobiBannerResult({
    required this.loaded,
    required this.instanceId,
    required this.placementId,
    this.width = 320,
    this.height = 50,
    this.loadLatencyMs = 0,
    this.ecpm = 0.0,
    this.errorMessage,
  });
}

/// Centralized advertising service for SRU Timetable 3.1.4.
///
/// Current strategy:
/// - Ad Network: InMobi
/// - Format: Banner ONLY
/// - Completely isolated from critical app startup & timetable rendering.
/// - Never crashes, blocks navigation, or leaves blank spaces when unavailable.
class AdService {
  static final AdService instance = AdService._internal();
  AdService._internal();

  static const String adNetwork = 'InMobi';
  static const String adFormat = 'Banner';
  static const MethodChannel _channel =
      MethodChannel('com.srutimetable.mobile/inmobi');

  // Optional compile-time configuration via --dart-define
  static const String defaultAccountId = String.fromEnvironment(
    'INMOBI_ACCOUNT_ID',
    defaultValue: '',
  );
  static const String defaultBannerPlacementId = String.fromEnvironment(
    'INMOBI_BANNER_PLACEMENT_ID',
    defaultValue: '',
  );

  bool _enabled = true;
  bool get enabled => _enabled;
  set enabled(bool value) {
    _enabled = value;
    if (!value) {
      _sdkStatus = AdSdkStatus.disabled;
    } else if (_sdkStatus == AdSdkStatus.disabled) {
      _sdkStatus = AdSdkStatus.uninitialized;
    }
  }

  /// Test hook to simulate InMobi SDK unavailable / network failure.
  bool simulateUnavailable = false;

  AdSdkStatus _sdkStatus = AdSdkStatus.uninitialized;
  AdSdkStatus get sdkStatus => _sdkStatus;

  Future<bool>? _initFuture;
  int _instanceCounter = 0;
  final Set<String> _activeBanners = {};

  // Telemetry & Real Traffic Metrics
  int _requests = 0;
  int _impressions = 0;
  int _fills = 0;
  int _lastLoadLatencyMs = 0;
  int _totalLoadLatencyMs = 0;
  double _totalEcpmAccumulator = 0.0;
  double _estimatedEarningsUsd = 0.0;
  String? _lastError;

  String get bannerPlacementId => defaultBannerPlacementId;
  bool get isBannerReady => _activeBanners.isNotEmpty;

  @visibleForTesting
  void resetDiagnosticsForTest() => resetDiagnostics();

  /// Backward-compatible alias for `initialize()`.
  Future<bool> init() => initialize();

  /// Initializes the InMobi SDK via the platform bridge.
  /// Never throws — if the SDK is unavailable or unconfigured, transitions to
  /// `AdSdkStatus.unavailable` so the app continues normally.
  Future<bool> initialize({String? accountId}) {
    if (!_enabled) {
      _sdkStatus = AdSdkStatus.disabled;
      return Future.value(false);
    }
    if (simulateUnavailable || kIsWeb) {
      _sdkStatus = AdSdkStatus.unavailable;
      _lastError = simulateUnavailable
          ? 'Simulated InMobi unavailable'
          : 'Web platform does not use native InMobi SDK';
      return Future.value(false);
    }
    if (_sdkStatus == AdSdkStatus.ready && _initFuture != null) {
      return _initFuture!;
    }

    _sdkStatus = AdSdkStatus.initializing;
    final resolvedAccount = (accountId ?? defaultAccountId).trim();

    _initFuture = () async {
      if (resolvedAccount.isEmpty) {
        _sdkStatus = AdSdkStatus.unavailable;
        _lastError = 'InMobi Account ID not configured';
        log('INIT_SKIPPED', 'SYSTEM', _lastError);
        return false;
      }

      try {
        final ok = await _channel
            .invokeMethod<bool>('initialize', {'accountId': resolvedAccount})
            .timeout(const Duration(seconds: 4), onTimeout: () => false);
        if (ok == true) {
          _sdkStatus = AdSdkStatus.ready;
          _lastError = null;
          log('INIT_SUCCESS', 'SYSTEM', 'InMobi SDK initialized');
          return true;
        } else {
          _sdkStatus = AdSdkStatus.unavailable;
          _lastError = 'InMobi native bridge returned false';
          log('INIT_UNAVAILABLE', 'SYSTEM', _lastError);
          return false;
        }
      } catch (e) {
        _sdkStatus = AdSdkStatus.unavailable;
        _lastError = e.toString();
        log('INIT_FAILED', 'SYSTEM', _lastError);
        return false;
      }
    }();

    return _initFuture!;
  }

  /// Requests a banner ad from InMobi and records telemetry metrics.
  /// Never throws — returns `InMobiBannerResult(loaded: false, ...)` on failure.
  Future<InMobiBannerResult> loadBanner({
    String? placementId,
    int width = 320,
    int height = 50,
  }) async {
    final instanceId = generateInstanceId();
    final resolvedPlacement = (placementId ?? defaultBannerPlacementId).trim();
    final stopwatch = Stopwatch()..start();

    _requests++;

    if (!_enabled) {
      stopwatch.stop();
      _lastLoadLatencyMs = stopwatch.elapsedMilliseconds;
      return InMobiBannerResult(
        loaded: false,
        instanceId: instanceId,
        placementId: resolvedPlacement,
        width: width,
        height: height,
        loadLatencyMs: _lastLoadLatencyMs,
        errorMessage: 'AdService is disabled',
      );
    }

    if (simulateUnavailable || kIsWeb) {
      stopwatch.stop();
      _lastLoadLatencyMs = stopwatch.elapsedMilliseconds;
      _totalLoadLatencyMs += _lastLoadLatencyMs;
      _sdkStatus = AdSdkStatus.unavailable;
      _lastError = simulateUnavailable
          ? 'InMobi unavailable (simulated)'
          : 'InMobi native banner unsupported on web';
      log('LOAD_UNAVAILABLE', instanceId, _lastError);
      return InMobiBannerResult(
        loaded: false,
        instanceId: instanceId,
        placementId: resolvedPlacement,
        width: width,
        height: height,
        loadLatencyMs: _lastLoadLatencyMs,
        errorMessage: _lastError,
      );
    }

    if (_sdkStatus != AdSdkStatus.ready) {
      final ready = await initialize();
      if (!ready) {
        stopwatch.stop();
        _lastLoadLatencyMs = stopwatch.elapsedMilliseconds;
        _totalLoadLatencyMs += _lastLoadLatencyMs;
        return InMobiBannerResult(
          loaded: false,
          instanceId: instanceId,
          placementId: resolvedPlacement,
          width: width,
          height: height,
          loadLatencyMs: _lastLoadLatencyMs,
          errorMessage: _lastError ?? 'InMobi SDK not ready',
        );
      }
    }

    if (resolvedPlacement.isEmpty) {
      stopwatch.stop();
      _lastLoadLatencyMs = stopwatch.elapsedMilliseconds;
      _totalLoadLatencyMs += _lastLoadLatencyMs;
      _lastError = 'InMobi Banner Placement ID not configured';
      log('LOAD_SKIPPED', instanceId, _lastError);
      return InMobiBannerResult(
        loaded: false,
        instanceId: instanceId,
        placementId: resolvedPlacement,
        width: width,
        height: height,
        loadLatencyMs: _lastLoadLatencyMs,
        errorMessage: _lastError,
      );
    }

    try {
      final response = await _channel.invokeMapMethod<String, dynamic>(
        'loadBanner',
        {
          'instanceId': instanceId,
          'placementId': resolvedPlacement,
          'width': width,
          'height': height,
        },
      ).timeout(const Duration(seconds: 6));

      stopwatch.stop();
      _lastLoadLatencyMs = stopwatch.elapsedMilliseconds;
      _totalLoadLatencyMs += _lastLoadLatencyMs;

      final loaded = response?['loaded'] == true;
      final ecpm = (response?['ecpm'] as num?)?.toDouble() ?? 0.0;

      if (loaded) {
        _fills++;
        _impressions++;
        _totalEcpmAccumulator += ecpm;
        _estimatedEarningsUsd += (ecpm / 1000.0);
        _activeBanners.add(instanceId);
        _lastError = null;
        log('BANNER_LOADED', instanceId, 'latency=${_lastLoadLatencyMs}ms');
        return InMobiBannerResult(
          loaded: true,
          instanceId: instanceId,
          placementId: resolvedPlacement,
          width: width,
          height: height,
          loadLatencyMs: _lastLoadLatencyMs,
          ecpm: ecpm,
        );
      } else {
        _lastError = response?['error']?.toString() ?? 'No fill';
        log('BANNER_NO_FILL', instanceId, _lastError);
        return InMobiBannerResult(
          loaded: false,
          instanceId: instanceId,
          placementId: resolvedPlacement,
          width: width,
          height: height,
          loadLatencyMs: _lastLoadLatencyMs,
          errorMessage: _lastError,
        );
      }
    } catch (e) {
      stopwatch.stop();
      _lastLoadLatencyMs = stopwatch.elapsedMilliseconds;
      _totalLoadLatencyMs += _lastLoadLatencyMs;
      _lastError = e.toString();
      log('BANNER_ERROR', instanceId, _lastError);
      return InMobiBannerResult(
        loaded: false,
        instanceId: instanceId,
        placementId: resolvedPlacement,
        width: width,
        height: height,
        loadLatencyMs: _lastLoadLatencyMs,
        errorMessage: _lastError,
      );
    }
  }

  /// Disposes an active banner instance safely.
  Future<void> disposeBanner([String? instanceId]) async {
    if (instanceId != null) {
      _activeBanners.remove(instanceId);
    } else {
      _activeBanners.clear();
    }
    if (kIsWeb || _sdkStatus != AdSdkStatus.ready) return;
    try {
      await _channel.invokeMethod('disposeBanner', {'instanceId': instanceId});
    } catch (_) {}
  }

  /// Resets telemetry counters (useful for tests).
  @visibleForTesting
  void resetDiagnostics() {
    _requests = 0;
    _impressions = 0;
    _fills = 0;
    _lastLoadLatencyMs = 0;
    _totalLoadLatencyMs = 0;
    _totalEcpmAccumulator = 0.0;
    _estimatedEarningsUsd = 0.0;
    _lastError = null;
    _activeBanners.clear();
    _sdkStatus = _enabled ? AdSdkStatus.uninitialized : AdSdkStatus.disabled;
    _initFuture = null;
  }

  /// Structured telemetry & diagnostics for real SRU Timetable traffic evaluation.
  Map<String, dynamic> get diagnostics {
    final fillRate = _requests > 0 ? (_fills / _requests) * 100.0 : 0.0;
    final avgEcpm = _fills > 0 ? (_totalEcpmAccumulator / _fills) : 0.0;
    final avgLatency = _requests > 0 ? (_totalLoadLatencyMs / _requests).round() : 0;

    return {
      'network': adNetwork,
      'format': adFormat,
      'enabled': _enabled,
      'sdkStatus': _sdkStatus.name,
      'requests': _requests,
      'impressions': _impressions,
      'fills': _fills,
      'fillRatePercent': double.parse(fillRate.toStringAsFixed(2)),
      'eCPM': double.parse(avgEcpm.toStringAsFixed(4)),
      'estimatedEarningsUsd': double.parse(_estimatedEarningsUsd.toStringAsFixed(6)),
      'revenuePerActiveUserUsd': double.parse(_estimatedEarningsUsd.toStringAsFixed(6)),
      'lastLoadLatencyMs': _lastLoadLatencyMs,
      'averageLoadLatencyMs': avgLatency,
      'activeBanners': _activeBanners.length,
      'lastError': _lastError,
    };
  }

  /// Generates a human-readable instance ID for diagnostic logging.
  String generateInstanceId() {
    _instanceCounter++;
    return 'INMOBI_BANNER_${_instanceCounter.toString().padLeft(3, '0')}';
  }

  /// Centralized debug logging for InMobi lifecycle events.
  void log(String tag, String instanceId, [String? extra]) {
    if (kDebugMode) {
      final extraStr = (extra != null && extra.isNotEmpty) ? ' - $extra' : '';
      debugPrint('[INMOBI] $tag ($instanceId)$extraStr');
    }
  }
}
