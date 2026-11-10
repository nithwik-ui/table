import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/core/constants.dart';
import 'package:mobile/core/storage.dart';
import 'package:mobile/core/sraap/sraap_academic_service.dart';
import 'package:mobile/core/sraap/sraap_auth_manager.dart';
import 'package:mobile/core/sraap/sraap_session_manager.dart';
import 'package:mobile/core/sraap/sraap_session_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Valid minimal PNG header bytes
  final validPngBytes = Uint8List.fromList([
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
    0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
  ]);

  setUpAll(() async {
    AppConstants.useSystemFontInTests = true;
    final path = Directory.systemTemp.createTempSync().path;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async => path,
    );
    Hive.init(path);
    await StorageService.init();
  });

  tearDownAll(() async {
    await Hive.close();
  });

  setUp(() async {
    await SraapSessionManager.instance.clearSession();
  });

  group('1. CAPTCHA State & Session Continuity Tests', () {
    test('CAPTCHA load success initializes session and transitions to captchaReady', () async {
      int loginPageHits = 0;
      int captchaHits = 0;
      String? cookieOnCaptchaRequest;

      SraapSessionManager.instance.client = MockClient((req) async {
        if (req.url.path.endsWith('/student_login.php')) {
          loginPageHits++;
          return http.Response(
            '<html><body>Login</body></html>',
            200,
            headers: {'set-cookie': 'PHPSESSID=sess_abc123; path=/; secure'},
          );
        }
        if (req.url.path.endsWith('/captcha/image.php')) {
          captchaHits++;
          cookieOnCaptchaRequest = req.headers['Cookie'] ?? req.headers['x-proxy-cookie'];
          return http.Response.bytes(
            validPngBytes,
            200,
            headers: {'content-type': 'image/png'},
          );
        }
        return http.Response('Not found', 404);
      });

      final bytes = await SraapSessionManager.instance.fetchCaptcha(
        forceFreshSession: true,
      );

      expect(bytes, isNotNull);
      expect(bytes, equals(validPngBytes));
      expect(loginPageHits, equals(1));
      expect(captchaHits, equals(1));
      expect(cookieOnCaptchaRequest, equals('PHPSESSID=sess_abc123'));
      expect(
        SraapSessionManager.instance.flowState,
        equals(SraapLoginFlowState.captchaReady),
      );
    });

    test('Manual CAPTCHA refresh reuses existing PHPSESSID without wiping session', () async {
      int loginPageHits = 0;
      int captchaHits = 0;
      final seenCookies = <String?>[];

      SraapSessionManager.instance.client = MockClient((req) async {
        if (req.url.path.endsWith('/student_login.php')) {
          loginPageHits++;
          return http.Response(
            '<html><body>Login</body></html>',
            200,
            headers: {'set-cookie': 'PHPSESSID=sess_keep_me; path=/; secure'},
          );
        }
        if (req.url.path.endsWith('/captcha/image.php')) {
          captchaHits++;
          seenCookies.add(req.headers['Cookie'] ?? req.headers['x-proxy-cookie']);
          return http.Response.bytes(
            validPngBytes,
            200,
            headers: {'content-type': 'image/png'},
          );
        }
        return http.Response('Not found', 404);
      });

      // Initial load creates session
      final first = await SraapSessionManager.instance.fetchCaptcha(
        forceFreshSession: true,
      );
      expect(first, isNotNull);
      expect(loginPageHits, equals(1));
      expect(captchaHits, equals(1));

      // Manual refresh (forceFreshSession: false) reuses PHPSESSID=sess_keep_me
      final second = await SraapSessionManager.instance.fetchCaptcha(
        forceFreshSession: false,
      );
      expect(second, isNotNull);
      expect(loginPageHits, equals(1)); // Must NOT re-download 104KB student_login.php
      expect(captchaHits, equals(2));
      expect(seenCookies, equals(['PHPSESSID=sess_keep_me', 'PHPSESSID=sess_keep_me']));
    });

    test('CAPTCHA load failure rejects HTML captive portal / error payload disguised as 200', () async {
      SraapSessionManager.instance.client = MockClient((req) async {
        if (req.url.path.endsWith('/student_login.php')) {
          return http.Response(
            '<html></html>',
            200,
            headers: {'set-cookie': 'PHPSESSID=sess_err; path=/'},
          );
        }
        if (req.url.path.endsWith('/captcha/image.php')) {
          return http.Response(
            '<!DOCTYPE html><html><body>Captive Portal Login Required</body></html>',
            200,
            headers: {'content-type': 'text/html'},
          );
        }
        return http.Response('', 500);
      });

      final bytes = await SraapSessionManager.instance.fetchCaptcha(
        forceFreshSession: true,
      );
      expect(bytes, isNull);
      expect(
        SraapSessionManager.instance.flowState,
        equals(SraapLoginFlowState.captchaError),
      );
    });

    test('Slow network fallback: if student_login.php times out, captcha/image.php still initializes session', () async {
      SraapSessionManager.instance.client = MockClient((req) async {
        if (req.url.path.endsWith('/student_login.php')) {
          throw TimeoutException('student_login.php 104KB timed out');
        }
        if (req.url.path.endsWith('/captcha/image.php')) {
          return http.Response.bytes(
            validPngBytes,
            200,
            headers: {
              'set-cookie': 'PHPSESSID=sess_from_captcha; path=/; secure',
              'content-type': 'image/png',
            },
          );
        }
        return http.Response('', 404);
      });

      final bytes = await SraapSessionManager.instance.fetchCaptcha(
        forceFreshSession: true,
      );
      expect(bytes, isNotNull);
      expect(
        SraapSessionManager.instance.cookieHeader,
        equals('PHPSESSID=sess_from_captcha'),
      );
      expect(
        SraapSessionManager.instance.flowState,
        equals(SraapLoginFlowState.captchaReady),
      );
    });

    test('Concurrent fetchCaptcha calls coalesce into a single request without session race', () async {
      int captchaRequests = 0;

      SraapSessionManager.instance.client = MockClient((req) async {
        if (req.url.path.endsWith('/student_login.php')) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
          return http.Response(
            '<html></html>',
            200,
            headers: {'set-cookie': 'PHPSESSID=single_sess; path=/'},
          );
        }
        if (req.url.path.endsWith('/captcha/image.php')) {
          captchaRequests++;
          await Future<void>.delayed(const Duration(milliseconds: 20));
          return http.Response.bytes(
            validPngBytes,
            200,
            headers: {'content-type': 'image/png'},
          );
        }
        return http.Response('', 404);
      });

      final results = await Future.wait([
        SraapSessionManager.instance.fetchCaptcha(forceFreshSession: true),
        SraapSessionManager.instance.fetchCaptcha(forceFreshSession: true),
      ]);

      expect(results[0], isNotNull);
      expect(results[1], isNotNull);
      expect(captchaRequests, equals(1));
      expect(
        SraapSessionManager.instance.cookieHeader,
        equals('PHPSESSID=single_sess'),
      );
    });
  });

  group('2. Login Error Classification & Compatibility Tests', () {
    test('Classifies native 302 redirect to student/dash_board.php as success', () {
      final res = http.Response(
        '',
        302,
        headers: {'location': 'student/dash_board.php'},
      );
      final eval = SraapAuthManager.evaluateLoginResponse(res);
      expect(eval.success, isTrue);
    });

    test('Classifies Web/PWA proxy 200 OK with x-proxy-redirect header and empty body as success', () {
      final res = http.Response(
        '',
        200,
        headers: {'x-proxy-redirect': '/api/sraap/student/dash_board.php'},
      );
      final eval = SraapAuthManager.evaluateLoginResponse(res);
      expect(eval.success, isTrue);
    });

    test('Classifies HTTP 200 with inline JS redirect to student/dash_board.php as success', () {
      final res = http.Response(
        "<script>window.location.href = 'student/dash_board.php';</script>",
        200,
      );
      final eval = SraapAuthManager.evaluateLoginResponse(res);
      expect(eval.success, isTrue);
    });

    test('Verifies authenticated session via dash_board.php when POST returns ambiguous 200 OK', () async {
      int dashboardCheckCount = 0;

      SraapSessionManager.instance.client = MockClient((req) async {
        if (req.url.path.endsWith('/student_login.php') && req.method == 'GET') {
          return http.Response(
            '<html></html>',
            200,
            headers: {'set-cookie': 'PHPSESSID=auth_sess_77; path=/'},
          );
        }
        if (req.url.path.endsWith('/captcha/image.php')) {
          return http.Response.bytes(
            validPngBytes,
            200,
            headers: {'content-type': 'image/png'},
          );
        }
        if (req.url.path.endsWith('/student_login.php') && req.method == 'POST') {
          // Simulate PHP headers already flushed by 5KB convocationModal on sraap.in:
          // returns 200 OK without explicit error banner while session is authenticated
          return http.Response(
            '<html><body><div id="convocationModal">Fee Reminder</div></body></html>',
            200,
          );
        }
        if (req.url.path.endsWith('/student/dash_board.php')) {
          dashboardCheckCount++;
          return http.Response(
            '<html><body>Welcome to Student Portal <table id="attendanceTable"></table> <a href="logout.php">Logout</a></body></html>',
            200,
          );
        }
        return http.Response('', 404);
      });

      await SraapSessionManager.instance.fetchCaptcha(forceFreshSession: true);
      final result = await SraapAuthManager.submitLogin(
        enrollment: '2303A51001',
        password: 'secretPassword',
        captcha: 'mAui',
      );

      expect(result.success, isTrue);
      expect(dashboardCheckCount, equals(1));
      expect(
        SraapSessionManager.instance.flowState,
        equals(SraapLoginFlowState.authenticated),
      );
    });

    test('Classifies wrong CAPTCHA (<b>Enter CAPTCHA code:<br></b>) as invalidCaptcha', () {
      final res = http.Response(
        '<html><body><b>Enter CAPTCHA code:<br></b><input name="token" placeholder="Captcha"></body></html>',
        200,
      );
      final eval = SraapAuthManager.evaluateLoginResponse(res);
      expect(eval.success, isFalse);
      expect(eval.error, equals(SraapLoginError.invalidCaptcha));
    });

    test('Classifies invalid credentials accurately without confusing with CAPTCHA error', () {
      final res = http.Response(
        "<html><body><b><p>Sorry, I don't recognize you, kindly recheck.</p><a href='forgot_passwords.php'>Forgot / Reset password</a></b><input name='token' placeholder='Captcha'></body></html>",
        200,
      );
      final eval = SraapAuthManager.evaluateLoginResponse(res);
      expect(eval.success, isFalse);
      expect(eval.error, equals(SraapLoginError.invalidCredentials));
    });

    test('Classifies expired session (slogin.php / In Valid Login) as sessionExpired', () {
      final res = http.Response(
        "<script>window.location.href = '../slogin.php';</script><h1>In Valid Login</h1>",
        200,
      );
      final eval = SraapAuthManager.evaluateLoginResponse(res);
      expect(eval.success, isFalse);
      expect(eval.error, equals(SraapLoginError.sessionExpired));
    });

    test('Classifies "In Valid Login" or "Invalid Login" as invalidCredentials', () {
      final res1 = http.Response('<html><body><h1>In Valid Login</h1></body></html>', 200);
      expect(SraapAuthManager.evaluateLoginResponse(res1).error, equals(SraapLoginError.invalidCredentials));

      final res2 = http.Response('<html><body><h1>Invalid Login</h1></body></html>', 200);
      expect(SraapAuthManager.evaluateLoginResponse(res2).error, equals(SraapLoginError.invalidCredentials));
    });

    test('Classifies IP restriction and Server busy as portalUnavailable', () {
      final resIp = http.Response(
        '<html><body>Access Restricted due to shared public IP</body></html>',
        200,
      );
      expect(
        SraapAuthManager.evaluateLoginResponse(resIp).error,
        equals(SraapLoginError.portalUnavailable),
      );

      final resBusy = http.Response(
        '<h2>Server busy. Please try again later.</h2>',
        200,
      );
      expect(
        SraapAuthManager.evaluateLoginResponse(resBusy).error,
        equals(SraapLoginError.portalUnavailable),
      );
    });
  });

  group('3. Loop Prevention, Background Isolation & Safe Diagnostic Logging', () {
    test('One login submission = exactly one POST request (no automatic retry or CAPTCHA loop)', () async {
      int postCount = 0;
      int captchaCount = 0;

      SraapSessionManager.instance.client = MockClient((req) async {
        if (req.url.path.endsWith('/student_login.php') && req.method == 'GET') {
          return http.Response(
            '<html></html>',
            200,
            headers: {'set-cookie': 'PHPSESSID=loop_guard; path=/'},
          );
        }
        if (req.url.path.endsWith('/captcha/image.php')) {
          captchaCount++;
          return http.Response.bytes(
            validPngBytes,
            200,
            headers: {'content-type': 'image/png'},
          );
        }
        if (req.url.path.endsWith('/student_login.php') && req.method == 'POST') {
          postCount++;
          return http.Response(
            '<html><body><b>Enter CAPTCHA code:<br></b></body></html>',
            200,
          );
        }
        return http.Response('', 404);
      });

      await SraapSessionManager.instance.fetchCaptcha(forceFreshSession: true);
      expect(captchaCount, equals(1));

      final result = await SraapAuthManager.submitLogin(
        enrollment: '2303A51001',
        password: 'wrong',
        captcha: '0000',
      );

      expect(result.success, isFalse);
      expect(result.error, equals(SraapLoginError.invalidCaptcha));
      expect(postCount, equals(1));
      // submitLogin itself never triggers an uncontrolled background CAPTCHA fetch loop
      expect(captchaCount, equals(1));
    });

    test('submitLogin normalizes lowercase roll numbers to uppercase in payload', () async {
      String? sentUserId;
      SraapSessionManager.instance.client = MockClient((req) async {
        if (req.url.path.endsWith('/student_login.php') && req.method == 'POST') {
          sentUserId = req.bodyFields['user_id'];
          return http.Response(
            '',
            302,
            headers: {'location': 'student/dash_board.php'},
          );
        }
        return http.Response('', 404);
      });

      final result = await SraapAuthManager.submitLogin(
        enrollment: '2403a53050',
        password: 'password123',
        captcha: 'abcd',
      );

      expect(result.success, isTrue);
      expect(sentUserId, equals('2403A53050'));
    });

    test('Background pingKeepAlive is suppressed while isLoginFlowActive is true', () async {
      int dashboardHits = 0;
      await StorageService.setSraapConnected(true);
      await StorageService.saveSessionState({
        'cookie': 'PHPSESSID=old_expired_cookie',
        'cookieHeader': 'PHPSESSID=old_expired_cookie',
      });

      SraapSessionManager.instance.client = MockClient((req) async {
        if (req.url.path.endsWith('/student_login.php')) {
          return http.Response(
            '<html></html>',
            200,
            headers: {'set-cookie': 'PHPSESSID=active_login_cookie; path=/'},
          );
        }
        if (req.url.path.endsWith('/captcha/image.php')) {
          return http.Response.bytes(
            validPngBytes,
            200,
            headers: {'content-type': 'image/png'},
          );
        }
        if (req.url.path.endsWith('/student/dash_board.php')) {
          dashboardHits++;
          return http.Response('<h1>In Valid Login</h1>', 200);
        }
        return http.Response('', 404);
      });

      SraapSessionManager.instance.isLoginFlowActive = true;
      await SraapSessionManager.instance.fetchCaptcha(forceFreshSession: true);
      expect(
        SraapSessionManager.instance.cookieHeader,
        equals('PHPSESSID=active_login_cookie'),
      );

      // Simulate app resume triggering pingKeepAlive while user is on login screen
      await SraapAcademicService.instance.pingKeepAlive();
      await SraapSessionManager.instance.restoreSession();

      expect(dashboardHits, equals(0));
      expect(
        SraapSessionManager.instance.cookieHeader,
        equals('PHPSESSID=active_login_cookie'),
      );
      SraapSessionManager.instance.isLoginFlowActive = false;
    });

    test('Diagnostic log contains required keys and never leaks sensitive values', () async {
      SraapSessionManager.instance.client = MockClient((req) async {
        if (req.url.path.endsWith('/student_login.php') && req.method == 'GET') {
          return http.Response(
            '<html></html>',
            200,
            headers: {'set-cookie': 'PHPSESSID=super_secret_cookie_val; path=/'},
          );
        }
        if (req.url.path.endsWith('/captcha/image.php')) {
          return http.Response.bytes(
            validPngBytes,
            200,
            headers: {'content-type': 'image/png'},
          );
        }
        if (req.url.path.endsWith('/student_login.php') && req.method == 'POST') {
          return http.Response(
            '',
            302,
            headers: {'location': 'student/dash_board.php'},
          );
        }
        return http.Response('', 404);
      });

      await SraapSessionManager.instance.fetchCaptcha(forceFreshSession: true);
      await SraapAuthManager.submitLogin(
        enrollment: '2303A59999',
        password: 'MySuperSecretPassword123!',
        captcha: 'mAui',
      );

      final log = SraapSessionManager.instance.lastDebugLog;
      expect(log, contains('SRAAP_LOGIN: session_initialized=true'));
      expect(log, contains('SRAAP_LOGIN: captcha_load_started=true'));
      expect(log, contains('SRAAP_LOGIN: captcha_load_completed=true'));
      expect(log, contains('SRAAP_LOGIN: captcha_http_status=200'));
      expect(log, contains('SRAAP_LOGIN: captcha_content_type=image/png'));
      expect(log, contains('SRAAP_LOGIN: login_submit_started=true'));
      expect(log, contains('SRAAP_LOGIN: login_response_status=302'));
      expect(log, contains('SRAAP_LOGIN: redirect_detected=true'));
      expect(log, contains('SRAAP_LOGIN: session_cookie_present=true'));

      // Verify zero leakage of secrets
      expect(log.contains('MySuperSecretPassword123!'), isFalse);
      expect(log.contains('super_secret_cookie_val'), isFalse);
      expect(log.contains('mAui'), isFalse);
      expect(utf8.encode(log).isNotEmpty, isTrue);
    });
  });
}

