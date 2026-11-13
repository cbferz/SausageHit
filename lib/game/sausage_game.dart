import 'dart:math' as math;
import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:flutter/material.dart';
import 'level_data.dart';
import 'level_loader.dart';

enum RoundState { loading, aiming, flying, won, lost }

class SausageGame extends Forge2DGame<Forge2DWorld> {
  SausageGame() : super(gravity: Vector2(0, 9.8), zoom: 50);

  final LevelLoader _loader = LevelLoader();
  final ValueNotifier<RoundState> state = ValueNotifier(RoundState.loading);
  final ValueNotifier<int> levelNumber = ValueNotifier(1);
  final ValueNotifier<int> remainingSeconds = ValueNotifier(30);
  LevelData? level;
  SausageBody? sausage;
  TargetBody? target;
  GroundBody? _ground;
  double _elapsed = 0;
  double _aimX = 0;
  double _aimY = 0;
  double _contactElapsed = 0;
  bool _isAiming = false;
  bool _touchingTarget = false;
  final List<ObstacleBody> _obstacles = [];

  Offset get aimDelta => Offset(_aimX, _aimY);
  bool get isAiming => _isAiming;

  Future<void> loadLevel(int index) async {
    state.value = RoundState.loading;
    levelNumber.value = index + 1;
    level = await _loader.load(index);
    _elapsed = 0;
    _contactElapsed = 0;
    _touchingTarget = false;
    _aimX = 0;
    _aimY = 0;
    _clearBodies();
    final data = level!;
    _ground = GroundBody();
    world.add(_ground!);
    sausage = SausageBody(
      initialPosition: Vector2(data.launchX, data.launchY),
      onTargetContact: () => _touchingTarget = true,
      onTargetLeave: () => _touchingTarget = false,
    );
    target = TargetBody(initialPosition: Vector2(data.targetX, data.targetY));
    world.add(sausage!);
    world.add(target!);
    for (final obstacle in data.obstacles) {
      final body = ObstacleBody(
        x: obstacle.x,
        y: obstacle.y,
        width: obstacle.width,
        height: obstacle.height,
      );
      _obstacles.add(body);
      world.add(body);
    }
    remainingSeconds.value = data.timeLimitSeconds;
    state.value = RoundState.aiming;
  }

  void _clearBodies() {
    _ground?.removeFromParent();
    _ground = null;
    sausage?.removeFromParent();
    target?.removeFromParent();
    for (final obstacle in _obstacles) {
      obstacle.removeFromParent();
    }
    _obstacles.clear();
    sausage = null;
    target = null;
  }

  void beginAim(Offset local, Size size) {
    if (state.value != RoundState.aiming || sausage == null) return;
    _isAiming = true;
    updateAim(local, size);
  }

  void updateAim(Offset local, Size size) {
    if (!_isAiming || level == null) return;
    final worldPoint = _screenToWorld(local, size);
    final origin = Vector2(level!.launchX, level!.launchY);
    final delta = Vector2(origin.x - worldPoint.x, worldPoint.y - origin.y);
    final maxPull = level!.maxPull;
    final length = delta.length;
    if (length > maxPull) delta.scale(maxPull / length);
    _aimX = delta.x;
    _aimY = delta.y;
  }

  void releaseAim() {
    if (!_isAiming || state.value != RoundState.aiming || sausage == null) return;
    _isAiming = false;
    final pull = Vector2(_aimX, _aimY);
    if (pull.length < 0.18) return;
    sausage!.launch(pull * 7.2);
    state.value = RoundState.flying;
  }

  Vector2 _screenToWorld(Offset point, Size size) {
    final scale = math.min(size.width / 24, size.height / 13.5);
    return Vector2(
      (point.dx - size.width / 2) / scale + 12,
      (point.dy - size.height / 2) / scale + 6.75,
    );
  }

  void restart() {
    final index = (levelNumber.value - 1).clamp(0, LevelLoader.levelCount - 1);
    loadLevel(index);
  }

  void nextLevel() {
    final next = levelNumber.value;
    loadLevel(next >= LevelLoader.levelCount ? 0 : next);
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    camera.viewfinder.position = Vector2(12, 6.75);
    await loadLevel(0);
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (state.value == RoundState.flying) {
      _elapsed += dt;
      if (_touchingTarget) {
        _contactElapsed += dt;
        if (_contactElapsed >= 0.5) state.value = RoundState.won;
      } else {
        _contactElapsed = 0;
      }
      final remaining = (level!.timeLimitSeconds - _elapsed).ceil();
      remainingSeconds.value = remaining.clamp(0, level!.timeLimitSeconds);
      final body = sausage?.body;
      if (body != null &&
          (body.position.x > 28 ||
              body.position.x < -4 ||
              body.position.y > 16 ||
              _elapsed >= level!.timeLimitSeconds)) {
        state.value = RoundState.lost;
      }
    }
  }
}

class SausageBody extends BodyComponent with ContactCallbacks {
  SausageBody({
    required this.initialPosition,
    required this.onTargetContact,
    required this.onTargetLeave,
  });

  final Vector2 initialPosition;
  final VoidCallback onTargetContact;
  final VoidCallback onTargetLeave;
  bool _launched = false;

  @override
  Body createBody() {
    final body = world.createBody(BodyDef(
      type: BodyType.dynamic,
      position: initialPosition,
      angularDamping: 0.25,
      linearDamping: 0.04,
      isBullet: true,
      userData: this,
    ));
    body.createShape(
      Capsule(
        center1: Vector2(-0.55, 0),
        center2: Vector2(0.55, 0),
        radius: 0.28,
      ),
      ShapeDef(
        density: 1.3,
        material: SurfaceMaterial(friction: 0.55, restitution: 0.28),
        enableContactEvents: true,
      ),
    );
    return body;
  }

  void launch(Vector2 impulse) {
    if (_launched) return;
    _launched = true;
    body.applyLinearImpulse(impulse);
  }

  @override
  void beginContact(Object other, Contact contact) {
    if (other is TargetBody) onTargetContact();
  }

  @override
  void endContact(Object other, Contact contact) {
    if (other is TargetBody) onTargetLeave();
  }
}

class TargetBody extends BodyComponent {
  TargetBody({required this.initialPosition});

  final Vector2 initialPosition;

  @override
  Body createBody() {
    final body = world.createBody(
      BodyDef(type: BodyType.static, position: initialPosition, userData: this),
    );
    body.createShape(
      Circle(radius: 0.72),
      ShapeDef(
        material: SurfaceMaterial(friction: 0.4, restitution: 0.15),
        enableContactEvents: true,
      ),
    );
    return body;
  }
}

class GroundBody extends BodyComponent {
  @override
  Body createBody() {
    final body = world.createBody(BodyDef(type: BodyType.static));
    body.createShape(
      Segment(point1: Vector2(-5, 8.2), point2: Vector2(29, 8.2)),
      ShapeDef(material: SurfaceMaterial(friction: 0.8)),
    );
    return body;
  }
}

class ObstacleBody extends BodyComponent {
  ObstacleBody({
    required double x,
    required double y,
    required double width,
    required double height,
  }) : super(
          bodyDef: BodyDef(
            type: BodyType.static,
            position: Vector2(x, y),
          ),
          shapeSpecs: [
            ShapeSpec(
              Polygon.box(width / 2, height / 2),
              ShapeDef(
                material: SurfaceMaterial(friction: 0.65, restitution: 0.08),
              ),
            ),
          ],
        );
}
