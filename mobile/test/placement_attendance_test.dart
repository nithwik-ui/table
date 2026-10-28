import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mobile/core/constants.dart';
import 'package:mobile/core/storage.dart';
import 'package:mobile/core/sraap/sraap_parser.dart';
import 'package:mobile/core/sraap/models/sraap_academic_data.dart';
import 'package:mobile/features/academic/attendance_screen.dart';

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

  group('Placements Attendance Parser Tests', () {
    test('Parses summary KPI block format from std_training_atten_view.php', () {
      const html = '''
        <div class="row">
          <div class="col-md-3">
            <div class="small-box bg-info">
              <div class="inner">
                <p>Training Attendance</p>
                <h3>65.0%</h3>
              </div>
            </div>
          </div>
        </div>
      ''';
      final pct = SraapParser.parsePlacementAttendance(html);
      expect(pct, 65.0);
    });

    test('Parses table with explicit total row from std_training_atten_view.php', () {
      const html = '''
        <table class="table table-bordered">
          <thead>
            <tr>
              <th>S.No</th>
              <th>Training Program</th>
              <th>Total Cls</th>
              <th>Present Cls</th>
              <th>Attendance %</th>
            </tr>
          </thead>
          <tbody>
            <tr>
              <td>1</td>
              <td>Aptitude & Soft Skills</td>
              <td>20</td>
              <td>13</td>
              <td>65.0</td>
            </tr>
            <tr style="font-weight:bold">
              <td>Total</td>
              <td>Overall Training</td>
              <td>20</td>
              <td>13</td>
              <td>65.0</td>
            </tr>
          </tbody>
        </table>
      ''';
      final pct = SraapParser.parsePlacementAttendance(html);
      expect(pct, 65.0);
    });

    test('Parses multi-row training table and calculates aggregated percentage accurately', () {
      const html = '''
        <table class="table">
          <thead>
            <tr>
              <th>Training Course</th>
              <th>Held</th>
              <th>Present</th>
            </tr>
          </thead>
          <tbody>
            <tr>
              <td>Technical CRT</td>
              <td>30</td>
              <td>21</td>
            </tr>
            <tr>
              <td>Verbal & Logical</td>
              <td>20</td>
              <td>14</td>
            </tr>
          </tbody>
        </table>
      ''';
      // Total Held = 50, Total Present = 35 -> (35 / 50) * 100 = 70.0%
      final pct = SraapParser.parsePlacementAttendance(html);
      expect(pct, 70.0);
    });

    test('Parses contextual regex percentage fallback when minimal markup provided', () {
      const html = '<div class="alert">Overall Training Attendance: 78.5%</div>';
      final pct = SraapParser.parsePlacementAttendance(html);
      expect(pct, 78.5);
    });

    test('Returns null on login redirection or session expired HTML without fabricating 0%', () {
      const expiredHtml = '<script>window.location.href="../slogin.php";</script><h1>In Valid Login</h1>';
      final pct = SraapParser.parsePlacementAttendance(expiredHtml);
      expect(pct, isNull);
    });
  });

  group('StorageService Placement Attendance Cache Tests', () {
    test('Saves, retrieves, and clears placement attendance in local cache', () async {
      await StorageService.savePlacementAttendance(65.0);
      expect(StorageService.getPlacementAttendance(), 65.0);

      await StorageService.clearPlacementAttendance();
      expect(StorageService.getPlacementAttendance(), isNull);
    });
  });

  group('AttendanceScreen Placements UI & Info Card Tests', () {
    testWidgets('Renders Placements Attendance section and verifies footer card has NO arrow', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      // Seed mock academic and placement attendance cache inside real async zone for Hive disk I/O
      await tester.runAsync(() async {
        await StorageService.setSraapConnected(false);
        await StorageService.savePlacementAttendance(65.0);
        await StorageService.saveSraapAcademicCache(
          SraapAcademicData(
            overallAttendance: 82.0,
            placementAttendance: 65.0,
            subjects: [
              SraapSubjectAttendance(
                subjectName: 'Software Engineering',
                subjectCode: '24CS301',
                attendancePercentage: 85.0,
                presentCount: 17,
                totalCount: 20,
              ),
            ],
            lastSynced: DateTime.now(),
          ).toJson(),
        );
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: AttendanceScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // 1. Verify "Placements Attendance" section header is rendered
      expect(find.text('Placements Attendance'), findsWidgets);

      // 2. Verify placement percentage is prominently displayed
      expect(find.text('65%'), findsOneWidget);

      // 3. Verify footer info text is present
      expect(
        find.text(
          'Maintain at least 75% attendance in each subject to be eligible to appear for university exams.',
        ),
        findsOneWidget,
      );

      // 4. Verify Chevron / Right Arrow is REMOVED from the info card as strictly required
      final infoCardFinder = find.ancestor(
        of: find.text('Maintain at least 75% attendance in each subject to be eligible to appear for university exams.'),
        matching: find.byType(Container),
      );
      expect(
        find.descendant(of: infoCardFinder, matching: find.byIcon(Icons.chevron_right_rounded)),
        findsNothing,
      );
      expect(
        find.descendant(of: infoCardFinder, matching: find.byIcon(Icons.arrow_forward_ios_rounded)),
        findsNothing,
      );

      // Clean unmount
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });
  });
}
