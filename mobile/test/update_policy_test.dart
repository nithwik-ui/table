import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/update/app_update_policy.dart';
import 'package:mobile/core/update/direct_apk_update_service.dart';
import 'package:mobile/core/update/update_service.dart';

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

    test('Direct APK installation returns optionalFlexible when update is available', () {
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

  group('DirectApkUpdateService Version Semantics Tests', () {
    test('isNewerVersion correctly evaluates semantic version tags', () {
      expect(DirectApkUpdateService.isNewerVersion('3.0.0', 'v3.0.1'), isTrue);
      expect(DirectApkUpdateService.isNewerVersion('3.0.1', 'v3.0.1'), isFalse);
      expect(DirectApkUpdateService.isNewerVersion('3.0.2', 'v3.0.1'), isFalse);
      expect(DirectApkUpdateService.isNewerVersion('3.0.0', '3.1.0'), isTrue);
      expect(DirectApkUpdateService.isNewerVersion('2.9.9', '3.0.0'), isTrue);
      expect(DirectApkUpdateService.isNewerVersion('3.0.0+30', '3.0.1+31'), isTrue);
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
