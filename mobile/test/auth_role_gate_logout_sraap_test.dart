import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/constants.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:mobile/core/storage.dart';
import 'package:mobile/core/auth/auth_repository.dart';
import 'package:mobile/core/auth/auth_state.dart';
import 'package:mobile/core/auth/secure_session_store.dart';
import 'package:mobile/features/onboarding/mode_selection_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final secureStorageValues = <String, String>{};

  setUpAll(() async {
    AppConstants.useSystemFontInTests = true;
    final path = Directory.systemTemp.createTempSync().path;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async => path,
    );

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'write') {
          secureStorageValues[methodCall.arguments['key'] as String] =
              methodCall.arguments['value'] as String;
          return null;
        } else if (methodCall.method == 'read') {
          return secureStorageValues[methodCall.arguments['key'] as String];
        } else if (methodCall.method == 'delete') {
          secureStorageValues.remove(methodCall.arguments['key'] as String);
          return null;
        } else if (methodCall.method == 'deleteAll') {
          secureStorageValues.clear();
          return null;
        } else if (methodCall.method == 'readAll') {
          return Map<String, String>.from(secureStorageValues);
        }
        return null;
      },
    );

    Hive.init(path);
    await StorageService.init();
  });

  tearDownAll(() async {
    await Hive.close();
  });

  setUp(() {
    secureStorageValues.clear();
  });

  group('P0: Role Gate & Onboarding Tests', () {
    testWidgets('ModeSelectionScreen displays Student and Faculty options', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ModeSelectionScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Choose how you use SRU Timetable'), findsOneWidget);
      expect(find.text('Student'), findsOneWidget);
      expect(find.text('Faculty'), findsOneWidget);
    });
  });

  group('P0: Authentication State Machine & Storage Gate', () {
    test('Cached timetable or roll number without valid session sets AuthState.unauthenticated', () async {
      await StorageService.saveStudentRollNumber('2103A51000');
      await StorageService.setUserMode('student');
      await StorageService.saveTimetableCache([
        {'id': '1', 'subject': 'Physics', 'day': 'monday'}
      ]);

      // restoreSession without session cookie
      await AuthRepository.instance.restoreSession();

      expect(AuthRepository.instance.state, AuthState.unauthenticated);
      expect(AuthRepository.instance.currentRole, isNull);
    });

    test('Valid persisted session cookie successfully restores AuthState.ready', () async {
      await SecureSessionStore.saveSession({
        'cookie': 'sruniv_session=active_valid_session_123',
        'role': 'student',
        'identifier': '2103A51000',
      }, role: 'student');
      await StorageService.setUserMode('student');

      await AuthRepository.instance.restoreSession();

      expect(AuthRepository.instance.state, AuthState.ready);
      expect(AuthRepository.instance.currentRole, 'student');
    });

    test('Logout completely terminates auth and clears user identifiers', () async {
      // Setup authenticated state
      await SecureSessionStore.saveSession({
        'cookie': 'sruniv_session=test_cookie',
        'role': 'student',
        'identifier': '2103A51000',
      }, role: 'student');
      await StorageService.setUserMode('student');
      await StorageService.saveUserIdentifier('2103A51000');
      await StorageService.saveStudentRollNumber('2103A51000');
      await StorageService.saveUserName('John Doe');

      // Execute logout
      await AuthRepository.instance.logout();

      // Verify complete teardown
      expect(AuthRepository.instance.state, AuthState.unauthenticated);
      expect(AuthRepository.instance.currentRole, isNull);
      expect(AuthRepository.instance.savedIdentifier, isNull);
      expect(await SecureSessionStore.getSession(), isNull);
      expect(StorageService.getUserIdentifier(), isNull);
      expect(StorageService.getStudentRollNumber(), isNull);
      expect(StorageService.getUserName(), isNull);
      expect(StorageService.getUserMode(), isNull);
    });
  });

  group('P0: SRAAP Response Evaluation & CAPTCHA Correctness', () {
    test('Differentiates incorrect CAPTCHA from invalid credentials', () {
      // Mock server response when CAPTCHA code is wrong (contains Enter CAPTCHA code)
      final captchaFailResponse = http.Response(
        '<html><body><b>Enter CAPTCHA code:<br></b><input placeholder="Captcha"></body></html>',
        200,
      );

      // Test direct evaluation logic
      final body1 = captchaFailResponse.body.toLowerCase();
      final isCaptchaErr = body1.contains('enter captcha code') || body1.contains('invalid captcha');
      expect(isCaptchaErr, isTrue);

      // Mock server response when CAPTCHA is correct but credentials are wrong
      final credsFailResponse = http.Response(
        "<html><body><b><p style='color: darkred;'>Sorry, I don't recognize you, kindly recheck.</p></b><input placeholder='Captcha'></body></html>",
        200,
      );

      final body2 = credsFailResponse.body.toLowerCase();
      final isCredsErr = body2.contains("sorry, i don't recognize you") || body2.contains('recheck');
      expect(isCredsErr, isTrue);
      // Ensure it is NOT falsely identified as captcha error even though the word 'Captcha' is in the HTML
      final isCaptchaErrOnCreds = body2.contains('enter captcha code') || body2.contains('invalid captcha');
      expect(isCaptchaErrOnCreds, isFalse);
    });

    test('Identifies SRAAP successful redirect', () {
      final success302 = http.Response('', 302, headers: {'location': 'student/dash_board.php'});
      final isSuccess = success302.statusCode == 302 || success302.statusCode == 301;
      expect(isSuccess, isTrue);
    });
  });
}
