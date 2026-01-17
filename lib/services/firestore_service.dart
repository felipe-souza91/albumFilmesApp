// lib/services/firestore_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/movie.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String moviesCollection = 'movies';
  final String usersCollection = 'users';
  final String userMoviesCollection = 'user_movies';
  final String achievementsCollection = 'achievements';
  final String userAchievementsCollection = 'user_achievements';

  FirebaseFirestore get firestore => _firestore;

  // Movies
  Future<void> addMovie(Map<String, dynamic> movieData) async {
    try {
      await _firestore
          .collection(moviesCollection)
          .doc(movieData['id'].toString())
          .set(movieData);
    } catch (e) {
      //print('Error adding movie: $e');
      rethrow;
    }
  }

  Future<void> addMovies(List<Map<String, dynamic>> moviesData) async {
    final batch = _firestore.batch();

    for (var movieData in moviesData) {
      final docRef = _firestore
          .collection(moviesCollection)
          .doc(movieData['id'].toString());
      batch.set(docRef, movieData);
    }

    try {
      await batch.commit();
    } catch (e) {
      //print('Error adding movies in batch: $e');
      rethrow;
    }
  }

  Future<List<Movie>> getMovies() async {
    try {
      final snapshot = await _firestore.collection(moviesCollection).get();
      return snapshot.docs.map((doc) => Movie.fromJson(doc.data())).toList();
    } catch (e) {
      //print('Error getting movies: $e');
      rethrow;
    }
  }

  Future<Movie?> getMovie(String movieId) async {
    try {
      final doc =
          await _firestore.collection(moviesCollection).doc(movieId).get();
      if (doc.exists) {
        return Movie.fromJson(doc.data()!);
      }
      return null;
    } catch (e) {
      //print('Error getting movie: $e');
      rethrow;
    }
  }

  // User Movies
  Future<void> markMovieAsWatched(String userId, String movieId,
      {double rating = 0.0}) async {
    try {
      await _firestore
          .collection(userMoviesCollection)
          .doc('${userId}_$movieId')
          .set({
        'userId': userId,
        'movieId': movieId,
        'watched': true,
        'watchedDate': FieldValue.serverTimestamp(),
        'rating': rating,
      });
    } catch (e) {
      //print('Error marking movie as watched: $e');
      rethrow;
    }
  }

  Future<void> markMovieAsUnwatched(String userId, String movieId,
      {double rating = 0.0}) async {
    try {
      await _firestore
          .collection(userMoviesCollection)
          .doc('${userId}_$movieId')
          .set({
        'userId': userId,
        'movieId': movieId,
        'watched': false,
        'watchedDate': FieldValue.serverTimestamp(),
        'rating': rating,
      });
    } catch (e) {
      //print('Error marking movie as watched: $e');
      rethrow;
    }
  }

  Future<void> rateMovie(String userId, String movieId, double rating) async {
    try {
      await _firestore
          .collection(userMoviesCollection)
          .doc('${userId}_$movieId')
          .set({
        'userId': userId,
        'movieId': movieId,
        'rating': rating,
      }, SetOptions(merge: true));
    } catch (e) {
      //print('Error rating movie: $e');
      rethrow;
    }
  }

  Future<List<Movie>> getWatchedMovies(String userId) async {
    try {
      final snapshot = await _firestore
          .collection(userMoviesCollection)
          .where('userId', isEqualTo: userId)
          .where('watched', isEqualTo: true)
          .get();

      final List<Movie> movies = [];
      for (var doc in snapshot.docs) {
        final movieId = doc.data()['movieId'];
        final movie = await getMovie(movieId);
        if (movie != null) {
          movies.add(movie.copyWith(
            isWatched: true,
            rating: doc.data()['rating'] ?? 0.0,
          ));
        }
      }

      return movies;
    } catch (e) {
      //print('Error getting watched movies: $e');
      rethrow;
    }
  }

  // Achievements
  Future<void> setupAchievements(
      List<Map<String, dynamic>> achievements) async {
    final batch = _firestore.batch();

    for (var achievement in achievements) {
      final docRef =
          _firestore.collection(achievementsCollection).doc(achievement['id']);
      batch.set(docRef, achievement);
    }

    try {
      await batch.commit();
    } catch (e) {
      //print('Error setting up achievements: $e');
      rethrow;
    }
  }

  Future<bool> unlockAchievement(String userId, String achievementId) async {
    final docId = '${userId}_$achievementId';
    final ref = firestore.collection(userAchievementsCollection).doc(docId);

    return firestore.runTransaction((tx) async {
      final snap = await tx.get(ref);

      if (snap.exists) {
        final data = snap.data() as Map<String, dynamic>;
        final already = (data['unlocked'] ?? false) == true;
        if (already) return false;

        tx.set(
            ref,
            {
              'userId': userId,
              'achievementId': achievementId,
              'unlocked': true,
              'unlockedAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true));

        return true;
      } else {
        tx.set(
            ref,
            {
              'userId': userId,
              'achievementId': achievementId,
              'unlocked': true,
              'progress': 0,
              'unlockedAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true));

        return true;
      }
    });
  }

  Future<void> updateAchievementProgress(
      String userId, String achievementId, int progress) async {
    try {
      await _firestore
          .collection(userAchievementsCollection)
          .doc('${userId}_$achievementId')
          .set({
        'userId': userId,
        'achievementId': achievementId,
        'progress': progress,
      }, SetOptions(merge: true));
    } catch (e) {
      //print('Error updating achievement progress: $e');
      rethrow;
    }
  }
}
