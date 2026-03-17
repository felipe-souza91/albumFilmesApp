// lib/views/achievements/achievements_screen.dart
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../controllers/achievement_controller.dart';
import '../../models/achievement.dart';
import '../../services/achievement_share_service.dart';
import '../../services/ads_service.dart';
import '../../services/config.dart';
import '../../services/firestore_service.dart';
import 'achievement_unlocked_dialog.dart';

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
    unawaited(_prepareInterstitial());
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _prepareInterstitial() async {
    try {
      if (!Config.adsEnabled) return;
      if (Config.admobInterstitialUnitId.isEmpty) return;

      debugPrint('[Ads][achievements] preparando interstitial.');
      await AdsService.instance.init();
      await AdsService.instance.preloadInterstitial(
        adUnitId: Config.admobInterstitialUnitId,
      );
    } catch (e) {
      debugPrint('[Ads][achievements] falha ao preparar interstitial: $e');
    }
  }

  Future<void> _loadAchievements() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) {
        throw Exception('Usuário não autenticado');
      }

      final achievementsSnapshot = await _firestoreService.firestore
          .collection(_firestoreService.achievementsCollection)
          .get();

      _achievements = achievementsSnapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] ??= doc.id;
        return Achievement.fromJson(data);
      }).toList();

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
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
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

  Future<void> _showUnlockedAchievementsPopup(List<String> unlockedIds) async {
    if (unlockedIds.isEmpty || !mounted) return;

    for (final id in unlockedIds) {
      Achievement? achievement;
      try {
        achievement = _achievements.firstWhere((a) => a.id == id);
      } catch (_) {
        achievement = null;
      }

      if (!mounted) return;
      if (achievement == null) continue;

      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AchievementUnlockedDialog(achievement: achievement!),
      );
    }
  }

  Future<bool> _tryShowInterstitial({
    required String reason,
    Duration waitForReady = Duration.zero,
  }) async {
    try {
      if (!Config.adsEnabled) {
        debugPrint('[Ads][$reason] ads desabilitados.');
        return false;
      }
      if (Config.admobInterstitialUnitId.isEmpty) {
        debugPrint('[Ads][$reason] adUnitId vazio.');
        return false;
      }

      debugPrint(
        '[Ads][$reason] tentativa iniciada '
        '(ready=${AdsService.instance.hasInterstitialReady}).',
      );

      await AdsService.instance.init();

      if (!AdsService.instance.hasInterstitialReady) {
        await AdsService.instance.preloadInterstitial(
          adUnitId: Config.admobInterstitialUnitId,
        );
      }

      if (waitForReady > Duration.zero &&
          !AdsService.instance.hasInterstitialReady) {
        final deadline = DateTime.now().add(waitForReady);

        while (!AdsService.instance.hasInterstitialReady &&
            DateTime.now().isBefore(deadline)) {
          await Future<void>.delayed(const Duration(milliseconds: 100));
        }
      }

      final shown = await AdsService.instance.showInterstitialIfAvailable(
        adUnitId: Config.admobInterstitialUnitId,
      );

      debugPrint('[Ads][$reason] resultado da tentativa: shown=$shown.');
      return shown;
    } catch (e, stackTrace) {
      debugPrint('[Ads][$reason] excecao ao tentar exibir interstitial: $e');
      if (kDebugMode) {
        debugPrint(stackTrace.toString());
      }
      return false;
    }
  }

  Future<List<String>> _handleAchievementUnlockFlow(String userId) async {
    try {
      final controller = AchievementController(
        firestoreService: _firestoreService,
      );

      final newlyUnlockedIds =
          await controller.checkAchievementsForUser(userId);

      if (newlyUnlockedIds.isEmpty || !mounted) return newlyUnlockedIds;

      await _showUnlockedAchievementsPopup(newlyUnlockedIds);
      await _loadAchievements();
      return newlyUnlockedIds;
    } catch (e) {
      debugPrint('[Achievement] falha ao reavaliar conquistas: $e');
      return const <String>[];
    }
  }

  Future<void> _shareAchievement(Achievement achievement) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    try {
      await AchievementShareService.shareAchievement(achievement);
      if (userId != null) {
        await _firestoreService.incrementUserMetric(userId, 'shares');
        unawaited(_handlePostShareFlow(userId));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao compartilhar: $e')),
        );
      }
    }
  }

  Future<void> _handlePostShareFlow(String userId) async {
    final newlyUnlockedIds = await _handleAchievementUnlockFlow(userId);

    if (!mounted || newlyUnlockedIds.isEmpty) return;

    await Future<void>.delayed(const Duration(milliseconds: 150));
    await _tryShowInterstitial(
      reason: 'achievement_screen_share',
      waitForReady: const Duration(milliseconds: 1200),
    );
  }

  Widget _buildAchievementIcon(Achievement achievement, bool isUnlocked) {
    final iconUrl = achievement.iconUrl.trim();
    final bgColor = isUnlocked ? const Color(0xFFFFD700) : Colors.grey;
    final fallbackColor = isUnlocked ? const Color(0xFF0D1B2A) : Colors.white54;

    Widget iconWidget;
    if (iconUrl.startsWith('assets/')) {
      iconWidget = Image.asset(
        iconUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) =>
            Icon(Icons.emoji_events, color: fallbackColor, size: 30),
      );
    } else if (iconUrl.startsWith('http://') ||
        iconUrl.startsWith('https://')) {
      iconWidget = Image.network(
        iconUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) =>
            Icon(Icons.emoji_events, color: fallbackColor, size: 30),
      );
    } else {
      iconWidget = Icon(Icons.emoji_events, color: fallbackColor, size: 30);
    }

    if (!isUnlocked) {
      iconWidget = ColorFiltered(
        colorFilter: const ColorFilter.matrix(<double>[
          0.2126,
          0.7152,
          0.0722,
          0,
          0,
          0.2126,
          0.7152,
          0.0722,
          0,
          0,
          0.2126,
          0.7152,
          0.0722,
          0,
          0,
          0,
          0,
          0,
          1,
          0,
        ]),
        child: iconWidget,
      );
    }

    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: bgColor,
        shape: BoxShape.circle,
        border: Border.all(
          color: isUnlocked ? const Color(0xFFFFE082) : Colors.white24,
          width: isUnlocked ? 2 : 1,
        ),
        boxShadow: isUnlocked
            ? const [
                BoxShadow(
                  color: Color.fromARGB(120, 255, 215, 0),
                  blurRadius: 10,
                  spreadRadius: 1,
                  offset: Offset(0, 2),
                ),
              ]
            : const [],
      ),
      child: ClipOval(child: iconWidget),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Color(0xFFFFD700)),
        title: const Text(
          'Conquistas',
          style: TextStyle(color: Color(0xFFFFD700)),
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
                _buildAchievementsGrid(_achievements),
                _buildAchievementsGrid(
                  _achievements.where((a) => a.category == 'quantity').toList(),
                ),
                _buildAchievementsGrid(
                  _achievements.where((a) => a.category == 'genre').toList(),
                ),
                _buildAchievementsGrid(
                  _achievements
                      .where(
                        (a) =>
                            a.category == 'director' ||
                            a.category == 'franchise',
                      )
                      .toList(),
                ),
                _buildAchievementsGrid(
                  _achievements
                      .where(
                        (a) => a.category == 'era' || a.category == 'origin',
                      )
                      .toList(),
                ),
                _buildAchievementsGrid(
                  _achievements.where((a) => a.category == 'social').toList(),
                ),
                _buildAchievementsGrid(
                  _achievements.where((a) => a.category == 'special').toList(),
                ),
              ],
            ),
    );
  }

  Widget _buildAchievementsGrid(List<Achievement> achievements) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.75,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: achievements.length,
      itemBuilder: (context, index) {
        final achievement = achievements[index];
        final isUnlocked = _isAchievementUnlocked(achievement.id);
        final userAchievement = _getUserAchievement(achievement.id);
        final progress = userAchievement?.progress ?? 0;
        final maxProgress = achievement.targetValue;
        final progressValue = maxProgress > 0 ? progress / maxProgress : 0.0;

        return GestureDetector(
          onTap: isUnlocked ? () => _shareAchievement(achievement) : null,
          child: Container(
            decoration: BoxDecoration(
              color: const Color.fromRGBO(11, 18, 34, 1.0),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isUnlocked ? const Color(0xFFFFD700) : Colors.white24,
                width: isUnlocked ? 2 : 1,
              ),
              boxShadow: isUnlocked
                  ? const [
                      BoxShadow(
                        color: Color.fromARGB(40, 255, 215, 0),
                        blurRadius: 10,
                        spreadRadius: 1,
                        offset: Offset(0, 4),
                      ),
                    ]
                  : const [],
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    children: [
                      _buildAchievementIcon(achievement, isUnlocked),
                      const SizedBox(height: 12),
                      Text(
                        achievement.name,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isUnlocked
                              ? const Color(0xFFFFD700)
                              : Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        achievement.description,
                        textAlign: TextAlign.center,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    children: [
                      LinearProgressIndicator(
                        value: progressValue.clamp(0.0, 1.0),
                        backgroundColor: Colors.white12,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          isUnlocked
                              ? const Color(0xFFFFD700)
                              : Colors.blueGrey,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '$progress / $maxProgress',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                        ),
                      ),
                      if (isUnlocked) ...[
                        const SizedBox(height: 8),
                        const Text(
                          'Toque para compartilhar',
                          style: TextStyle(
                            color: Color(0xFFFFD700),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
