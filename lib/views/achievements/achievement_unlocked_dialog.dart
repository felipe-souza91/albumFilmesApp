import 'package:flutter/material.dart';
import '../../services/achievement_share_service.dart';
import '../../models/achievement.dart';

class AchievementUnlockedDialog extends StatelessWidget {
  final Achievement achievement;

  const AchievementUnlockedDialog({super.key, required this.achievement});

  Future<void> _share(BuildContext context) async {
    try {
      await AchievementShareService.shareAchievement(achievement);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao compartilhar: $e')),
        );
      }
    }
  }

  Widget _buildIcon() {
    final iconUrl = achievement.iconUrl.trim();

    if (iconUrl.startsWith('assets/')) {
      return ClipOval(
        child: Image.asset(
          iconUrl,
          width: 56,
          height: 56,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const Icon(Icons.emoji_events,
              color: Color(0xFFFFD700), size: 48),
        ),
      );
    }

    if (iconUrl.startsWith('http://') || iconUrl.startsWith('https://')) {
      return ClipOval(
        child: Image.network(
          iconUrl,
          width: 56,
          height: 56,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const Icon(Icons.emoji_events,
              color: Color(0xFFFFD700), size: 48),
        ),
      );
    }

    return const Icon(Icons.emoji_events, color: Color(0xFFFFD700), size: 48);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color.fromRGBO(11, 18, 34, 1.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildIcon(),
            const SizedBox(height: 12),
            const Text(
              'Conquista desbloqueada!',
              style: TextStyle(
                color: Color(0xFFFFD700),
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              achievement.name,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              achievement.description,
              style: const TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFFFD700),
                      side: const BorderSide(color: Color(0xFFFFD700)),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Fechar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFD700),
                      foregroundColor: const Color(0xFF0D1B2A),
                    ),
                    onPressed: () => _share(context),
                    icon: const Icon(Icons.share),
                    label: const Text('Compartilhar'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
