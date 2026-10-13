import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/foundation.dart';

class AppDataMigrationManager {
  static const String _migrationFlagKey = 'v3_migration_complete';
  static const int schemaVersion = 3;

  static Future<void> runMigrationIfNeeded() async {
    final v3PrefsBox = Hive.box('sru_timetable_v3_prefs');
    
    final bool isMigrationComplete = v3PrefsBox.get(_migrationFlagKey, defaultValue: false) as bool;
    if (isMigrationComplete) return;

    debugPrint('[Migration] Running 2.0 -> 3.0 Clean Reset Migration');

    try {
      final hasLegacyPrefs = await Hive.boxExists('sru_timetable_prefs');
      if (hasLegacyPrefs) {
        debugPrint('[Migration] Detected legacy 2.0 installation. Archiving old session state.');
        final legacyBox = await Hive.openBox('sru_timetable_prefs');
        
        // Salvage non-sensitive display preferences if they exist
        final legacyName = legacyBox.get('user_name') as String?;
        if (legacyName != null && legacyName.isNotEmpty) {
          await v3PrefsBox.put('user_name', legacyName);
        }

        final legacyMode = legacyBox.get('user_mode') as String?;
        if (legacyMode != null && legacyMode.isNotEmpty) {
          await v3PrefsBox.put('user_mode', legacyMode);
        }

        // Close legacy box without carrying forward broken session or auth cookies
        await legacyBox.close();
      }
    } catch (e) {
      debugPrint('[Migration] Non-fatal legacy detection error: $e');
    }

    // Mark 3.0 initialization complete
    await v3PrefsBox.put('app_schema_version', schemaVersion);
    await v3PrefsBox.put(_migrationFlagKey, true);
    debugPrint('[Migration] 3.0 Migration Completed. Data namespace: sru_timetable_v3');
  }
}

