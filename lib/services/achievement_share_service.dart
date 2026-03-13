import 'dart:io';
//import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/achievement.dart';

class AchievementShareService {
  AchievementShareService._();

  static Future<void> shareAchievement(Achievement achievement) async {
    final text =
        '🏆 Desbloqueei a conquista "${achievement.name}" no Movie Album!\n\n${achievement.description}';

    final icon = await _resolveIcon(achievement);
    if (icon != null) {
      await Share.shareXFiles(
        [icon],
        text: text,
        subject: 'Conquista desbloqueada',
      );
      return;
    }

    await Share.share(text, subject: 'Conquista desbloqueada');
  }

  static Future<XFile?> _resolveIcon(Achievement achievement) async {
    final iconUrl = achievement.iconUrl.trim();
    if (iconUrl.isEmpty) return null;

    try {
      if (iconUrl.startsWith('assets/')) {
        final data = await rootBundle.load(iconUrl);
        return _writeTempFile(
            data.buffer.asUint8List(), achievement.id, iconUrl);
      }

      if (iconUrl.startsWith('http://') || iconUrl.startsWith('https://')) {
        final response = await http.get(Uri.parse(iconUrl));
        if (response.statusCode == 200) {
          return _writeTempFile(response.bodyBytes, achievement.id, iconUrl);
        }
      }
    } catch (_) {
      return null;
    }

    return null;
  }

  static Future<XFile?> _writeTempFile(
      Uint8List bytes, String achievementId, String source) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final ext = source.toLowerCase().endsWith('.webp')
          ? 'webp'
          : source.toLowerCase().endsWith('.jpg') ||
                  source.toLowerCase().endsWith('.jpeg')
              ? 'jpg'
              : 'png';

      final file = File('${tempDir.path}/achievement_$achievementId.$ext');
      await file.writeAsBytes(bytes, flush: true);
      return XFile(file.path);
    } catch (_) {
      return null;
    }
  }
}
