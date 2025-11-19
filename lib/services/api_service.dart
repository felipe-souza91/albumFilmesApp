import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:hive/hive.dart';
import 'config.dart'; // <--- adiciona isso

class ApiService {
  static const String baseUrl = 'https://api.themoviedb.org/3';
  final Box _moviesCache = Hive.box('moviesCache');

  // Obtenha as chaves do Config
  String get _apiKey => Config.tmdbApiKey;
  String get _token => Config.tmdbApiToken;

  Map<String, String> _buildHeaders() {
    return {
      'Authorization': 'Bearer $_token',
      'Content-Type': 'application/json',
    };
  }

  dynamic _processResponse(http.Response response) {
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception(
          'Erro: ${response.statusCode} - ${response.reasonPhrase}');
    }
  }

  Future<List<dynamic>> getTopRatedMovies() async {
    // exemplo
    final response = await http.get(
      Uri.parse('$baseUrl/movie/top_rated?api_key=$_apiKey&language=pt-BR'),
      headers: _buildHeaders(),
    );
    return _processResponse(response)['results'];
  }
}
