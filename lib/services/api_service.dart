import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:hive/hive.dart';

class ApiService {
  static const String apiKey = 'f6b750ae57811b46ef095aaa96092c59';
  static const String token =
      'eyJhbGciOiJIUzI1NiJ9.eyJhdWQiOiJmNmI3NTBhZTU3ODExYjQ2ZWYwOTVhYWE5NjA5MmM1OSIsIm5iZiI6MTYyOTkzMTI3Ni4zMzQsInN1YiI6IjYxMjZjNzBjNWVkOTYyMDAyNjY5ZGVkYyIsInNjb3BlcyI6WyJhcGlfcmVhZCJdLCJ2ZXJzaW9uIjoxfQ.UDycv3COVFlnp6a5xEkz1RXo_lyZKw1uud9ibg2qvJA';
  static const String baseUrl = 'https://api.themoviedb.org/3';
  final Box _moviesCache = Hive.box('moviesCache');

  // Método auxiliar para criar headers padrão
  Map<String, String> _buildHeaders() {
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
  }

  // Método para lidar com a resposta da API
  dynamic _processResponse(http.Response response) {
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception(
          'Erro: ${response.statusCode} - ${response.reasonPhrase}');
    }
  }

  // Buscar os filmes mais bem avaliados
  Future<List<dynamic>> getTopRatedMovies() async {
    List<dynamic>? cachedMovies = _moviesCache.get('moviesList');
    List<dynamic> allMovies = [];
    int page = 1;

    if (cachedMovies != null && cachedMovies.isNotEmpty) {
      return cachedMovies;
    } else {
      try {
        while (true) {
          final url =
              Uri.parse('$baseUrl/list/8499489?language=pt-BR&page=$page');
          final response = await http.get(url, headers: _buildHeaders());
          final data = _processResponse(response);

          allMovies.addAll(data['items']);

          if (page >= data['total_pages']) break;
          page++;
        }
      } catch (e) {
        throw Exception('Erro ao carregar filmes: $e');
      }
      _moviesCache.put('moviesList', allMovies);
      return allMovies;
    }
  }

  // Buscar plataformas disponíveis para um filme
  Future<Map<String, List<Map<String, String>>>> getAvailablePlatforms(
      int movieId, String region) async {
    try {
      final url =
          Uri.parse('$baseUrl/movie/$movieId/watch/providers?api_key=$apiKey');
      final response = await http.get(url, headers: _buildHeaders());
      final data = _processResponse(response);

      final results = data['results']?[region];
      if (results != null) {
        return {
          'streaming': _extractPlatforms(results['flatrate']),
          'rent': _extractPlatforms(results['rent']),
        };
      } else if (region == 'BR') {
        return await getAvailablePlatforms(movieId, 'US'); // Fallback para US
      }

      return {'streaming': [], 'rent': []};
    } catch (e) {
      throw Exception('Erro ao carregar plataformas: $e');
    }
  }

  // Método auxiliar para extrair plataformas
  List<Map<String, String>> _extractPlatforms(List? platforms) {
    return platforms
            ?.map<Map<String, String>>((item) => {
                  'provider_name': item['provider_name'] ?? 'Desconhecido',
                  'logo_path':
                      'https://image.tmdb.org/t/p/w500${item['logo_path']}',
                })
            .toList() ??
        [];
  }
}
