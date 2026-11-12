# ChronoLoge

ChronoLoge is a Flutter diary prototype that combines manual entries with an
automatic timeline built from location and weather context.

## Current features

- Today timeline and manual diary editing
- Calendar and list views for previous entries
- Image and voice-memo attachments with local file encryption
- SQLCipher-encrypted SQLite storage
- Background location, place, trip, and weather collection
- Firebase email/password and Google authentication
- Light/dark themes, accent colors, units, and news interests

## Structure

The app uses feature-based MVVM folders under `lib/features`. Shared database,
service, theme, and widget code lives under `lib/core`.

All diary content is stored locally in one encrypted `chronologe.db` database.
Media files are stored separately and encrypted before being written to disk.

## Run locally

```shell
flutter pub get
flutter run
```

The checked-in Firebase configuration targets the `chronologe-test` project
and the temporary `com.example.chronologe` Android/iOS identifier.
