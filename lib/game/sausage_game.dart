import 'dart:math' as math;
import 'package:flame/components.dart';
import 'package:flame_forge2d/flame_forge2d.dart';
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'level_data.dart';
import 'level_loader.dart';

enum RoundState { loading, aiming, flying, won, lost }

class SausageGame extends Forge2DGame<Forge2DWorld> {
  SausageGame() : super(gravity: Vector2(0, 9.8));

  final LevelLoader _loader = LevelLoader();
  final ValueNotifier<RoundState> state = ValueNotifier(RoundState.loading);
  final ValueNotifier<int> levelNumber = ValueNotifier(1);
  final ValueNotifier<int> remainingSeconds = ValueNotifier(30);
  late final SausageScene _scene = SausageScene(this);
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

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    if (size.x > 0 && size.y > 0) {
      // Forge2D already converts metres to 50 px. Zoom must be a ratio,
      // not another 50x multiplier, otherwise the camera sees only a tiny patch.
      camera.viewfinder.zoom = math.min(size.x / 24, size.y / 13.5) / 50;
    }
  }

  Future<void> loadLevel(int index) async {
    state.value = RoundState.loading;
    levelNumber.value = index + 1;
    level = await _loader.load(index);
    _elapsed = 0;
    _contactElapsed = 0;
    _touchingTarget = false;
    _aimX = 0;
    _aimY = 0;
    _isAiming = false;
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
    world.add(_scene);
    await loadLevel(0);
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (state.value == RoundState.flying && level != null) {
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
          (body.position.x > 32 ||
              body.position.x < -5 ||
              body.position.y > 16 ||
              _elapsed >= level!.timeLimitSeconds)) {
        state.value = RoundState.lost;
      }
    }
  }
}

class SausageScene extends Component {
  SausageScene(this.game) {
    priority = -100;
  }

  final SausageGame game;

