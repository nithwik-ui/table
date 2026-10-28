import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mobile/core/constants.dart';
import 'package:mobile/core/storage.dart';
import 'package:mobile/widgets/timetable_card.dart';
import 'package:mobile/features/onboarding/sru_login_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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

  group('TimetableCard Layout & Non-Collision Tests', () {
    testWidgets('Starts in 152 min badge is placed below time and room, never overlapping',
        (WidgetTester tester) async {
      final classEvent = {
        'id': 'test_1',
        'subject': 'Algorithms',
        'start_time': '09:30',
        'end_time': '11:30',
        'room': '1106-B',
        'faculty': 'Mr. Srinivas Komakula',
        'ltp': 'Lab',
      };

      // Set screen size to standard Android width 360x800
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: TimetableCard(
                classEvent: classEvent,
                status: 'Starts in 152 min',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Ensure all elements exist
      expect(find.text('Algorithms'), findsOneWidget);
      expect(find.textContaining('9:30 AM'), findsOneWidget);
      expect(find.text('1106-B'), findsOneWidget);
      expect(find.text('Mr. Srinivas Komakula'), findsOneWidget);
      expect(find.text('Starts in 152 min'), findsOneWidget);
      expect(find.text('Lab'), findsOneWidget);

      // Verify geometry: status badge must be vertically below room and time
      final timeRect = tester.getRect(find.textContaining('9:30 AM'));
      final roomRect = tester.getRect(find.text('1106-B'));
      final badgeRect = tester.getRect(find.text('Starts in 152 min'));
      final labRect = tester.getRect(find.text('Lab'));

      // Badge must be strictly below time and room
      expect(badgeRect.top, greaterThanOrEqualTo(timeRect.bottom));
      expect(badgeRect.top, greaterThanOrEqualTo(roomRect.bottom));

      // No horizontal collision between time and room
      // If on same line, room must be to the right of time; if wrapped, below
      if (roomRect.top == timeRect.top) {
        expect(roomRect.left, greaterThanOrEqualTo(timeRect.right));
      } else {
        expect(roomRect.top, greaterThanOrEqualTo(timeRect.bottom));
      }

      // Status badge and Lab badge must not overlap each other
      if (labRect.top == badgeRect.top) {
        expect(labRect.left, greaterThanOrEqualTo(badgeRect.right));
      } else {
        expect(labRect.top, greaterThanOrEqualTo(badgeRect.bottom));
      }
    });

    testWidgets('Scheduled status with long room name does not collide on narrow 320px phone',
        (WidgetTester tester) async {
      final classEvent = {
        'id': 'test_2',
        'subject': 'Software Engineering and System Design',
        'start_time': '10:30',
        'end_time': '12:30',
        'room': 'Mechanical Engineering Block B-204',
        'faculty': 'Dr. K. Ramakrishna Rao',
        'ltp': 'Lecture',
      };

      // Set screen size to narrow width 320x640
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: TimetableCard(
                classEvent: classEvent,
                status: 'Scheduled',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Software Engineering and System Design'), findsOneWidget);
      expect(find.text('Scheduled'), findsOneWidget);
      expect(find.text('Mechanical Engineering Block B-204'), findsOneWidget);

      final roomRect = tester.getRect(find.text('Mechanical Engineering Block B-204'));
      final statusRect = tester.getRect(find.text('Scheduled'));

      // Status badge must be below room metadata
      expect(statusRect.top, greaterThanOrEqualTo(roomRect.bottom));
    });

    testWidgets('Long multi-line subject wraps naturally and does not cause overflow',
        (WidgetTester tester) async {
      final classEvent = {
        'id': 'test_3',
        'subject': 'Advanced Computer Architecture, Microprocessors, and Embedded System Applications',
        'start_time': '14:00',
        'end_time': '16:00',
        'room': 'Auditorium Hall 1',
        'faculty': 'Prof. Dr. V. Subrahmanyam',
        'ltp': 'Lab',
      };

      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: TimetableCard(
                classEvent: classEvent,
                status: 'Starts in 45 min',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Starts in 45 min'), findsOneWidget);
      expect(find.text('Lab'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Card layout remains robust under large accessibility text scale (1.8x)',
        (WidgetTester tester) async {
      final classEvent = {
        'id': 'test_4',
        'subject': 'Data Structures and Algorithms',
        'start_time': '09:00',
        'end_time': '11:00',
        'room': 'CS Lab 3',
        'faculty': 'Dr. Sharma',
        'ltp': 'Lab',
      };

      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              textScaler: TextScaler.linear(1.8),
            ),
            child: Scaffold(
              body: SingleChildScrollView(
                child: TimetableCard(
                  classEvent: classEvent,
                  status: 'Starts in 152 min',
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Starts in 152 min'), findsOneWidget);
      expect(tester.takeException(), isNull);

      final roomRect = tester.getRect(find.text('CS Lab 3'));
      final statusRect = tester.getRect(find.text('Starts in 152 min'));
      expect(statusRect.top, greaterThanOrEqualTo(roomRect.bottom));
    });

    testWidgets('All canonical statuses render correctly: Ongoing, Completed, Cancelled, Changed',
        (WidgetTester tester) async {
      final baseEvent = {
        'subject': 'Operating Systems',
        'start_time': '09:00',
        'end_time': '10:00',
        'room': '101',
      };

      for (final st in ['Ongoing', 'Completed', 'Cancelled', 'Changed', 'Scheduled']) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: TimetableCard(
                classEvent: baseEvent,
                status: st,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text(st), findsOneWidget);
      }
    });
  });

  group('SRUNIV Login Autofill & Security Semantics Tests', () {
    testWidgets('SruLoginScreen has AutofillGroup and standard AutofillHints',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SruLoginScreen(role: 'student'),
        ),
      );
      await tester.pumpAndSettle();

      // AutofillGroup must be present in the widget tree
      expect(find.byType(AutofillGroup), findsOneWidget);

      // Verify username text field has AutofillHints.username
      final idFieldFinder = find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.autofillHints != null &&
            widget.autofillHints!.contains(AutofillHints.username),
      );
      expect(idFieldFinder, findsOneWidget);

      // Verify password text field has AutofillHints.password and obscureText
      final passwordFieldFinder = find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.autofillHints != null &&
            widget.autofillHints!.contains(AutofillHints.password) &&
            widget.obscureText == true,
      );
      expect(passwordFieldFinder, findsOneWidget);
    });

    testWidgets('Password visibility toggle toggles obscureText',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SruLoginScreen(role: 'student'),
        ),
      );
      await tester.pumpAndSettle();

      // Tap visibility toggle icon button
      final toggleIconFinder = find.byIcon(Icons.visibility);
      expect(toggleIconFinder, findsOneWidget);

      await tester.tap(toggleIconFinder);
      await tester.pumpAndSettle();

      // Now icon should be visibility_off and obscureText false
      expect(find.byIcon(Icons.visibility_off), findsOneWidget);
      final visiblePasswordField = find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.autofillHints != null &&
            widget.autofillHints!.contains(AutofillHints.password) &&
            widget.obscureText == false,
      );
      expect(visiblePasswordField, findsOneWidget);
    });
  });
}
