import 'package:flutter_test/flutter_test.dart';
import 'package:sausage_hit/game/level_loader.dart';

void main() {
  test('parses a level JSON document and its obstacles', () {
    const source = '''
    {
      "id": 7,
      "name": "Test Level",
      "launchX": 1.5,
      "launchY": 6.8,
      "targetX": 9,
      "targetY": 4,
      "maxPull": 2.5,
      "timeLimitSeconds": 20,
      "obstacles": [
        {"x": 4, "y": 6, "width": 1, "height": 2}
      ]
    }
    ''';

    final level = LevelLoader.parse(source);

    expect(level.id, 7);
    expect(level.name, 'Test Level');
    expect(level.targetX, 9);
    expect(level.obstacles, hasLength(1));
    expect(level.obstacles.single.height, 2);
  });

  test('rejects malformed level data', () {
    expect(
      () => LevelLoader.parse('{"id": 1}'),
      throwsFormatException,
    );
  });
}
