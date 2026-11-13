import 'dart:convert';
import 'package:flutter/services.dart';
import 'level_data.dart';

class LevelLoader {
  static const levelCount = 8;

  Future<LevelData> load(int index) async {
    if (index < 0 || index >= levelCount) {
      throw RangeError.range(index, 0, levelCount - 1, 'index');
    }
    final source = await rootBundle.loadString(
      'assets/levels/level_${index + 1}.json',
    );
    final decoded = jsonDecode(source);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Level root must be a JSON object');
    }
    return LevelData.fromJson(decoded);
  }

  static LevelData parse(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Level root must be a JSON object');
    }
    return LevelData.fromJson(decoded);
  }
}
