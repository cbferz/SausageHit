# SausageHit

A landscape arcade physics game made with Flutter, Flame and Forge2D.

## Gameplay

- Pull back from the sausage on the frying pan, then release to launch it.
- Reach the glowing target while avoiding kitchen obstacles.
- Each level has its own layout, pull strength and time limit.
- The campaign currently contains 8 levels.
- Touching the target continuously for 0.5 seconds wins the level.

## Controls

1. Touch and drag from the sausage backwards to aim.
2. Watch the dotted trajectory preview.
3. Release to launch.
4. Tap Retry or Next Level after the round ends.

## Build

```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
```

## Art and licensing

The visible kitchen, frying pan, sausage, targets and props are drawn as vector shapes in the game, so the APK does not depend on network downloads at runtime. The food/kitchen visual direction can be extended with Kenney's **Food Kit**, which is published under CC0 on its asset page:

- https://kenney.nl/assets/food-kit
- https://kenney.nl/support

The current in-game vector artwork is original project code. The level layouts are authored for this project and stored locally as JSON; they are not downloaded from a server.

## CI

GitHub Actions runs Flutter analysis and tests, builds a debug APK, and uploads the APK as the `sausagehit-debug-apk` artifact for 7 days.
