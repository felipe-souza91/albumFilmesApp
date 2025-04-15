import 'package:cloud_firestore/cloud_firestore.dart';

class AchievementService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> markFilmWatched(String userId, String movieId,
      List<String> genres, String? director) async {
    final userFilmsRef = _firestore
        .collection('users')
        .doc(userId)
        .collection('films')
        .doc(movieId);
    await userFilmsRef.set({
      'movie_id': movieId,
      'watched_at': FieldValue.serverTimestamp(),
      'genres': genres,
      'director': director ?? '',
    });

    await _checkAchievements(userId);
  }

  Future<void> _checkAchievements(String userId) async {
    final achievementsRef = _firestore.collection('achievements');
    final userAchievementsRef =
        _firestore.collection('users').doc(userId).collection('achievements');
    final userFilmsRef =
        _firestore.collection('users').doc(userId).collection('films');

    final filmsSnapshot = await userFilmsRef.get();
    final totalFilms = filmsSnapshot.docs.length;
    final genreCounts = <String, int>{};
    final directorCounts = <String, int>{};

    for (var doc in filmsSnapshot.docs) {
      final genres = doc['genres'] as List<dynamic>? ?? [];
      final director = doc['director'] as String? ?? '';
      for (var genre in genres) {
        genreCounts[genre] = (genreCounts[genre] ?? 0) + 1;
      }
      if (director.isNotEmpty) {
        directorCounts[director] = (directorCounts[director] ?? 0) + 1;
      }
    }

    final achievementsSnapshot = await achievementsRef.get();
    for (var achievement in achievementsSnapshot.docs) {
      final data = achievement.data();
      final type = data['type'] as String;
      final goal = data['goal'] as Map<String, dynamic>;
      final achievementId = achievement.id;

      bool unlocked = false;
      int currentProgress = 0;

      if (type == 'total_films') {
        currentProgress = totalFilms;
        unlocked = currentProgress >= (goal['count'] as int);
      } else if (type == 'genre') {
        final targetGenre = goal['genre'] as String;
        currentProgress = genreCounts[targetGenre] ?? 0;
        unlocked = currentProgress >= (goal['count'] as int);
      } else if (type == 'director') {
        final targetDirector = goal['director'] as String;
        currentProgress = directorCounts[targetDirector] ?? 0;
        unlocked = currentProgress >= (goal['count'] as int);
      }

      await userAchievementsRef.doc(achievementId).set({
        'achievement_id': achievementId,
        'unlocked': unlocked,
        'progress': {'current': currentProgress},
        'unlocked_at': unlocked ? FieldValue.serverTimestamp() : null,
      }, SetOptions(merge: true));
    }
  }
}
