# ChronoLoge code guide

ChronoLoge uses MVVM. In simple terms:

1. A **view** draws a page and forwards button presses.
2. A **view model** holds the page state and performs the work.
3. A **database/service** talks to SQLite, Firebase, location, weather, or files.
4. Riverpod providers give those objects to the parts of the app that need them.

## Main folders

- `lib/core/database`: SQLCipher tables and database queries.
- `lib/core/services`: location, weather, and media encryption.
- `lib/core/widgets`: small reusable UI pieces.
- `lib/core/utils`: simple shared helper functions.
- `lib/features`: one folder for each app feature.

## Important data flow

### Opening the app

`main.dart` starts Firebase, creates Riverpod, and shows `AuthenticationGate`.
The gate shows the sign-in page when there is no Firebase user. Otherwise it
shows `AppShell`, which contains the bottom navigation bar.

### Saving a manual diary entry

The page sends title, text, mood, and selected media to its view model. The
view model encrypts copied media files and asks `DiaryDatabase` to save their
paths. SQLCipher encrypts the SQLite database itself.

### Building the automatic timeline

`BackgroundLocationService` receives location updates. It recognizes visits,
trips, and weather changes, then writes timeline events through
`DiaryDatabase`. Timeline events point to persistent location/weather
snapshots instead of copying those details into every event.

### Media ownership

Every file has one row in `diary_media`:

- `timeline_item_id` is empty for Summary-tab media.
- `timeline_item_id` points to an event for Timeline-tab media.
- `media_type` is plain text, so video or other types can be added later.

## Safe editing rules

- Put UI layout in a view.
- Put button logic and page state in a view model.
- Put SQL only in a database class.
- Put reusable UI in `core/widgets`.
- Put reusable formatting in `core/utils`.
- Never read an encrypted media file directly; use `MediaEncryptionService`.
- Run `flutter analyze` after changes.
