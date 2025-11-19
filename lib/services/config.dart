import 'dart:io';

/// Centraliza chaves e toggles. Prefira definir via --dart-define em build time
/// e complementar com Remote Config em runtime.
class Config {
  static String get tmdbApiKey => const String.fromEnvironment('TMDB_API_KEY',
      defaultValue: 'f6b750ae57811b46ef095aaa96092c59');

  static String get tmdbApiToken => const String.fromEnvironment(
      'TMDB_API_TOKEN',
      defaultValue:
          'eyJhdWQiOiJmNmI3NTBhZTU3ODExYjQ2ZWYwOTVhYWE5NjA5MmM1OSIsIm5iZiI6MTYyOTkzMTI3Ni4zMzQsInN1YiI6IjYxMjZjNzBjNWVkOTYyMDAyNjY5ZGVkYyIsInNjb3BlcyI6WyJhcGlfcmVhZCJdLCJ2ZXJzaW9uIjoxfQ');

  static bool get adsEnabled =>
      const bool.fromEnvironment('ADS_ENABLED', defaultValue: false);

  static String get flavor =>
      const String.fromEnvironment('FLAVOR', defaultValue: 'prod');

  static bool get isProd => flavor == 'prod';
}
