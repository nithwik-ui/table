/// Distribution channel of the running application.
enum DistributionSource {
  googlePlay,
  directApk,
  web,
  unknown,
}

/// Release classification according to SRU Timetable policy.
enum AppUpdateClassification {
  none,
  normal,
  critical,
}

/// Update decision produced by the policy engine.
enum UpdateDecision {
  noUpdate,
  optionalFlexible,
  recommendedFlexible,
  requiredImmediate,
}

/// Pure Dart policy layer governing app update decisions.
///
/// Decoupled from platform channels, network layers, and UI state
/// to guarantee deterministic, isolated unit testability.
class AppUpdatePolicy {
  /// Evaluates update conditions and produces an [UpdateDecision].
  ///
  /// [updateAvailable]: whether an update is reported by the distribution channel.
  /// [priority]: Google Play in-app update priority (0 to 5).
  /// [stalenessDays]: days since the update was first known to Google Play.
  /// [flexibleAllowed]: whether flexible update is allowed by the Play API.
  /// [immediateAllowed]: whether immediate update is allowed by the Play API.
  /// [distributionSource]: where the app was installed from (Play, sideload APK, Web).
  static UpdateDecision evaluate({
    required bool updateAvailable,
    required int priority,
    int? stalenessDays,
    bool flexibleAllowed = true,
    bool immediateAllowed = true,
    DistributionSource distributionSource = DistributionSource.googlePlay,
  }) {
    if (!updateAvailable) {
      return UpdateDecision.noUpdate;
    }

    // Direct APK flow (sideloaded from GitHub)
    if (distributionSource == DistributionSource.directApk) {
      return UpdateDecision.optionalFlexible;
    }

    // Web/PWA flow
    if (distributionSource == DistributionSource.web) {
      return UpdateDecision.optionalFlexible;
    }

    // Google Play In-App Update Priority Model:
    // Priority 0: No special priority / no automatic in-app update prompt.
    // Priority 1: Minor update (treat as no automatic prompt unless manual).
    // Priority 2: Normal bug/UI update -> OPTIONAL_FLEXIBLE.
    // Priority 3: Important feature/performance update -> RECOMMENDED_FLEXIBLE.
    // Priority 4: Critical compatibility/security update -> REQUIRED_IMMEDIATE.
    // Priority 5: Emergency / broken-version update -> REQUIRED_IMMEDIATE.

    // If staleness is very high (> 14 days) on a priority 2 update, elevate to recommended
    final effectivePriority = (priority == 2 && stalenessDays != null && stalenessDays >= 14)
        ? 3
        : priority;

    if (effectivePriority <= 1) {
      return UpdateDecision.noUpdate;
    }

    if (effectivePriority == 2) {
      if (flexibleAllowed) {
        return UpdateDecision.optionalFlexible;
      }
      return UpdateDecision.noUpdate;
    }

    if (effectivePriority == 3) {
      if (flexibleAllowed) {
        return UpdateDecision.recommendedFlexible;
      }
      if (immediateAllowed) {
        return UpdateDecision.optionalFlexible;
      }
      return UpdateDecision.noUpdate;
    }

    // priority >= 4 (CRITICAL: 4 or 5)
    if (immediateAllowed) {
      return UpdateDecision.requiredImmediate;
    }

    // Fallback if immediate update is blocked by Play Core but flexible is allowed
    if (flexibleAllowed) {
      return UpdateDecision.recommendedFlexible;
    }

    return UpdateDecision.noUpdate;
  }

  /// Converts a priority integer (0-5) into its [AppUpdateClassification].
  static AppUpdateClassification classifyPriority(int priority) {
    if (priority <= 0) return AppUpdateClassification.none;
    if (priority >= 4) return AppUpdateClassification.critical;
    return AppUpdateClassification.normal;
  }

  /// Whether an update decision requires mandatory user interaction before proceeding.
  static bool isMandatory(UpdateDecision decision) {
    return decision == UpdateDecision.requiredImmediate;
  }
}
