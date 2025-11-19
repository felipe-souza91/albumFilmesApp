import 'package:firebase_analytics/firebase_analytics.dart';

class AnalyticsService {
  AnalyticsService._();
  static final AnalyticsService instance = AnalyticsService._();
  final FirebaseAnalytics _fa = FirebaseAnalytics.instance;

  Future<void> logAlbumOpened() =>
      _fa.logEvent(name: 'album_opened');

  Future<void> logMovieMarkedWatched(String movieId) =>
      _fa.logEvent(name: 'movie_marked_watched', parameters: {'movie_id': movieId});

  Future<void> logMovieRated(String movieId, int rating) =>
      _fa.logEvent(name: 'movie_rated', parameters: {'movie_id': movieId, 'rating': rating});

  Future<void> logRandomPick(String movieId) =>
      _fa.logEvent(name: 'random_pick', parameters: {'movie_id': movieId});

  Future<void> logPersonalizedPick(String movieId, double score) =>
      _fa.logEvent(name: 'personalized_pick', parameters: {'movie_id': movieId, 'score': score});

  Future<void> logAchievementUnlocked(String achievementId) =>
      _fa.logEvent(name: 'achievement_unlocked', parameters: {'achievement_id': achievementId});

  Future<void> logAdImpression(String placement) =>
      _fa.logEvent(name: 'ad_impression', parameters: {'placement': placement});

  Future<void> logAdClick(String placement) =>
      _fa.logEvent(name: 'ad_click', parameters: {'placement': placement});
}