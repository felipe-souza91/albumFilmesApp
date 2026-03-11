// lib/views/achievements/achievements_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/achievement.dart';
import '../../services/achievement_share_service.dart';
import '../../services/firestore_service.dart';

class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key});

  @override
  AchievementsScreenState createState() => AchievementsScreenState();
}

class AchievementsScreenState extends State<AchievementsScreen>
    with SingleTickerProviderStateMixin {
  final FirestoreService _firestoreService = FirestoreService();
  bool _isLoading = true;
  List<Achievement> _achievements = [];
  List<UserAchievement> _userAchievements = [];
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 7, vsync: this);
    _loadAchievements();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAchievements() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) {
        throw Exception('Usuário não autenticado');
      }

      // Carregar todas as conquistas
      final achievementsSnapshot = await _firestoreService.firestore
          .collection(_firestoreService.achievementsCollection)
          .get();

      _achievements = achievementsSnapshot.docs
          .map((doc) => Achievement.fromJson(doc.data()))
          .toList();

      // Carregar conquistas do usuário
      final userAchievementsSnapshot = await _firestoreService.firestore
          .collection(_firestoreService.userAchievementsCollection)
          .where('userId', isEqualTo: userId)
          .get();

      _userAchievements = userAchievementsSnapshot.docs
          .map((doc) => UserAchievement.fromJson(doc.data()))
          .toList();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar conquistas: $e')),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  bool _isAchievementUnlocked(String achievementId) {
    return _userAchievements.any(
      (ua) => ua.achievementId == achievementId && ua.unlocked,
    );
  }

  UserAchievement? _getUserAchievement(String achievementId) {
    try {
      return _userAchievements.firstWhere(
        (ua) => ua.achievementId == achievementId,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _shareAchievement(Achievement achievement) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    try {
      await AchievementShareService.shareAchievement(achievement);
      if (userId != null) {
        await _firestoreService.incrementUserMetric(userId, 'shares');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao compartilhar: $e')),
        );
      }
    }
  }

  Widget _buildAchievementIcon(Achievement achievement, bool isUnlocked) {
    final iconUrl = achievement.iconUrl.trim();
    final bgColor = isUnlocked ? const Color(0xFFFFD700) : Colors.grey;
    final fallbackColor = isUnlocked ? const Color(0xFF0D1B2A) : Colors.white54;

    Widget child;
    if (iconUrl.startsWith('assets/')) {
      child = Image.asset(
        iconUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) =>
            Icon(Icons.emoji_events, color: fallbackColor, size: 30),
      );
    } else if (iconUrl.startsWith('http://') ||
        iconUrl.startsWith('https://')) {
      child = Image.network(
        iconUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) =>
            Icon(Icons.emoji_events, color: fallbackColor, size: 30),
      );
    } else {
      child = Icon(Icons.emoji_events, color: fallbackColor, size: 30);
    }

    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: bgColor,
        shape: BoxShape.circle,
      ),
      child: ClipOval(child: child),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      appBar: AppBar(
        iconTheme: IconThemeData(color: const Color(0xFFFFD700)),
        title: Text(
          'Conquistas',
          style: TextStyle(color: const Color(0xFFFFD700)),
        ),
        backgroundColor: const Color.fromRGBO(11, 18, 34, 1.0),
        bottom: TabBar(
          unselectedLabelColor: Colors.white,
          labelColor: const Color(0xFFFFD700),
          controller: _tabController,
          isScrollable: true,
          indicatorColor: const Color(0xFFFFD700),
          tabs: const [
            Tab(text: 'Todas'),
            Tab(text: 'Quantidade'),
            Tab(text: 'Gêneros'),
            Tab(text: 'Diretores/Franquias'),
            Tab(text: 'Época/Origem'),
            Tab(text: 'Social'),
            Tab(text: 'Especiais'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFFD700)),
              ),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                // Todas as conquistas
                _buildAchievementsList(_achievements),

                // Conquistas por quantidade
                _buildAchievementsList(_achievements
                    .where((a) => a.category == 'quantity')
                    .toList()),
                _buildAchievementsList(
                    _achievements.where((a) => a.category == 'genre').toList()),

                // Conquistas por diretor/franquia
                _buildAchievementsList(_achievements
                    .where(
                      (a) =>
                          a.category == 'director' || a.category == 'franchise',
                    )
                    .toList()),

                // Conquistas por época/origem
                _buildAchievementsList(_achievements
                    .where(
                      (a) => a.category == 'era' || a.category == 'origin',
                    )
                    .toList()),

                // Conquistas sociais
                _buildAchievementsList(_achievements
                    .where(
                      (a) => a.category == 'social',
                    )
                    .toList()),

                // Conquistas especiais
                _buildAchievementsList(_achievements
                    .where(
                      (a) => a.category == 'special',
                    )
                    .toList()),
              ],
            ),
    );
  }

  Widget _buildAchievementsList(List<Achievement> achievements) {
    if (achievements.isEmpty) {
      return const Center(
        child: Text(
          'Nenhuma conquista disponível nesta categoria',
          style: TextStyle(color: Colors.white),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: achievements.length,
      itemBuilder: (context, index) {
        final achievement = achievements[index];
        final isUnlocked = _isAchievementUnlocked(achievement.id);
        final userAchievement = _getUserAchievement(achievement.id);

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          color: isUnlocked ? const Color(0xFF0047AB) : Colors.grey[800],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(
              color: isUnlocked ? const Color(0xFFFFD700) : Colors.transparent,
              width: 2,
            ),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: _buildAchievementIcon(achievement, isUnlocked),
            title: Text(
              achievement.name,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                Text(
                  achievement.description,
                  style: const TextStyle(
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 8),
                if (!isUnlocked && userAchievement != null)
                  LinearProgressIndicator(
                    value: userAchievement.progress /
                        (achievement.ruleValue as int),
                    backgroundColor: Colors.grey[700],
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(Color(0xFFFFD700)),
                  ),
                if (isUnlocked)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton.icon(
                        icon: const Icon(Icons.share, color: Colors.white),
                        label: const Text(
                          'Compartilhar',
                          style: TextStyle(color: Colors.white),
                        ),
                        onPressed: () => _shareAchievement(achievement),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
