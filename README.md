# SausageHit

A landscape Android arcade MVP built with **Flutter**, **Flame** and **Forge2D**. Pull back from the frying pan, release the sausage, and try to reach the target.

## Gameplay

- Side-view physics with gravity, rigid-body collisions and a capsule-shaped sausage.
- Drag backwards to set launch direction and power; release to launch.
- Three JSON-driven levels with increasing obstacle layouts.
- A target hit must remain in contact for 0.5 seconds to count as a win.
- Falling out of bounds or reaching the level timer is a loss.
- Retry and next-level actions are available after each round.

## Requirements

- Flutter stable (Dart 3.12+)
- Java 17 for Android builds

## Run locally

```bash
flutter pub get
flutter run
```

For Android, the app is locked to landscape orientation. The Android Gradle scaffold is generated in CI using the installed stable Flutter SDK.

## Tests and analysis

```bash
flutter analyze
flutter test
```

## Build APK

```bash
flutter build apk --debug
```

The GitHub Actions workflow runs on pushes to `main` and manual dispatch. It generates Android platform files, runs analysis and tests, builds a debug APK, and uploads `app-debug.apk` as the `sausagehit-debug-apk` artifact for 7 days.

## Levels

Level definitions are stored in `assets/levels/level_1.json` through `level_3.json`. The typed model and loader live in `lib/game/level_data.dart` and `lib/game/level_loader.dart`.
