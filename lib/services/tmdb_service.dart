// lib/services/tmdb_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

class TMDBService {
  final String apiKey;
  final String apiToken;
  final String baseUrl = 'https://api.themoviedb.org/3';
  final String language = 'pt-BR';

  TMDBService({
    required this.apiKey,
    required this.apiToken,
  });

  Future<Map<String, dynamic>> getList(String listId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/list/$listId?api_key=$apiKey&language=$language'),
      headers: {
        'Authorization': 'Bearer $apiToken',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load list: ${response.statusCode}');
    }
  }

  Future<Map<String, dynamic>> getMovieDetails(int movieId) async {
    final response = await http.get(
      Uri.parse(
          '$baseUrl/movie/$movieId?api_key=$apiKey&language=$language&append_to_response=keywords,watch/providers'),
      headers: {
        'Authorization': 'Bearer $apiToken',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load movie details: ${response.statusCode}');
    }
  }

  Future<List<Map<String, dynamic>>> getMoviesFromList(String listId) async {
    final listData = await getList(listId);
    final List<dynamic> items = listData['items'] ?? [];
    final List<Map<String, dynamic>> movies = [];

    for (var item in items) {
      try {
        final movieDetails = await getMovieDetails(item['id']);
        movies.add(movieDetails);
      } catch (e) {
        print('Error fetching details for movie ${item['id']}: $e');
      }
    }

    return movies;
  }

  List<String> extractGenres(Map<String, dynamic> movieData) {
    final List<dynamic> genres = movieData['genres'] ?? [];
    return genres.map<String>((genre) => genre['name'].toString()).toList();
  }

  List<String> extractKeywords(Map<String, dynamic> movieData) {
    final keywordsData = movieData['keywords'];
    if (keywordsData == null) return [];

    final List<dynamic> keywords = keywordsData['keywords'] ?? [];
    return keywords
        .map<String>((keyword) => keyword['name'].toString())
        .toList();
  }

  List<String> extractPlatforms(Map<String, dynamic> movieData) {
    final watchProviders = movieData['watch/providers'];
    if (watchProviders == null) return [];

    final results = watchProviders['results'];
    if (results == null) return [];

    final brData = results['BR'];
    if (brData == null) return [];

    final List<dynamic> flatrate = brData['flatrate'] ?? [];
    final List<dynamic> rent = brData['rent'] ?? [];
    final List<dynamic> buy = brData['buy'] ?? [];

    final Set<String> platforms = {};

    for (var provider in [...flatrate, ...rent, ...buy]) {
      platforms.add(provider['provider_name'].toString());
    }

    return platforms.toList();
  }

  Map<String, dynamic> transformMovieData(Map<String, dynamic> movieData) {
    return {
      'id': movieData['id'],
      'title': movieData['title'],
      'description': movieData['overview'],
      'genres': extractGenres(movieData),
      'platforms': extractPlatforms(movieData),
      'releaseDate': movieData['release_date'],
      'keywords': extractKeywords(movieData),
      'posterUrl': movieData['poster_path'] != null
          ? 'https://image.tmdb.org/t/p/w500${movieData['poster_path']}'
          : '',
      'isWatched': false,
      'rating': 0.0,
    };
  }
}