  final Paint _wallPaint = Paint()
    ..shader = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFF25364A), Color(0xFF3D5267), Color(0xFF725C4B)],
    ).createShader(const Rect.fromLTWH(-4, -3, 34, 14));
  final Paint _tileLine = Paint()
    ..color = const Color(0x337EE1E8)
    ..strokeWidth = 0.035;
  final Paint _floorPaint = Paint()..color = const Color(0xFF59402F);
  final Paint _floorEdgePaint = Paint()..color = const Color(0xFFFFB45C);

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    canvas.drawRect(const Rect.fromLTWH(-4, -3, 34, 14), _wallPaint);

    // Tiled kitchen wall and warm ceiling lights.
    for (var x = -3.0; x < 29; x += 2) {
      canvas.drawLine(Offset(x, -2.5), Offset(x, 8.1), _tileLine);
    }
    for (var y = -1.5; y < 8; y += 1.25) {
      canvas.drawLine(Offset(-4, y), Offset(30, y), _tileLine);
    }
    for (final x in [3.5, 12.0, 21.0]) {
      canvas.drawLine(Offset(x, -1.5), Offset(x, -0.5), _tileLine..strokeWidth = 0.07);
      canvas.drawCircle(Offset(x, -0.35), 0.24,
          Paint()..color = const Color(0xFFFFD27A));
      canvas.drawCircle(Offset(x, -0.35), 0.65,
          Paint()..color = const Color(0x22FFD27A)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.4));
    }

    // Countertop and front fascia.
    canvas.drawRect(const Rect.fromLTWH(-4, 8.2, 34, 2.2), _floorPaint);
    canvas.drawRect(const Rect.fromLTWH(-4, 8.15, 34, 0.12), _floorEdgePaint);
    for (var x = -3.0; x < 29; x += 2.4) {
      canvas.drawLine(Offset(x, 8.45), Offset(x + 1.1, 10.3),
          Paint()..color = const Color(0x226B3524)..strokeWidth = 0.045);
    }

    _drawPan(canvas);
    _drawObstacles(canvas);
    _drawTarget(canvas);
    _drawSausage(canvas);
    _drawDecor(canvas);
  }

  void _drawPan(Canvas canvas) {
    final handle = Path()
      ..moveTo(-0.15, 7.45)
      ..lineTo(-1.25, 7.1)
      ..lineTo(-1.45, 7.45)
      ..lineTo(-0.2, 7.9)
      ..close();
    canvas.drawPath(handle, Paint()..color = const Color(0xFF303B48));
    canvas.drawPath(handle, Paint()
      ..color = const Color(0xFF8FA1B2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.07);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(1.55, 7.55), width: 3.6, height: 1.1),
      Paint()..color = const Color(0xFF111923),
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(1.55, 7.42), width: 3.55, height: 0.88),
      Paint()..color = const Color(0xFF718091),
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(1.55, 7.36), width: 3.18, height: 0.66),
      Paint()..color = const Color(0xFF293747),
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(1.55, 7.28), width: 2.7, height: 0.42),
      Paint()..color = const Color(0xFFDB8A4A),
    );
  }

  void _drawObstacles(Canvas canvas) {
    final level = game.level;
    if (level == null) return;
    for (final obstacle in level.obstacles) {
      final rect = Rect.fromCenter(
        center: Offset(obstacle.x, obstacle.y),
        width: obstacle.width,
        height: obstacle.height,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect.shift(const Offset(0.09, 0.12)), const Radius.circular(0.12)),
        Paint()..color = const Color(0x55000000),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(0.12)),
        Paint()..color = const Color(0xFFB56B42),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect.deflate(0.08), const Radius.circular(0.08)),
        Paint()
          ..color = const Color(0xFFFFC078)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.045,
      );
      canvas.drawLine(
        Offset(rect.left + 0.12, rect.top + 0.2),
        Offset(rect.right - 0.12, rect.top + 0.2),
        Paint()..color = const Color(0x66FFF0C2)..strokeWidth = 0.06,
      );
    }
  }

  void _drawTarget(Canvas canvas) {
    final target = game.target;
    if (target == null || !target.isLoaded) return;
    final p = target.body.position;
    final center = Offset(p.x, p.y);
    canvas.drawCircle(center, 0.92, Paint()..color = const Color(0x3349E6C1));
    canvas.drawCircle(center, 0.76, Paint()..color = const Color(0xFF172D37));
    canvas.drawCircle(center, 0.64, Paint()..color = const Color(0xFFFFD166));
    canvas.drawCircle(center, 0.43, Paint()..color = const Color(0xFFEF6C50));
    canvas.drawCircle(center, 0.22, Paint()..color = const Color(0xFFFFF1C7));
    canvas.drawCircle(center, 0.78, Paint()
      ..color = const Color(0xFF8AF2D6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.07);
    for (var i = 0; i < 8; i++) {
      final angle = i * math.pi / 4;
      final start = center + Offset(math.cos(angle), math.sin(angle)) * 0.98;
      final end = center + Offset(math.cos(angle), math.sin(angle)) * 1.15;
      canvas.drawLine(start, end, Paint()
        ..color = const Color(0xFFFFD166)
        ..strokeWidth = 0.055
        ..strokeCap = StrokeCap.round);
    }
  }

  void _drawSausage(Canvas canvas) {
    final sausage = game.sausage;
    if (sausage == null || !sausage.isLoaded) return;
    final p = sausage.body.position;
    canvas.save();
    canvas.translate(p.x, p.y);
    canvas.rotate(sausage.body.angle);
    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: 1.65, height: 0.56),
      const Radius.circular(0.28),
    );
    canvas.drawRRect(bodyRect.shift(const Offset(0.04, 0.08)),
        Paint()..color = const Color(0x66000000));
    canvas.drawRRect(bodyRect, Paint()..color = const Color(0xFF9B3F32));
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(0, -0.035), width: 1.48, height: 0.43),
        const Radius.circular(0.22),
      ),
      Paint()..color = const Color(0xFFE97952),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-0.52, -0.17, 0.72, 0.075),
        const Radius.circular(0.04),
      ),
      Paint()..color = const Color(0x99FFE1AE),
    );
    canvas.drawCircle(const Offset(-0.72, 0), 0.12, Paint()..color = const Color(0xFFFFB36C));
    canvas.drawCircle(const Offset(0.72, 0), 0.12, Paint()..color = const Color(0xFFB64A38));
    canvas.restore();
  }

  void _drawDecor(Canvas canvas) {
    // Small jars on the counter make the scene read as a kitchen, not an empty physics test.
    for (final x in [23.0, 25.0, 27.0]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, 6.35, 0.65, 1.45),
          const Radius.circular(0.12),
        ),
        Paint()..color = const Color(0xFF8CC6C9),
      );
      canvas.drawRect(Rect.fromLTWH(x + 0.12, 6.15, 0.41, 0.22),
          Paint()..color = const Color(0xFFDBA65C));
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x + 0.1, 6.72, 0.45, 0.08),
          const Radius.circular(0.04),
        ),
        Paint()..color = const Color(0x77FFFFFF),
      );
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(20.7, 7.55, 1.15, 0.55),
        const Radius.circular(0.1),
      ),
      Paint()..color = const Color(0xFF526B80),
    );
    canvas.drawRect(const Rect.fromLTWH(20.88, 7.35, 0.78, 0.22),
        Paint()..color = const Color(0xFF9BB5C4));
  }
}

class SausageBody extends BodyComponent with ContactCallbacks {
  SausageBody({
    required this.initialPosition,
    required this.onTargetContact,
    required this.onTargetLeave,
  }) : super(renderBody: false);

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
  TargetBody({required this.initialPosition}) : super(renderBody: false);

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
  GroundBody() : super(renderBody: false);

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
          renderBody: false,
        );
}
