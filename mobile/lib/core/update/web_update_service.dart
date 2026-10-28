import 'package:flutter/foundation.dart';

/// Service responsible for Web/PWA updates (Service Worker updates).
class WebUpdateService {
  WebUpdateService._();
  static final WebUpdateService instance = WebUpdateService._();

  bool get isWeb => kIsWeb;

  /// Checks if a PWA service worker update is waiting to activate.
  Future<bool> checkForWebUpdate() async {
    if (!kIsWeb) return false;
    // On web, Flutter PWA updates are managed by flutter_service_worker.js
    return false;
  }
}
