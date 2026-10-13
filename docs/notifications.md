# Push Notifications & FCM — SRU Timetable 3.0

## 1. Principles
- **Non-Blocking**: FCM initialization must never prevent or delay timetable rendering.
- **Resilient Fallback**: If Firebase or network is unavailable, the application functions seamlessly in offline/cached mode.
- **Deterministic Notification IDs**: Class reminders use deterministic ID hashing based on subject, day, and start time to prevent duplicate alarms.
- **Holiday Awareness**: Reminders and push notifications are suppressed on dates with registered calendar holiday overrides.
