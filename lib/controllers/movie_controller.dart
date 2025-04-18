// lib/controllers/movie_controller.dart
import '../services/tmdb_service.dart';
import '../services/firestore_service.dart';
import '../models/movie.dart';

class MovieController {
  final TMDBService tmdbService;
  final FirestoreService firestoreService;

  MovieController({
    required this.tmdbService,
    required this.firestoreService,
  });

  // Rotina de administração para importar filmes da lista TMDB para o Firebase
  Future<void> importMoviesFromList(String listId) async {
    try {
      // Buscar filmes da lista TMDB
      final List<Map<String, dynamic>> tmdbMovies =
          await tmdbService.getMoviesFromList(listId);

      // Transformar dados para o formato do Firebase
      final List<Map<String, dynamic>> moviesData = tmdbMovies.map((movieData) {
        return tmdbService.transformMovieData(movieData);
      }).toList();

      // Salvar filmes no Firebase
      await firestoreService.addMovies(moviesData);

      print(
          'Successfully imported ${moviesData.length} movies from TMDB list to Firebase');
    } catch (e) {
      print('Error importing movies from TMDB: $e');
      throw e;
    }
  }

  // Obter todos os filmes do Firebase
  Future<List<Movie>> getAllMovies() async {
    try {
      return await firestoreService.getMovies();
    } catch (e) {
      print('Error getting all movies: $e');
      throw e;
    }
  }

  // Marcar filme como assistido
  Future<void> markMovieAsWatched(String userId, String movieId,
      {double rating = 0.0}) async {
    try {
      await firestoreService.markMovieAsWatched(userId, movieId,
          rating: rating);
    } catch (e) {
      print('Error marking movie as watched: $e');
      throw e;
    }
  }

  // Avaliar filme
  Future<void> rateMovie(String userId, String movieId, double rating) async {
    try {
      await firestoreService.rateMovie(userId, movieId, rating);
    } catch (e) {
      print('Error rating movie: $e');
      throw e;
    }
  }

  // Obter filmes assistidos por um usuário
  Future<List<Movie>> getWatchedMovies(String userId) async {
    try {
      return await firestoreService.getWatchedMovies(userId);
    } catch (e) {
      print('Error getting watched movies: $e');
      throw e;
    }
  }

  // Filtrar filmes por gênero
  List<Movie> filterByGenre(List<Movie> movies, String genre) {
    return movies.where((movie) => movie.genres.contains(genre)).toList();
  }

  // Filtrar filmes por plataforma
  List<Movie> filterByPlatform(List<Movie> movies, String platform) {
    return movies.where((movie) => movie.platforms.contains(platform)).toList();
  }

  // Filtrar filmes por palavra-chave
  List<Movie> filterByKeyword(List<Movie> movies, String keyword) {
    return movies.where((movie) => movie.keywords.contains(keyword)).toList();
  }

  // Filtrar filmes por nome (busca parcial)
  List<Movie> filterByName(List<Movie> movies, String name) {
    final lowerCaseName = name.toLowerCase();
    return movies
        .where((movie) => movie.title.toLowerCase().contains(lowerCaseName))
        .toList();
  }
}
