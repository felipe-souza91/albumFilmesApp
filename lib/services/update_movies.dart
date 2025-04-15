import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';

// Credenciais
const String tmdbApiKey =
    'f6b750ae57811b46ef095aaa96092c59'; // Substitua pela sua chave da TMDb
const String tmdbAccessToken =
    'eyJhbGciOiJIUzI1NiJ9.eyJhdWQiOiJmNmI3NTBhZTU3ODExYjQ2ZWYwOTVhYWE5NjA5MmM1OSIsIm5iZiI6MTYyOTkzMTI3Ni4zMzQsInN1YiI6IjYxMjZjNzBjNWVkOTYyMDAyNjY5ZGVkYyIsInNjb3BlcyI6WyJhcGlfcmVhZCJdLCJ2ZXJzaW9uIjoxfQ.UDycv3COVFlnp6a5xEkz1RXo_lyZKw1uud9ibg2qvJA'; // Substitua pelo seu access token da TMDb

// Classe para gerenciar a atualização dos filmes
class MovieUpdater {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  // Obtém os IDs dos filmes da lista personalizada na TMDb
  Future<List<int>> fetchMovieIdsFromList(int listId) async {
    List<int> movieIds = [];
    int page = 1;
    bool hasMore = true;

    while (hasMore) {
      final response = await http.get(
        Uri.parse(
            'https://api.themoviedb.org/3/list/$listId?api_key=$tmdbApiKey&page=$page'),
        headers: {
          'Authorization': 'Bearer $tmdbAccessToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final items = data['items'] as List<dynamic>? ?? [];
        movieIds.addAll(items
            .map((item) => (item as Map<String, dynamic>)['id'] as int)
            .toList());
        hasMore = page < (data['total_pages'] as int);
        page++;
      } else {
        throw Exception(
            'Falha ao carregar a lista de filmes: ${response.statusCode}');
      }
    }
    return movieIds;
  }

  // Obtém os IDs dos filmes existentes no Firestore
  Future<Set<String>> getExistingMovieIds() async {
    final snapshot = await firestore.collection('movies').get();
    return snapshot.docs.map((doc) => doc.id).toSet();
  }

  // Atualiza o Firestore com base na lista da API
  Future<void> updateFirestore(int listId) async {
    final apiMovieIds = await fetchMovieIdsFromList(listId);
    final existingMovieIds = await getExistingMovieIds();
    final apiMovieIdsSet = apiMovieIds.map((id) => id.toString()).toSet();

    // Filmes a adicionar
    final toAdd = apiMovieIdsSet.difference(existingMovieIds);
    // Filmes a remover
    final toRemove = existingMovieIds.difference(apiMovieIdsSet);

    // Processa adições e remoções
    for (final movieId in toAdd) {
      await addMovieToFirestore(int.parse(movieId));
    }
    for (final movieId in toRemove) {
      await removeMovieFromFirestore(movieId);
    }
    print(
        'Atualização concluída: ${toAdd.length} filmes adicionados, ${toRemove.length} filmes removidos.');
  }

  // Adiciona um filme ao Firestore com detalhes e plataformas
  Future<void> addMovieToFirestore(int movieId) async {
    final details = await fetchMovieDetails(movieId);
    final platforms = await fetchPlatforms(movieId);

    // Adiciona à coleção 'movies'
    await firestore.collection('movies').doc(movieId.toString()).set({
      'title': details['title'] as String? ?? '',
      'description': details['overview'] as String? ?? '',
      'genres': (details['genres'] as List<dynamic>?)
              ?.map((g) => (g as Map<String, dynamic>)['name'] as String)
              .toList() ??
          [],
      'poster_url': details['poster_path'] != null
          ? 'https://image.tmdb.org/t/p/w500${details['poster_path']}'
          : '',
      'releaseDate': details['release_date'] as String? ?? '',
    });

    // Adiciona às plataformas ('platform_movies')
    for (final platform in platforms) {
      final docId = '${movieId}_$platform';
      await firestore.collection('platform_movies').doc(docId).set({
        'movie_id': movieId.toString(),
        'platform': platform,
      });
    }

    // Adiciona às tags ('tag_movies') usando gêneros como tags
    final genres = (details['genres'] as List<dynamic>?) ?? [];
    for (final genre in genres) {
      final genreName = (genre as Map<String, dynamic>)['name'] as String;
      final docId = '${movieId}_$genreName';
      await firestore.collection('tag_movies').doc(docId).set({
        'movie_id': movieId.toString(),
        'tag': genreName,
      });
    }
  }

  // Remove um filme e suas associações do Firestore
  Future<void> removeMovieFromFirestore(String movieId) async {
    // Remove o filme
    await firestore.collection('movies').doc(movieId).delete();

    // Remove plataformas associadas
    final platformDocs = await firestore
        .collection('platform_movies')
        .where('movie_id', isEqualTo: movieId)
        .get();
    for (final doc in platformDocs.docs) {
      await doc.reference.delete();
    }

    // Remove tags associadas
    final tagDocs = await firestore
        .collection('tag_movies')
        .where('movie_id', isEqualTo: movieId)
        .get();
    for (final doc in tagDocs.docs) {
      await doc.reference.delete();
    }
  }

  // Obtém detalhes de um filme na TMDb
  Future<Map<String, dynamic>> fetchMovieDetails(int movieId) async {
    final response = await http.get(
      Uri.parse(
          'https://api.themoviedb.org/3/movie/$movieId?language=pt-BR&api_key=$tmdbApiKey'),
    );
    if (response.statusCode == 200) {
      return json.decode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception(
          'Falha ao carregar detalhes do filme: ${response.statusCode}');
    }
  }

  // Obtém plataformas de streaming disponíveis (exemplo para Brasil)
  Future<List<String>> fetchPlatforms(int movieId) async {
    final response = await http.get(
      Uri.parse(
          'https://api.themoviedb.org/3/movie/$movieId/watch/providers?api_key=$tmdbApiKey'),
    );
    if (response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      final providers =
          (data['results']?['BR']?['flatrate'] as List<dynamic>?) ?? [];
      return providers
          .map<String>(
              (p) => (p as Map<String, dynamic>)['provider_name'].toString())
          .toList();
    } else {
      throw Exception('Falha ao carregar plataformas: ${response.statusCode}');
    }
  }
}

// Função principal para executar a atualização
Future<void> main() async {
  final updater = MovieUpdater();
  const int listId = 8499489; // Substitua pelo ID da sua lista na TMDb
  try {
    await updater.updateFirestore(listId);
  } catch (e) {
    print('Erro durante a atualização: $e');
  }
}
