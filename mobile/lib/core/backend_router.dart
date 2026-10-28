import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'constants.dart';

/// Centralized BackendRouter implementing Cloudflare PRIMARY with Render FALLBACK.
///
/// Lifecycle:
/// 1. Tries Cloudflare Worker Primary with a bounded 8-second timeout.
/// 2. If Cloudflare succeeds (status < 500), returns response immediately.
/// 3. If Cloudflare fails (DNS/Socket/Timeout/5xx infrastructure error),
///    automatically falls over to the Render backend.
class BackendRouter {
  static final BackendRouter instance = BackendRouter._();
  static const Duration primaryTimeout = Duration(seconds: 8);
  static const Duration fallbackTimeout = Duration(seconds: 12);

  BackendRouter._();

  http.Client? _client;

  @visibleForTesting
  set testClient(http.Client? client) => _client = client;

  Future<http.Response> _httpGet(Uri uri, {Map<String, String>? headers}) {
    if (_client != null) return _client!.get(uri, headers: headers);
    return http.get(uri, headers: headers);
  }

  Future<http.Response> _httpPost(Uri uri, {Map<String, String>? headers, Object? body}) {
    if (_client != null) return _client!.post(uri, headers: headers, body: body);
    return http.post(uri, headers: headers, body: body);
  }

  static String _normalizePath(String input) {
    if (input.startsWith(AppConstants.cloudflarePrimaryUrl)) {
      return input.substring(AppConstants.cloudflarePrimaryUrl.length);
    }
    if (input.startsWith(AppConstants.renderFallbackUrl)) {
      return input.substring(AppConstants.renderFallbackUrl.length);
    }
    return input.startsWith('/') ? input : '/$input';
  }

  /// Performs a GET request with automatic fallback from Cloudflare to Render.
  Future<http.Response> get(String pathOrUrl, {Map<String, String>? headers}) async {
    final pathWithQuery = _normalizePath(pathOrUrl);
    // 1. Attempt Cloudflare Worker Primary
    try {
      final primaryUri = Uri.parse('${AppConstants.cloudflarePrimaryUrl}$pathWithQuery');
      final res = await _httpGet(primaryUri, headers: headers).timeout(primaryTimeout);
      
      // If Primary returns a valid response or client error (4xx), return it directly.
      // We only fall over for server-side infrastructure errors (5xx).
      if (res.statusCode < 500) {
        return res;
      }
      debugPrint('[BackendRouter] Primary HTTP ${res.statusCode}, failing over to Render fallback');
    } catch (e) {
      debugPrint('[BackendRouter] Primary request failed ($e), failing over to Render fallback');
    }

    // 2. Fallback to Render
    final fallbackUri = Uri.parse('${AppConstants.renderFallbackUrl}$pathWithQuery');
    return await _httpGet(fallbackUri, headers: headers).timeout(fallbackTimeout);
  }

  /// Performs a POST request with automatic fallback from Cloudflare to Render.
  Future<http.Response> post(
    String pathOrUrl, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    final pathWithQuery = _normalizePath(pathOrUrl);
    // 1. Attempt Cloudflare Worker Primary
    try {
      final primaryUri = Uri.parse('${AppConstants.cloudflarePrimaryUrl}$pathWithQuery');
      final res = await _httpPost(primaryUri, headers: headers, body: body).timeout(primaryTimeout);
      
      if (res.statusCode < 500) {
        return res;
      }
      debugPrint('[BackendRouter] Primary POST HTTP ${res.statusCode}, failing over to Render fallback');
    } catch (e) {
      debugPrint('[BackendRouter] Primary POST failed ($e), failing over to Render fallback');
    }

    // 2. Fallback to Render
    final fallbackUri = Uri.parse('${AppConstants.renderFallbackUrl}$pathWithQuery');
    return await _httpPost(fallbackUri, headers: headers, body: body).timeout(fallbackTimeout);
  }
}

