import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'game/sausage_game.dart';
import 'ui/game_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final game = SausageGame();
  runApp(SausageHitApp(game: game));
}

class SausageHitApp extends StatelessWidget {
  const SausageHitApp({required this.game, super.key});

  final SausageGame game;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SausageHit',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF17191E),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFF7043),
          brightness: Brightness.dark,
        ),
        fontFamily: 'sans-serif',
      ),
      home: GameScreen(game: game),
    );
  }
}
