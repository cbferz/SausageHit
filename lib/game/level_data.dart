class LevelData {
  const LevelData({
    required this.id,
    required this.name,
    required this.targetX,
    required this.targetY,
    required this.launchX,
    required this.launchY,
    required this.maxPull,
    required this.timeLimitSeconds,
    required this.obstacles,
  });

  final int id;
  final String name;
  final double targetX;
  final double targetY;
  final double launchX;
  final double launchY;
  final double maxPull;
  final int timeLimitSeconds;
  final List<LevelObstacle> obstacles;

  factory LevelData.fromJson(Map<String, dynamic> json) {
    final rawObstacles = json['obstacles'];
    if (rawObstacles is! List) {
      throw const FormatException('Level obstacles must be a list');
    }
    return LevelData(
      id: _readInt(json, 'id'),
      name: _readString(json, 'name'),
      targetX: _readDouble(json, 'targetX'),
      targetY: _readDouble(json, 'targetY'),
      launchX: _readDouble(json, 'launchX'),
      launchY: _readDouble(json, 'launchY'),
      maxPull: _readDouble(json, 'maxPull'),
      timeLimitSeconds: _readInt(json, 'timeLimitSeconds'),
      obstacles: rawObstacles
          .map((item) => LevelObstacle.fromJson(
                Map<String, dynamic>.from(item as Map),
              ))
          .toList(growable: false),
    );
  }

  static int _readInt(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! num) throw FormatException('Missing or invalid $key');
    return value.toInt();
  }

  static double _readDouble(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! num) throw FormatException('Missing or invalid $key');
    return value.toDouble();
  }

  static String _readString(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! String || value.isEmpty) {
      throw FormatException('Missing or invalid $key');
    }
    return value;
  }
}

class LevelObstacle {
  const LevelObstacle({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  final double x;
  final double y;
  final double width;
  final double height;

  factory LevelObstacle.fromJson(Map<String, dynamic> json) {
    double read(String key) {
      final value = json[key];
      if (value is! num) throw FormatException('Invalid obstacle $key');
      return value.toDouble();
    }

    return LevelObstacle(
      x: read('x'),
      y: read('y'),
      width: read('width'),
      height: read('height'),
    );
  }
}
