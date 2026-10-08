import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Centralized AdMob management service.
///
/// Ensures deterministic initialization, unit ID routing, and debug diagnostics.
class AdService {
  static final AdService instance = AdService._internal();
  AdService._internal();

  bool _isInitialized = false;
  Future<InitializationStatus>? _initFuture;
  int _instanceCounter = 0;

  // Official Google Anchored Adaptive Banner test ID (safe for dev/testing)
  static const String testBannerIdAndroid = 'ca-app-pub-3940256099942544/9214589741';
  static const String testBannerIdIos = 'ca-app-pub-3940256099942544/2934735716';

  // Production Banner Unit ID
  static const String prodBannerIdAndroid = 'ca-app-pub-4600395533739943/8970984870';
  static const String prodBannerIdIos = 'ca-app-pub-4600395533739943/8970984870';

  /// Returns the appropriate Banner Ad Unit ID based on platform and build mode.
  String get bannerAdUnitId {
    if (kReleaseMode) {
      return Platform.isAndroid ? prodBannerIdAndroid : prodBannerIdIos;
    }
    return Platform.isAndroid ? testBannerIdAndroid : testBannerIdIos;
  }

  /// Initializes MobileAds SDK exactly once and returns the initialization future.
  Future<InitializationStatus> init() {
    if (_isInitialized && _initFuture != null) {
      return _initFuture!;
    }
    _initFuture = MobileAds.instance.initialize().then((status) {
      _isInitialized = true;
      if (kDebugMode) {
        debugPrint('[ADMOB] SDK Initialized successfully');
      }
      return status;
    }).catchError((e) {
      debugPrint('[ADMOB] SDK Initialization failed: $e');
      throw e;
    });
    return _initFuture!;
  }

  /// Generates a human-readable instance ID for diagnostic logging.
  String generateInstanceId() {
    _instanceCounter++;
    return 'ADMOB_BANNER_${_instanceCounter.toString().padLeft(3, '0')}';
  }

  /// Centralized debug logging for AdMob lifecycle events.
  void log(String tag, String instanceId, [String? extra]) {
    if (kDebugMode) {
      final extraStr = (extra != null && extra.isNotEmpty) ? ' - $extra' : '';
      debugPrint('[ADMOB] $tag ($instanceId)$extraStr');
    }
  }
}
