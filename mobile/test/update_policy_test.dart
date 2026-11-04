import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/update/app_update_policy.dart';
import 'package:mobile/core/update/direct_apk_update_service.dart';
import 'package:mobile/core/update/update_service.dart';
import 'package:mobile/widgets/update_dialog.dart';

void main() {
  group('AppUpdatePolicy Decision Engine Tests', () {
    test('No update available returns noUpdate regardless of priority', () {
      for (int p = 0; p <= 5; p++) {
        final decision = AppUpdatePolicy.evaluate(
          updateAvailable: false,
          priority: p,
          flexibleAllowed: true,
          immediateAllowed: true,
        );
        expect(decision, UpdateDecision.noUpdate);
      }
    });

    test('Priority 0 returns noUpdate automatically', () {
      final decision = AppUpdatePolicy.evaluate(
        updateAvailable: true,
        priority: 0,
        flexibleAllowed: true,
        immediateAllowed: true,
      );
      expect(decision, UpdateDecision.noUpdate);
    });

    test('Priority 1 (minor) returns noUpdate automatically', () {
      final decision = AppUpdatePolicy.evaluate(
        updateAvailable: true,
        priority: 1,
        flexibleAllowed: true,
        immediateAllowed: true,
      );
      expect(decision, UpdateDecision.noUpdate);
    });

    test('Priority 2 (normal bug/UI update) returns optionalFlexible when flexible is allowed', () {
      final decision = AppUpdatePolicy.evaluate(
        updateAvailable: true,
        priority: 2,
        flexibleAllowed: true,
        immediateAllowed: true,
      );
      expect(decision, UpdateDecision.optionalFlexible);
    });

    test('Priority 2 returns noUpdate if flexible update is not allowed by Play Core', () {
      final decision = AppUpdatePolicy.evaluate(
        updateAvailable: true,
        priority: 2,
        flexibleAllowed: false,
        immediateAllowed: true,
      );
      expect(decision, UpdateDecision.noUpdate);
    });

    test('Priority 2 with staleness >= 14 days elevates to recommendedFlexible', () {
      final decision = AppUpdatePolicy.evaluate(
        updateAvailable: true,
        priority: 2,
        stalenessDays: 15,
        flexibleAllowed: true,
        immediateAllowed: true,
      );
      expect(decision, UpdateDecision.recommendedFlexible);
    });

    test('Priority 3 (important feature update) returns recommendedFlexible when flexible is allowed', () {
      final decision = AppUpdatePolicy.evaluate(
        updateAvailable: true,
        priority: 3,
        flexibleAllowed: true,
        immediateAllowed: true,
      );
      expect(decision, UpdateDecision.recommendedFlexible);
    });

    test('Priority 3 falls back to optionalFlexible if flexible update not allowed but immediate is', () {
      final decision = AppUpdatePolicy.evaluate(
        updateAvailable: true,
        priority: 3,
        flexibleAllowed: false,
        immediateAllowed: true,
      );
      expect(decision, UpdateDecision.optionalFlexible);
    });

    test('Priority 4 (critical compatibility/security) returns requiredImmediate when allowed', () {
      final decision = AppUpdatePolicy.evaluate(
        updateAvailable: true,
        priority: 4,
        flexibleAllowed: true,
        immediateAllowed: true,
      );
      expect(decision, UpdateDecision.requiredImmediate);
    });

    test('Priority 5 (emergency broken-version) returns requiredImmediate when allowed', () {
      final decision = AppUpdatePolicy.evaluate(
        updateAvailable: true,
        priority: 5,
        flexibleAllowed: true,
        immediateAllowed: true,
      );
      expect(decision, UpdateDecision.requiredImmediate);
    });

    test('Critical update (priority 4 or 5) falls back to recommendedFlexible if immediate not allowed', () {
      final decision = AppUpdatePolicy.evaluate(
        updateAvailable: true,
        priority: 5,
        flexibleAllowed: true,
        immediateAllowed: false,
      );
      expect(decision, UpdateDecision.recommendedFlexible);
    });

    test('Critical update returns noUpdate if neither immediate nor flexible allowed', () {
      final decision = AppUpdatePolicy.evaluate(
        updateAvailable: true,
        priority: 5,
        flexibleAllowed: false,
        immediateAllowed: false,
      );
      expect(decision, UpdateDecision.noUpdate);
    });

    test('Direct APK installation returns optionalFlexible or recommendedFlexible when update is available', () {
      final decision = AppUpdatePolicy.evaluate(
        updateAvailable: true,
        priority: 0,
        distributionSource: DistributionSource.directApk,
      );
      expect(decision, UpdateDecision.optionalFlexible);
    });

    test('Web/PWA installation returns optionalFlexible when update is available', () {
      final decision = AppUpdatePolicy.evaluate(
        updateAvailable: true,
        priority: 0,
        distributionSource: DistributionSource.web,
      );
      expect(decision, UpdateDecision.optionalFlexible);
    });
  });

  group('AppUpdateClassification & Mandatory Checks', () {
    test('Correctly classifies priority levels', () {
      expect(AppUpdatePolicy.classifyPriority(0), AppUpdateClassification.none);
      expect(AppUpdatePolicy.classifyPriority(1), AppUpdateClassification.normal);
      expect(AppUpdatePolicy.classifyPriority(2), AppUpdateClassification.normal);
      expect(AppUpdatePolicy.classifyPriority(3), AppUpdateClassification.normal);
      expect(AppUpdatePolicy.classifyPriority(4), AppUpdateClassification.critical);
      expect(AppUpdatePolicy.classifyPriority(5), AppUpdateClassification.critical);
    });

    test('isMandatory only flags requiredImmediate', () {
      expect(AppUpdatePolicy.isMandatory(UpdateDecision.noUpdate), isFalse);
      expect(AppUpdatePolicy.isMandatory(UpdateDecision.optionalFlexible), isFalse);
      expect(AppUpdatePolicy.isMandatory(UpdateDecision.recommendedFlexible), isFalse);
      expect(AppUpdatePolicy.isMandatory(UpdateDecision.requiredImmediate), isTrue);
    });
  });

  group('Semantic Version Comparison & 3.1.4 Update Evaluation Tests', () {
    test('3.1.2 -> 3.1.4 triggers update (recommended)', () {
      expect(DirectApkUpdateService.compareSemanticVersions('3.1.2', '3.1.4'), lessThan(0));
      expect(DirectApkUpdateService.isNewerVersion('3.1.2', '3.1.4'), isTrue);
      expect(DirectApkUpdateService.isNewerVersion('3.1.2', 'v3.1.4'), isTrue);
    });

    test('3.1.4 -> 3.1.4 triggers NO update', () {
      expect(DirectApkUpdateService.compareSemanticVersions('3.1.4', '3.1.4'), equals(0));
      expect(DirectApkUpdateService.isNewerVersion('3.1.4', '3.1.4'), isFalse);
      expect(DirectApkUpdateService.isNewerVersion('3.1.4', 'v3.1.4'), isFalse);
    });

    test('3.1.5 -> 3.1.4 triggers NO update', () {
      expect(DirectApkUpdateService.compareSemanticVersions('3.1.5', '3.1.4'), greaterThan(0));
      expect(DirectApkUpdateService.isNewerVersion('3.1.5', '3.1.4'), isFalse);
      expect(DirectApkUpdateService.isNewerVersion('3.1.5', 'v3.1.4'), isFalse);
    });

    test('Handles build codes and v prefixes properly', () {
      expect(DirectApkUpdateService.isNewerVersion('3.1.2+33', '3.1.4+35'), isTrue);
      expect(DirectApkUpdateService.isNewerVersion('3.1.4+35', '3.1.4+35'), isFalse);
      expect(DirectApkUpdateService.isNewerVersion('3.1.4+35', 'v3.1.4'), isFalse);
      expect(DirectApkUpdateService.isNewerVersion('v3.1.2', '3.1.4'), isTrue);
    });
  });

  group('Session Dismissal & Non-Intrusive State Tests', () {
    setUp(() {
      UpdateService.resetDismissedState();
    });

    test('dismissedThisSession is false initially', () {
      expect(UpdateService.dismissedThisSession, isFalse);
    });

    test('Setting dismissedThisSession persists across checks until reset', () {
      UpdateService.dismissedThisSession = true;
      expect(UpdateService.dismissedThisSession, isTrue);

      UpdateService.resetDismissedState();
      expect(UpdateService.dismissedThisSession, isFalse);
    });
  });

  group('UpdateDialog UX Widget Tests', () {
    testWidgets('Renders recommended update dialog with required 3.1.4 text and actions', (tester) async {
      bool updateClicked = false;
      bool laterClicked = false;

      UpdateService.resetDismissedState();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => UpdateDialog(
                      latestTag: '3.1.4',
                      downloadUrl: 'https://example.com/app.apk',
                      onUpdateNow: () {
                        updateClicked = true;
                        Navigator.of(ctx).pop();
                      },
                      onLater: () {
                        laterClicked = true;
                        Navigator.of(ctx).pop();
                      },
                    ),
                  );
                },
                child: const Text('Show Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('New update available'), findsOneWidget);
      expect(find.text('SRU Timetable 3.1.4'), findsOneWidget);
      expect(
        find.text(
          'SRU Timetable 3.1.4 includes important stability, timetable, dark mode, notification, performance and user experience improvements.',
        ),
        findsOneWidget,
      );

      expect(find.text('Later'), findsOneWidget);
      expect(find.text('Update Now'), findsOneWidget);

      await tester.tap(find.text('Later'));
      await tester.pumpAndSettle();

      expect(laterClicked, isTrue);
      expect(UpdateService.dismissedThisSession, isTrue);
      expect(find.text('New update available'), findsNothing);

      UpdateService.resetDismissedState();
      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Update Now'));
      await tester.pumpAndSettle();

      expect(updateClicked, isTrue);
      expect(find.text('New update available'), findsNothing);
    });
  });

  group('UnifiedUpdateResult Helper Tests', () {
    test('isCriticalImmediate is true only for requiredImmediate', () {
      const immediateResult = UnifiedUpdateResult(
        source: DistributionSource.googlePlay,
        updateAvailable: true,
        decision: UpdateDecision.requiredImmediate,
      );
      expect(immediateResult.isCriticalImmediate, isTrue);
      expect(immediateResult.isFlexibleAvailable, isFalse);

      const flexibleResult = UnifiedUpdateResult(
        source: DistributionSource.googlePlay,
        updateAvailable: true,
        decision: UpdateDecision.optionalFlexible,
      );
      expect(flexibleResult.isCriticalImmediate, isFalse);
      expect(flexibleResult.isFlexibleAvailable, isTrue);

      const recommendedResult = UnifiedUpdateResult(
        source: DistributionSource.googlePlay,
        updateAvailable: true,
        decision: UpdateDecision.recommendedFlexible,
      );
      expect(recommendedResult.isCriticalImmediate, isFalse);
      expect(recommendedResult.isFlexibleAvailable, isTrue);
    });
  });
}
