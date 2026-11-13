import 'dart:math' as math;
import 'package:flame/game.dart';
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import '../game/sausage_game.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({required this.game, super.key});
  final SausageGame game;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  SausageGame get game => widget.game;

  @override
  void dispose() {
    game.state.dispose();
    game.levelNumber.dispose();
    game.remainingSeconds.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          return Stack(
            fit: StackFit.expand,
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanStart: (details) {
                  game.beginAim(details.localPosition, size);
                  setState(() {});
                },
                onPanUpdate: (details) {
                  game.updateAim(details.localPosition, size);
                  setState(() {});
                },
                onPanEnd: (_) {
                  game.releaseAim();
                  setState(() {});
                },
                child: GameWidget(game: game),
              ),
              IgnorePointer(
                child: CustomPaint(
                  painter: _AimPainter(game),
                  size: Size.infinite,
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _HudPill(
                        child: ValueListenableBuilder<int>(
                          valueListenable: game.levelNumber,
                          builder: (_, value, __) => Text('LEVEL $value'),
                        ),
                      ),
                      const Spacer(),
                      _HudPill(
                        child: ValueListenableBuilder<int>(
                          valueListenable: game.remainingSeconds,
                          builder: (_, value, __) => Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.timer_outlined, size: 17),
                              const SizedBox(width: 6),
                              Text('$value s'),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 18),
                    child: ValueListenableBuilder<RoundState>(
                      valueListenable: game.state,
                      builder: (context, state, _) {
                        if (state == RoundState.won ||
                            state == RoundState.lost) {
                          final won = state == RoundState.won;
                          return _ResultPanel(
                            title: won ? 'NICE SHOT!' : 'TRY AGAIN',
                            subtitle: won
                                ? 'Target reached'
                                : 'The sausage missed its target',
                            buttonText: won ? 'NEXT LEVEL' : 'RETRY',
                            onPressed: won ? game.nextLevel : game.restart,
                          );
                        }
                        if (state == RoundState.aiming) {
                          return const _HudPill(
                            child: Text('DRAG BACK TO AIM  •  RELEASE TO LAUNCH'),
                          );
                        }
                        if (state == RoundState.loading) {
                          return const _HudPill(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _AimPainter extends CustomPainter {
  const _AimPainter(this.game);

  final SausageGame game;

  @override
  void paint(Canvas canvas, Size size) {
    final level = game.level;
    if (!game.isAiming || level == null || game.aimDelta.distance < 0.08) {
      return;
    }

    final scale = math.min(size.width / 24, size.height / 13.5);
    final origin = Offset(
      size.width / 2 + (level.launchX - 12) * scale,
      size.height / 2 + (level.launchY - 6.75) * scale,
    );
    final velocity = game.aimDelta * 7.2;
    final paint = Paint()
      ..color = const Color(0xFFFFD166)
      ..style = PaintingStyle.fill;

    for (var t = 0.08; t <= 2.2; t += 0.12) {
      final point = Offset(
        origin.dx + velocity.dx * t * scale,
        origin.dy + (velocity.dy * t + 4.9 * t * t) * scale,
      );
      if (point.dx < 0 || point.dx > size.width ||
          point.dy < 0 || point.dy > size.height) {
        break;
      }
      canvas.drawCircle(point, 2.6, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _AimPainter oldDelegate) => true;
}

class _HudPill extends StatelessWidget {
  const _HudPill({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        decoration: BoxDecoration(
          color: const Color(0xDD10141B),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white12),
        ),
        child: DefaultTextStyle(
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.1,
            fontSize: 12,
          ),
          child: child,
        ),
      );
}

class _ResultPanel extends StatelessWidget {
  const _ResultPanel({
    required this.title,
    required this.subtitle,
    required this.buttonText,
    required this.onPressed,
  });

  final String title;
  final String subtitle;
  final String buttonText;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(28, 20, 28, 18),
        decoration: BoxDecoration(
          color: const Color(0xF2191E27),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0x55FF7043)),
          boxShadow: const [
            BoxShadow(color: Colors.black45, blurRadius: 24, offset: Offset(0, 8)),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title,
                style: const TextStyle(
                  fontSize: 27,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                )),
            const SizedBox(height: 4),
            Text(subtitle, style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 15),
            FilledButton(
              onPressed: onPressed,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFFF7043),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 13),
              ),
              child: Text(buttonText,
                  style: const TextStyle(fontWeight: FontWeight.w900)),
            ),
          ],
        ),
      );
}
