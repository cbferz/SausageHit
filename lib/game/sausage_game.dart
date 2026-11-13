import 'dart:math' as math;
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:flutter/material.dart';
import 'level_data.dart';
import 'level_loader.dart';

enum RoundState { loading, aiming, flying, won, lost }

class SausageGame extends Forge2DGame<Forge2DWorld> {
  SausageGame() : super(gravity: Vector2(0, 9.8), zoom: 18);

  final LevelLoader _loader = LevelLoader();
  final ValueNotifier<RoundState> state = ValueNotifier(RoundState.loading);
  final ValueNotifier<int> levelNumber = ValueNotifier(1);
  final ValueNotifier<int> remainingSeconds = ValueNotifier(30);
  LevelData? level;
  SausageBody? sausage;
  TargetBody? target;
  double _elapsed = 0;
  double _aimX = 0;
  double _aimY = 0;
  bool _isAiming = false;
  final List<ObstacleBody> _obstacles = [];

  Future<void> loadLevel(int index) async {
    state.value = RoundState.loading;
    levelNumber.value = index + 1;
    level = await _loader.load(index);
    _elapsed = 0;
    _clearBodies();
    final data = level!;
    world.add(GroundBody());
    sausage = SausageBody(
      position: Vector2(data.launchX, data.launchY),
      onHitTarget: _win,
    );
    target = TargetBody(
      position: Vector2(data.targetX, data.targetY),
      onHit: _win,
    );
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
    sausage?.removeFromParent();
    target?.removeFromParent();
    for (final obstacle in _obstacles) {
      obstacle.removeFromParent();
    }
    _obstacles.clear();
    children.whereType<GroundBody>().forEach((body) => body.removeFromParent());
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
    final delta = origin - worldPoint;
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
    final data = level!;
    final scale = math.min(size.width / 24, size.height / 13.5);
    final originX = size.width / 2 - (data.launchX + 2.5) * scale;
    final originY = size.height / 2 - 4.0 * scale;
    return Vector2((point.dx - originX) / scale, (point.dy - originY) / scale);
  }

  void _win() {
    if (state.value == RoundState.flying) state.value = RoundState.won;
  }

  void restart() {
    final index = (levelNumber.value - 1).clamp(0, LevelLoader.levelCount - 1);
    loadLevel(index);
  }

  void nextLevel() {
    final next = levelNumber.value;
    if (next >= LevelLoader.levelCount) {
      loadLevel(0);
    } else {
      loadLevel(next);
    }
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    await loadLevel(0);
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (state.value == RoundState.flying) {
      _elapsed += dt;
      final remaining = (level!.timeLimitSeconds - _elapsed).ceil();
      remainingSeconds.value = remaining.clamp(0, level!.timeLimitSeconds);
      final body = sausage?.body;
      if (body != null &&
          (body.position.x > 24 ||
              body.position.x < -4 ||
              body.position.y > 16 ||
              _elapsed >= level!.timeLimitSeconds)) {
        state.value = RoundState.lost;
      }
    }
  }

  @override
  void render(Canvas canvas) {
    canvas.drawColor(const Color(0xFF202631), BlendMode.src);
    super.render(canvas);
  }
}

class SausageBody extends BodyComponent with ContactCallbacks {
  SausageBody({required Vector2 position, required this.onHitTarget})
      : super(
          bodyDef: BodyDef(
            type: BodyType.dynamic,
            position: position,
            angularDamping: 0.25,
            linearDamping: 0.04,
            bullet: true,
          ),
          shapeSpecs: [
            ShapeSpec(
              Capsule(Vector2(-0.55, 0), Vector2(0.55, 0), 0.28),
              ShapeDef(
                density: 1.3,
                material: SurfaceMaterial(friction: 0.55, restitution: 0.28),
                enableContactEvents: true,
              ),
            ),
          ],
        );

  final VoidCallback onHitTarget;
  bool _launched = false;

  void launch(Vector2 impulse) {
    if (_launched) return;
    _launched = true;
    body.applyLinearImpulse(impulse);
  }

  @override
  void beginContact(Object other, Contact contact) {
    if (other is TargetBody) onHitTarget();
  }
}

class TargetBody extends BodyComponent {
  TargetBody({required Vector2 position, required this.onHit})
      : super(
          bodyDef: BodyDef(type: BodyType.static, position: position),
          shapeSpecs: [
            ShapeSpec(
              Circle(radius: 0.72),
              ShapeDef(isSensor: true, enableSensorEvents: true),
            ),
          ],
        );

  final VoidCallback onHit;
}

class GroundBody extends BodyComponent {
  @override
  Body createBody() {
    final body = world.createBody(BodyDef(type: BodyType.static));
    body.createShape(
      Segment(point1: Vector2(-5, 8.2), point2: Vector2(26, 8.2)),
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
              Polygon(box: Vector2(width / 2, height / 2)),
              ShapeDef(
                material: SurfaceMaterial(friction: 0.65, restitution: 0.08),
              ),
            ),
          ],
        );
}
