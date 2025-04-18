import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/movie.dart';

class MovieProvider extends ChangeNotifier {
  List<Movie> _movies = [];
  List<Movie> _filteredMovies = [];
  bool _isLoading = false;
  String _error = '';

  // Filtros ativos
  String? _genreFilter;
  String? _platformFilter;
  String? _keywordFilter;
  String? _nameFilter;

  // Getters
  List<Movie> get movies => _movies;
  List<Movie> get filteredMovies => _filteredMovies;
  bool get isLoading => _isLoading;
  String get error => _error;

  String? get genreFilter => _genreFilter;
  String? get platformFilter => _platformFilter;
  String? get keywordFilter => _keywordFilter;
  String? get nameFilter => _nameFilter;

  // Carregar filmes
  Future<void> loadMovies(Future<List<Movie>> Function() getMovies) async {
    _isLoading = true;
    _error = '';
    notifyListeners();

    try {
      _movies = await getMovies();
      _applyFilters();
    } catch (e, stackTrace) {
      _error = 'Error getting movies: $e\n$stackTrace';
      print(_error);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Aplicar filtros
  void _applyFilters() {
    _filteredMovies = _movies;

    if (_genreFilter != null && _genreFilter!.isNotEmpty) {
      _filteredMovies = _filteredMovies
          .where((movie) => movie.genres.contains(_genreFilter))
          .toList();
    }

    if (_platformFilter != null && _platformFilter!.isNotEmpty) {
      _filteredMovies = _filteredMovies
          .where((movie) => movie.platforms.contains(_platformFilter))
          .toList();
    }

    if (_keywordFilter != null && _keywordFilter!.isNotEmpty) {
      _filteredMovies = _filteredMovies
          .where((movie) => movie.keywords.contains(_keywordFilter))
          .toList();
    }

    if (_nameFilter != null && _nameFilter!.isNotEmpty) {
      final lowerCaseName = _nameFilter!.toLowerCase();
      _filteredMovies = _filteredMovies
          .where((movie) => movie.title.toLowerCase().contains(lowerCaseName))
          .toList();
    }

    notifyListeners();
  }

  // Definir filtro de gênero
  void setGenreFilter(String? genre) {
    _genreFilter = genre;
    _applyFilters();
  }

  // Definir filtro de plataforma
  void setPlatformFilter(String? platform) {
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
