// lib/views/achievements/achievements_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/achievement.dart';
import '../../services/firestore_service.dart';

class AchievementsScreen extends StatefulWidget {
  @override
  _AchievementsScreenState createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen>
    with SingleTickerProviderStateMixin {
  final FirestoreService _firestoreService = FirestoreService();
  bool _isLoading = true;
  List<Achievement> _achievements = [];
  List<UserAchievement> _userAchievements = [];
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao carregar conquistas: $e')),
      );
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
    } catch (e) {
      return null;
    }
  }

  void _shareAchievement(Achievement achievement) async {
    final text =
        'Desbloqueei a conquista "${achievement.name}" no Movie Album! ${achievement.description}';

    try {
      await Share.share(text, subject: 'Compartilhar via WhatsApp');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao compartilhar: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF0D1B2A),
      appBar: AppBar(
        title: Text('Conquistas'),
        backgroundColor: Color(0xFF0047AB),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: Color(0xFFFFD700),
          tabs: [
            Tab(text: 'Todas'),
            Tab(text: 'Quantidade'),
            Tab(text: 'Gêneros'),
            Tab(text: 'Diretores/Franquias'),
            Tab(text: 'Época/Origem'),
            Tab(text: 'Especiais'),
          ],
        ),
      ),
      body: _isLoading
          ? Center(
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
                    .where(
                      (a) => a.category == 'quantity',
                    )
                    .toList()),

                // Conquistas por gênero
                _buildAchievementsList(_achievements
                    .where(
                      (a) => a.category == 'genre',
                    )
                    .toList()),

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
      return Center(
        child: Text(
          'Nenhuma conquista disponível nesta categoria',
          style: TextStyle(color: Colors.white),
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: achievements.length,
      itemBuilder: (context, index) {
        final achievement = achievements[index];
        final isUnlocked = _isAchievementUnlocked(achievement.id);
        final userAchievement = _getUserAchievement(achievement.id);

        return Card(
          margin: EdgeInsets.only(bottom: 16),
          color: isUnlocked ? Color(0xFF0047AB) : Colors.grey[800],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(
              color: isUnlocked ? Color(0xFFFFD700) : Colors.transparent,
              width: 2,
            ),
          ),
          child: ListTile(
            contentPadding: EdgeInsets.all(16),
            leading: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: isUnlocked ? Color(0xFFFFD700) : Colors.grey,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.emoji_events,
                color: isUnlocked ? Color(0xFF0D1B2A) : Colors.white54,
                size: 30,
              ),
            ),
            title: Text(
              achievement.name,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 8),
                Text(
                  achievement.description,
                  style: TextStyle(
                    color: Colors.white70,
                  ),
                ),
                SizedBox(height: 8),
                if (!isUnlocked && userAchievement != null)
                  LinearProgressIndicator(
                    value: userAchievement.progress /
                        (achievement.ruleValue as int),
                    backgroundColor: Colors.grey[700],
                    valueColor:
                        AlwaysStoppedAnimation<Color>(Color(0xFFFFD700)),
                  ),
                if (isUnlocked)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton.icon(
                        icon: Icon(Icons.share, color: Colors.white),
                        label: Text(
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
