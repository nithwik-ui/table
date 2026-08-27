# SRU Timetable

A cross-platform Flutter mobile application and Node/TypeScript backend to sync and notify students about SR University timetable changes.

## Stack
- **Mobile**: Flutter (Android + iOS) with Hive for offline caching.
- **Backend**: Node/TypeScript on Express, deployed to Render.
- **Database**: Supabase (PostgreSQL) with Row-Level Security (RLS).
- **Notifications**: Firebase Cloud Messaging (FCM).

## Project Structure
- `backend/`: TypeScript backend service + database sync worker.
- `mobile/`: Flutter client application.
- `docs/`: Product requirements, app flow diagrams, and design specifications.

## Setup Instructions

### Backend
1. Go to `backend/`.
2. Install dependencies: `npm install`.
3. Create a `.env` file from `.env.example` and fill in credentials.
4. Run locally: `npm run dev`.

### Mobile
1. Go to `mobile/`.
2. Run `flutter pub get`.
3. Launch on a connected device/emulator: `flutter run`.
