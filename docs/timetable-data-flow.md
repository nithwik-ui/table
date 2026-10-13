# Timetable Data Flow — SRU Timetable 3.0

## 1. Flow Diagram

```
App Open / Resume
       │
       ▼
Local Hive Storage (v3 Namespace)
       │
       ├─────────────────────────────────┐
       ▼                                 ▼
Render UI immediately (< 100ms)    Start Background Sync
       │                                 │
       ▼                                 ▼
User interacts with schedule       Check Remote Source
                                         │
                         ┌───────────────┴───────────────┐
                         ▼                               ▼
                      Success                         Failure
                         │                               │
                 Atomically update               Retain existing
                 Hive & notify UI                data + set isStale=true
```

## 2. Shared Tab State
`TimetableRepository` acts as the single source of truth:
- `HomeTab`: Consumes `todayClasses`, `upNextClass`, and `dailyStatus`.
- `WeekTab`: Consumes `weekSchedule` grouped by day.
- `ChangesTab`: Consumes detected schedule diffs.
- `AcademicTab`: Consumes attendance & grade records.

No tab initiates a network fetch merely by being selected or brought to the foreground.
