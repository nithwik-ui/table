# Caching & Local Persistence — SRU Timetable 3.0

## 1. Storage Architecture
- **Engine**: Hive (`hive_flutter`).
- **Namespace Separation**:
  - Preferences Box: `sru_timetable_v3_prefs`
  - Cache Box: `sru_timetable_v3_cache`
- **Legacy Migration Isolation**:
  - Legacy 2.0 boxes (`sru_timetable_prefs`, `sru_timetable_cache`) are read once during migration detection to salvage non-sensitive user profile/mode configurations if desired, but never mixed directly with 3.0 storage.

## 2. Timetable Cache Schema
```json
{
  "classes": [
    {
      "id": "course-101",
      "subject": "Distributed Systems",
      "faculty": "Dr. Rao",
      "room": "Block 2 - Room 304",
      "day": "monday",
      "start_time": "09:30",
      "end_time": "10:30",
      "isCancelled": false
    }
  ],
  "metadata": {
    "lastSyncedAt": "2026-10-12T04:30:00Z",
    "version": 3,
    "source": "backend_cache",
    "isStale": false
  }
}
```

## 3. Freshness & Stale Fallbacks
- Fresh: `< 6 hours` old.
- Stale: `>= 6 hours` old or remote sync failed.
- Offline: Remote unreachable.
In all cases, cached classes are fully interactive and searchable.
