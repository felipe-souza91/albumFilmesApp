// lib/admin/admin_screen.dart
import 'package:flutter/material.dart';
import 'package:album_filmes_app/services/tmdb_service.dart';
import 'package:album_filmes_app/services/firestore_service.dart';
import 'package:album_filmes_app/controllers/movie_controller.dart';
import 'package:album_filmes_app/controllers/achievement_controller.dart';

class AdminScreen extends StatefulWidget {
  @override
  _AdminScreenState createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  final String apiKey = 'f6b750ae57811b46ef095aaa96092c59';
  final String apiToken =
      'eyJhbGciOiJIUzI1NiJ9.eyJhdWQiOiJmNmI3NTBhZTU3ODExYjQ2ZWYwOTVhYWE5NjA5MmM1OSIsIm5iZiI6MTYyOTkzMTI3Ni4zMzQsInN1YiI6IjYxMjZjNzBjNWVkOTYyMDAyNjY5ZGVkYyIsInNjb3BlcyI6WyJhcGlfcmVhZCJdLCJ2ZXJzaW9uIjoxfQ.UDycv3COVFlnp6a5xEkz1RXo_lyZKw1uud9ibg2qvJA';
  final String listId = '8526195';

  bool _isLoading = false;
  String _status = '';
  int _importedCount = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Administração'),
        backgroundColor: Color(0xFF0047AB),
      ),
      body: Container(
        color: Color(0xFF0D1B2A),
        padding: EdgeInsets.all(16.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Rotina de Administração',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 20),
              Text(
                'Esta rotina importará filmes da lista TMDB para o Firebase.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white),
              ),
              SizedBox(height: 30),
              if (_isLoading)
                Column(
                  children: [
                    CircularProgressIndicator(
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Color(0xFFFFD700)),
                    ),
                    SizedBox(height: 20),
                    Text(
                      _status,
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                )
              else
                Column(
                  children: [
                    ElevatedButton(
                      onPressed: _importMovies,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFFFFD700),
                        padding:
                            EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                      ),
                      child: Text(
                        'Importar Filmes',
                        style: TextStyle(color: Color(0xFF0D1B2A)),
                      ),
                    ),
                    SizedBox(height: 20),
                    if (_importedCount > 0)
                      Text(
                        'Importação concluída! $_importedCount filmes importados.',
                        style: TextStyle(color: Colors.green),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _importMovies() async {
    setState(() {
      _isLoading = true;
      _status = 'Iniciando importação...';
    });

    try {
      // Inicializar serviços
      final tmdbService = TMDBService(
        apiKey: apiKey,
        apiToken: apiToken,
      );

      final firestoreService = FirestoreService();

      // Inicializar controladores
      final movieController = MovieController(
        tmdbService: tmdbService,
        firestoreService: firestoreService,
      );

      final achievementController = AchievementController(
        firestoreService: firestoreService,
      );

      // Importar filmes da lista TMDB para o Firebase
      setState(() {
        _status = 'Buscando filmes da lista TMDB...';
      });

      final movies = await tmdbService.getMoviesFromList(listId);

      setState(() {
        _status = 'Transformando dados para o formato do Firebase...';
      });

      final moviesData = movies.map((movieData) {
        return tmdbService.transformMovieData(movieData);
      }).toList();

      setState(() {
        _status = 'Salvando ${moviesData.length} filmes no Firebase...';
      });

      await firestoreService.addMovies(moviesData);

      setState(() {
        _status = 'Configurando conquistas iniciais...';
      });

      await achievementController.setupInitialAchievements();

      setState(() {
        _isLoading = false;
        _importedCount = moviesData.length;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _status = 'Erro: ${e.toString()}';
      });
    }
  }
}
