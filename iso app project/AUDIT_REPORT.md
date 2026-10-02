# SRU Timetable Audit Report

## 1. Current Architecture
The application follows a standard feature-based architecture, separated into `lib/core` for centralized services and `lib/features` for domain-specific UI (academic, dashboard, notifications, onboarding). Dependencies are clearly separated, and business logic is mostly abstracted into singleton service classes like `StorageService`, `SyncService`, and `NotificationService`.

## 2. Current State Management
The app relies almost entirely on `StatefulWidget` and `setState` for state management. While this works for isolated components, it is currently being used to rebuild entire screens (e.g., `HomeTab`) on a timer. `SyncService` acts as a rudimentary global state using `ChangeNotifier` to notify listeners of sync status.

## 3. Current Navigation
Standard Flutter `Navigator` is used with `push`, `pushReplacement`, and `pushAndRemoveUntil`. The onboarding and timetable-change flow appropriately uses `pushAndRemoveUntil` to clear the stack when returning to the dashboard. However, there is a risk of duplicate instances when returning from external applications (like an AdMob browser) due to the Android activity `launchMode`.

## 4. Current Notification System
A robust combination of Firebase Cloud Messaging (FCM) and `flutter_local_notifications`. The `ReminderManager` enforces deterministic notification IDs (via a hash of the event details) which safely prevents duplicate reminders. Reminders are cleanly separated between student and faculty modes.

## 5. Current AdMob Implementation
The flutter implementation uses a tightly lifecycle-controlled `AdBanner` widget that ensures 1:1 ownership of `BannerAd` instances to prevent memory leaks and duplicate requests. However, there is a prominent Android lifecycle bug: returning from an external ad click often results in a blank screen or multiple tasks in Android Recents because the `MainActivity` is set to `launchMode="singleTop"` instead of `singleTask`.

## 6. Current Firebase Implementation
Firebase is initialized asynchronously to prevent blocking the initial UI render. It includes handlers for background messages and stale notification filtering. It's appropriately structured.

## 7. Current SRAAP Implementation
SRAAP login, session restoration, and CAPTCHA fetching are abstracted within `SraapSessionManager`. The implementation isolates the user's password and avoids logging sensitive HTML. Note: `sraap_test_screen.dart` forgets to dispose of its `TextEditingController`s, though `academic_login_screen.dart` correctly handles them.

## 8. Current Caching
Caching is implemented using Hive (`StorageService`). It rigorously maintains separation between Student data (timetable, overrides, changes) and Faculty data, ensuring no leakage between the two modes.

## 9. Current Widget Implementation
The Android Home Screen widget uses `home_widget` and is triggered to update passively (e.g., during periodic UI refreshes or app launch) without spinning up the entire Flutter engine unnecessarily.

## 10. Performance Bottlenecks
- **Severe memory leak & jank:** In `home_tab.dart` and `week_tab.dart`, `PageController(viewportFraction: 0.93)` is instantiated directly inside the `build()` method (inside `ListView.builder`). Every time the widget rebuilds, a new controller is created, leaking memory and resetting scroll state.
- **Excessive Rebuilds:** `LiveClassProgressIndicator` calls `setState` every 1 second, and `LiveFreeSlotProgressIndicator` every 15 seconds.
- **Full Page Rebuilds:** `HomeTab` has a `Timer.periodic` running every minute that calls `_updateFreshnessAndTimetable()`, which eventually calls `setState` on the entire page, recreating the heavy widget tree.

## 11. Crash Risks
- The `PageController` initialization inside `build()` can cause out-of-memory errors over prolonged app usage.
- `sraap_test_screen.dart` undisposed controllers.

## 12. Lifecycle Risks
- **AdMob Android Recents Bug:** As noted, tapping an ad and returning causes the app to either blank out or duplicate its task stack due to `launchMode="singleTop"` in `AndroidManifest.xml`. 
- `Timer.periodic` in `home_tab.dart` keeps running even if the user pushes another route on top of the dashboard (though `mounted` checks prevent crashes, it wastes CPU).

## 13. Recommended Fixes
1. **AdMob Recents Fix**: Change `launchMode="singleTop"` to `launchMode="singleTask"` in `AndroidManifest.xml`.
2. **PageController Fix**: Move the initialization of `PageController`s to `initState` and dispose of them in `dispose()` for both `home_tab.dart` and `week_tab.dart`.
3. **Timer Optimizations**: 
   - Optimize `LiveClassProgressIndicator` to only update if the calculated progress actually changed, or use an `AnimationController` instead of `Timer`.
   - Consider reducing the global `HomeTab` refresh to only rebuild specific localized components rather than the entire page.
4. **Disposal Fixes**: Add `dispose()` methods for `TextEditingController`s in `sraap_test_screen.dart`.
