import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/movie.dart';

class MovieProvider extends ChangeNotifier {
  List<Movie> _movies = [];
  List<Movie> _filteredMovies = [];
  bool _isLoading = false;
  String _error = '';

  // Filtros ativos
  List<String>? _genreFilter;
  List<String>? _platformFilter;
  String? _keywordFilter;
  String? _nameFilter;
  String? _watchedFilter;

  // Getters
  List<Movie> get movies => _movies;
  List<Movie> get filteredMovies => _filteredMovies;
  bool get isLoading => _isLoading;
  String get error => _error;

  List<String>? get genreFilter => _genreFilter;
  List<String>? get platformFilter => _platformFilter;
  String? get keywordFilter => _keywordFilter;
  String? get nameFilter => _nameFilter;

  String? get currentUserId => FirebaseAuth.instance.currentUser?.uid;

  // Carregar filmes
  Future<void> loadMovies(
    Future<List<Movie>> Function() getMovies,
    Future<Map<String, Map<String, dynamic>>> Function() getUserMovies,
  ) async {
    _isLoading = true;
    _error = '';
    notifyListeners();

    try {
      final moviesList = await getMovies();
      final userMoviesMap = await getUserMovies();

      _movies = moviesList.map((movie) {
        final userData = userMoviesMap[movie.id.toString()];
        return movie.copyWith(
          isWatched: userData?['isWatched'] ?? false,
          rating: userData?['rating']?.toDouble() ?? 0.0,
        );
      }).toList();

      _applyFilters();
    } catch (e, stackTrace) {
      _error = 'Error getting movies or user data: $e\n$stackTrace';
      //print(_error);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Map<String, Map<String, dynamic>>> getUserMovies() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('user_movies')
        .where('userId', isEqualTo: currentUserId)
        .get();

    return {
      for (var doc in snapshot.docs)
        doc['movieId']: {
          'isWatched': doc['watched'],
          'rating': doc['rating'],
        }
    };
  }

  // Aplicar filtros
  void _applyFilters() {
    var result = [..._movies];

    if (_genreFilter != null && _genreFilter!.isNotEmpty) {
      result = result
          .where((movie) =>
              movie.genres.any((genre) => _genreFilter!.contains(genre)))
          .toList();
    }

    if (_platformFilter != null && _platformFilter!.isNotEmpty) {
      result = result
          .where((movie) => movie.platforms
              .any((platform) => _platformFilter!.contains(platform)))
          .toList();
    }

    if (_keywordFilter != null && _keywordFilter!.isNotEmpty) {
      result = result
          .where((movie) => movie.keywords.contains(_keywordFilter))
          .toList();
    }

    if (_nameFilter != null && _nameFilter!.isNotEmpty) {
      final lowerCaseName = _nameFilter!.toLowerCase();
      result = result
          .where((movie) => movie.title.toLowerCase().contains(lowerCaseName))
          .toList();
    }

    if (_watchedFilter != null) {
      if (_watchedFilter == 'watched') {
        result = result.where((m) => m.isWatched).toList();
      } else if (_watchedFilter == 'not_watched') {
        result = result.where((m) => !m.isWatched).toList();
      }
    }

    _filteredMovies = result;
    notifyListeners();
  }

  void setGenreFilterList(List<String>? genres) {
    _genreFilter = genres;
    _applyFilters();
  }

  void setPlatformFilterList(List<String>? platforms) {
    _platformFilter = platforms;
    _applyFilters();
  }

  // Aplicar filtros com base em parâmetros
  void setFilters({
    List<String>? genres,
    List<String>? platforms,
    String? keyword,
    String? name,
    String? watchedStatus,
  }) {
    _genreFilter = genres;
    _platformFilter = platforms;
    _keywordFilter = keyword;
    _nameFilter = name;
    _watchedFilter = watchedStatus;
    _applyFilters();
  }

  // Definir filtro de gênero
  void setGenreFilter(List<String>? genre) {
    _genreFilter = genre;
    _applyFilters();
  }

  // Definir filtro de plataforma
  void setPlatformFilter(List<String>? platform) {
    _platformFilter = platform;
    _applyFilters();
  }

  // Definir filtro de palavra-chave
  void setKeywordFilter(String? keyword) {
    _keywordFilter = keyword;
    _applyFilters();
  }

  // Definir filtro de nome
  void setNameFilter(String? name) {
    _nameFilter = name;
    _applyFilters();
  }

  // Limpar todos os filtros
  void clearFilters() {
    _genreFilter = null;
    _platformFilter = null;
    _keywordFilter = null;
    _nameFilter = null;
    _watchedFilter = null;
    _applyFilters();
  }

  void setWatchedFilter(String? status) {
    _watchedFilter = status;
    _applyFilters();
  }

  // Atualizar status de filme assistido
  void updateMovieWatchedStatus(String movieId, bool isWatched) {
    final index = _movies.indexWhere((movie) => movie.id.toString() == movieId);
    if (index != -1) {
      _movies[index] = _movies[index].copyWith(isWatched: isWatched);
      _applyFilters();
    }
  }

  // Atualizar avaliação de filme
  void updateMovieRating(String movieId, double rating) {
    final index = _movies.indexWhere((movie) => movie.id.toString() == movieId);
    if (index != -1) {
      _movies[index] = _movies[index].copyWith(rating: rating);
      _applyFilters();
    }
  }
}
