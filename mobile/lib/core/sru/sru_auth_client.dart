import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import 'package:flutter/foundation.dart';

class SruAuthException implements Exception {
  final String message;
  SruAuthException(this.message);
  @override
  String toString() => message;
}

class SruAuthClient {
  static final SruAuthClient instance = SruAuthClient._();
  SruAuthClient._();

  http.Client _client = http.Client();
  String _cookieHeader = '';
  final Map<String, String> _cookies = {};
  
  // The actual SRU Timetable portal URL
  static String get baseUrl => kIsWeb ? '/api/sru' : 'https://www.sruniv.com';
  
  String get cookieHeader => _cookieHeader;

  void restoreCookies(String cookieString) {
    _cookieHeader = cookieString;
    _cookies.clear();
    final parts = _cookieHeader.split(';');
    for (var p in parts) {
      final kv = p.trim().split('=');
      if (kv.length >= 2) {
        _cookies[kv[0]] = kv.sublist(1).join('=');
      }
    }
  }

  String? _cachedOtpToken;
  String _otpTargetUrl = '$baseUrl/verify-otp';

  Future<void> prefetchOtpToken([String? customUrl]) async {
    try {
      final url = customUrl ?? _otpTargetUrl;
      final token = await _getCsrfToken(url);
      if (token != null && token.isNotEmpty) {
        _cachedOtpToken = token;
      }
    } catch (_) {}
  }

  Future<String?> _getCsrfToken(String url) async {
    try {
      final response = await _client.get(Uri.parse(url), headers: _headers())
          .timeout(const Duration(seconds: 10));
      _updateCookies(response.headers);
      if (response.statusCode == 200) {
        final document = html_parser.parse(response.body);
        final tokenInput = document.querySelector('input[name="_token"]');
        return tokenInput?.attributes['value'];
      }
    } catch (_) {}
    return null;
  }

  Future<Map<String, dynamic>> login(String identifier, String password) async {
    final getCsrfUrl = '$baseUrl/';
    final postLoginUrl = '$baseUrl/';
    _cachedOtpToken = null;
    
    final token = await _getCsrfToken(getCsrfUrl);
    
    final request = http.Request('POST', Uri.parse(postLoginUrl));
    if (!kIsWeb) {
      request.followRedirects = false; // Handle 302 manually to preserve cookies on mobile
    }
    request.headers.addAll(_headers(isForm: true));
    request.bodyFields = {
      '_token': token ?? '',
      'login_identifier': identifier,
      'password': password,
    };
    
    final streamedResponse = await _client.send(request).timeout(const Duration(seconds: 15));
    final response = await http.Response.fromStream(streamedResponse);
    _updateCookies(response.headers);
    
    if (response.statusCode == 302) {
      final rawLocation = response.headers['location'] ?? '';
      final location = rawLocation.toLowerCase();
      
      if (location.contains('otp') || location.contains('verification')) {
        _otpTargetUrl = rawLocation.startsWith('http') ? rawLocation : '$baseUrl$rawLocation';
        // Prefetch OTP CSRF token immediately in the background
        prefetchOtpToken(_otpTargetUrl);
        return {'status': 'otp_required'};
      } else if (location.contains('dashboard') || location.contains('student') || location.contains('faculty')) {
        return {'status': 'authenticated'};
      } else {
        throw SruAuthException('Invalid credentials or SRU rejected the login.');
      }
    } else {
      final body = response.body.toLowerCase();
      if (body.contains('invalid') || body.contains('wrong') || body.contains('incorrect') || body.contains('credentials')) {
        throw SruAuthException('Your login details could not be verified.');
      }
      throw SruAuthException('Invalid credentials or SRU rejected the login.');
    }
  }

  Future<Map<String, dynamic>> verifyOtp(String otp) async {
    final otpUrl = _otpTargetUrl;
    
    // Use pre-fetched token if available, otherwise fetch quickly
    String? token = _cachedOtpToken;
    if (token == null || token.isEmpty) {
      token = await _getCsrfToken(otpUrl);
    }
    
    final request = http.Request('POST', Uri.parse(otpUrl));
    if (!kIsWeb) {
      request.followRedirects = false;
    }
    request.headers.addAll(_headers(isForm: true));
    request.bodyFields = {
      '_token': token ?? '',
      'otp': otp,
    };
    
    final streamedResponse = await _client.send(request).timeout(const Duration(seconds: 15));
    final response = await http.Response.fromStream(streamedResponse);
    _updateCookies(response.headers);
    
    if (response.statusCode == 302) {
      final location = response.headers['location']?.toLowerCase() ?? '';
      if (location.contains('dashboard') || location.contains('student') || location.contains('faculty')) {
        return {'status': 'authenticated'};
      }
      throw SruAuthException('Verification code is invalid.');
    } else {
      final body = response.body.toLowerCase();
      final finalUrl = response.request?.url.toString().toLowerCase() ?? '';
      
      // On Web, HTTP client automatically follows redirects, so we get 200 instead of 302
      if (finalUrl.contains('dashboard') || finalUrl.contains('student') || finalUrl.contains('faculty')) {
        return {'status': 'authenticated'};
      }

      if (body.contains('invalid') || body.contains('wrong') || body.contains('incorrect')) {
        throw SruAuthException('Verification code is invalid.');
      }
      throw SruAuthException('Failed to verify OTP. Please try again.');
    }
  }

  Future<http.Response> getAuthenticated(String url) async {
    final response = await _client.get(Uri.parse(url), headers: _headers())
        .timeout(const Duration(seconds: 15));
    _updateCookies(response.headers);
    return response;
  }

  void clearSession() {
    _cookieHeader = '';
    _cookies.clear();
    _client.close();
    _client = http.Client();
  }

  Map<String, String> _headers({bool isForm = false}) {
    final headers = {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
    };
    if (isForm) {
      headers['Content-Type'] = 'application/x-www-form-urlencoded';
      headers['Origin'] = baseUrl;
      headers['Referer'] = '$baseUrl/';
    }
    if (_cookieHeader.isNotEmpty) {
      headers['Cookie'] = _cookieHeader;
    }
    return headers;
  }

  void _updateCookies(Map<String, String> headers) {
    final setCookie = headers['set-cookie'];
    if (setCookie != null && setCookie.isNotEmpty) {
      final parts = setCookie.split(RegExp(r',(?=[a-zA-Z0-9_\-]+=|$)'));
      for (var part in parts) {
        final cookieString = part.split(';').first.trim();
        final equalIndex = cookieString.indexOf('=');
        if (equalIndex != -1) {
          final key = cookieString.substring(0, equalIndex);
          final value = cookieString.substring(equalIndex + 1);
          _cookies[key] = value;
        }
      }
      if (_cookies.isNotEmpty) {
        _cookieHeader = _cookies.entries.map((e) => '${e.key}=${e.value}').join('; ');
      }
    }
  }
}
