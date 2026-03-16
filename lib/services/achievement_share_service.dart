import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

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
        final rendered = await _renderShareImage(data.buffer.asUint8List());
        return _writeTempFile(
            rendered ?? data.buffer.asUint8List(), achievement.id, 'png');
      }

      if (iconUrl.startsWith('http://') || iconUrl.startsWith('https://')) {
        final response = await http.get(Uri.parse(iconUrl));
        if (response.statusCode == 200) {
          final rendered = await _renderShareImage(response.bodyBytes);
          return _writeTempFile(
              rendered ?? response.bodyBytes, achievement.id, 'png');
        }
      }
    } catch (_) {
      return null;
    }

    return null;
  }

  static Future<Uint8List?> _renderShareImage(Uint8List bytes) async {
    try {
      final codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: 512,
        targetHeight: 512,
      );
      final frame = await codec.getNextFrame();
      final image = frame.image;

      const size = 1024.0;
      const padding = 96.0;
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);

      final bgPaint = ui.Paint()
        ..color = const ui.Color(0xFF0D1B2A)
        ..style = ui.PaintingStyle.fill;
      canvas.drawRRect(
        ui.RRect.fromRectAndRadius(
          const ui.Rect.fromLTWH(0, 0, size, size),
          const ui.Radius.circular(48),
        ),
        bgPaint,
      );

      final cardPaint = ui.Paint()..color = const ui.Color(0xFF1A2A44);
      canvas.drawRRect(
        ui.RRect.fromRectAndRadius(
          const ui.Rect.fromLTWH(56, 56, size - 112, size - 112),
          const ui.Radius.circular(36),
        ),
        cardPaint,
      );

      final dst = ui.Rect.fromLTWH(
        padding,
        padding,
        size - (padding * 2),
        size - (padding * 2),
      );
      final src = ui.Rect.fromLTWH(
        0,
        0,
        image.width.toDouble(),
        image.height.toDouble(),
      );
      canvas.drawImageRect(image, src, dst, ui.Paint());

      final finalImage =
          await recorder.endRecording().toImage(size.toInt(), size.toInt());
      final data = await finalImage.toByteData(format: ui.ImageByteFormat.png);
      return data?.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  static Future<XFile?> _writeTempFile(
      Uint8List bytes, String achievementId, String ext) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/achievement_$achievementId.$ext');
      await file.writeAsBytes(bytes, flush: true);
      return XFile(file.path);
    } catch (_) {
      return null;
    }
  }
}
