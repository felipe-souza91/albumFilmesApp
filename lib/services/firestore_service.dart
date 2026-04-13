// lib/services/firestore_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/movie.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String moviesCollection = 'movies';
  final String usersCollection = 'users';
  final String userMoviesCollection = 'user_movies';
  final String achievementsCollection = 'achievements';
  final String userAchievementsCollection = 'user_achievements';
  final String userMetricsCollection = 'user_metrics';

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

  Future<int> getWeekendWatchedCount(String userId) async {
    final snapshot = await _firestore
        .collection(userMoviesCollection)
        .where('userId', isEqualTo: userId)
        .where('watched', isEqualTo: true)
        .get();

    var count = 0;
    for (final doc in snapshot.docs) {
      final watchedDate = doc.data()['watchedDate'];
      if (watchedDate is Timestamp) {
        final dt = watchedDate.toDate();
        if (dt.weekday == DateTime.saturday || dt.weekday == DateTime.sunday) {
          count++;
        }
      }
    }
    return count;
  }

  Future<void> incrementUserMetric(String userId, String metric,
      {int by = 1}) async {
    final ref =
        _firestore.collection(userMetricsCollection).doc('${userId}_$metric');
    await ref.set({
      'userId': userId,
      'metric': metric,
      'count': FieldValue.increment(by),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<int> getUserMetricCount(String userId, String metric) async {
    final ref =
        _firestore.collection(userMetricsCollection).doc('${userId}_$metric');
    final snap = await ref.get();
    if (!snap.exists) return 0;
    final data = snap.data();
    final count = data?['count'];
    if (count is int) return count;
    if (count is num) return count.toInt();
    return 0;
  }

  /// LGPD: exclui todos os dados do usuário do Firestore e do Storage.
  ///
  /// Coleções limpas:
  ///   - users/{uid}
  ///   - user_movies/{uid}_*
  ///   - user_achievements/{uid}_*
  ///   - user_metrics/{uid}_*
  ///   - user_preferences/{uid}
  ///   - user_answers/{uid}/versions/*
  ///   - Storage: users/{uid}/**
  ///
  /// A exclusão da conta no Firebase Auth fica a cargo do caller
  /// (profile_screen.dart), que precisa fazer reauthenticate antes.
  Future<void> deleteAllUserData(String userId) async {
    // Helper: deleta todos os docs de uma coleção com userId == uid
    Future<void> deleteCollection(String collection) async {
      final snap = await _firestore
          .collection(collection)
          .where('userId', isEqualTo: userId)
          .get();
      final batch = _firestore.batch();
      for (final doc in snap.docs) {
        batch.delete(doc.reference);
      }
      if (snap.docs.isNotEmpty) await batch.commit();
    }

    // 1) Coleções com campo userId
    await deleteCollection(userMoviesCollection);
    await deleteCollection(userAchievementsCollection);
    await deleteCollection(userMetricsCollection);

    // 2) Documentos com chave igual ao uid
    await _firestore
        .collection(usersCollection)
        .doc(userId)
        .delete();

    await _firestore
        .collection('user_preferences')
        .doc(userId)
        .delete();

    // 3) Sub-coleção user_answers/{uid}/versions/*
    final versionsSnap = await _firestore
        .collection('user_answers')
        .doc(userId)
        .collection('versions')
        .get();
    final versionsBatch = _firestore.batch();
    for (final doc in versionsSnap.docs) {
      versionsBatch.delete(doc.reference);
    }
    if (versionsSnap.docs.isNotEmpty) await versionsBatch.commit();
    // Deleta o documento pai após esvaziar a sub-coleção
    await _firestore.collection('user_answers').doc(userId).delete();

    // 4) Firebase Storage: remove todos os arquivos em users/{uid}/
    try {
      final storageRef =
          FirebaseStorage.instance.ref().child('users/$userId');
      final listResult = await storageRef.listAll();
      for (final item in listResult.items) {
        await item.delete();
      }
    } on FirebaseException catch (e) {
      // Se o diretório não existir (object-not-found), ignora silenciosamente
      if (e.code != 'object-not-found') rethrow;
    }
  }
}
