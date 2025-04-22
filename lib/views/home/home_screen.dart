// lib/views/home/home_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/movie.dart';
import '../../providers/movie_provider.dart';
import '../../services/firestore_service.dart';
import '../movie_details/movie_details_screen.dart';
import '/profile/profile_screen.dart';
import '../achievements/achievements_screen.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  String _selectedGenre = '';
  String _selectedPlatform = '';
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadMovies();
  }

  Future<void> _loadMovies() async {
    final movieProvider = Provider.of<MovieProvider>(context, listen: false);
    await movieProvider.loadMovies(
      () => _firestoreService.getMovies(),
      () => movieProvider.getUserMovies(),
    );
  }

  void _sortearFilme(BuildContext context) {
    final movieProvider = Provider.of<MovieProvider>(context, listen: false);
    final movies =
        movieProvider.filteredMovies.where((m) => !m.isWatched).toList();

    if (movies.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Nenhum filme disponível para sortear.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final random = movies..shuffle();
    final filmeSorteado = random.first;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MovieDetailsScreen(movie: filmeSorteado),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF0D1B2A),
      appBar: AppBar(
        iconTheme: IconThemeData(color: Color(0xFFFFD700)),
        title: Text(
          'Meu Album',
          style: TextStyle(color: Color(0xFFFFD700)),
        ),
        backgroundColor: Color.fromRGBO(11, 18, 34, 1.0),
        actions: [
          IconButton(
            icon: Icon(Icons.search),
            onPressed: () {
              _showSearchDialog();
            },
          ),
          IconButton(
            icon: Icon(Icons.filter_list),
            onPressed: () {
              _showFilterDialog();
            },
          ),
          IconButton(
            icon: Icon(Icons.shuffle_rounded),
            onPressed: () {
              _sortearFilme(context);
            },
          ),
          IconButton(
            icon: Icon(Icons.person),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => ProfileScreen()),
              );
            },
          ),
        ],
      ),
      body: Consumer<MovieProvider>(
        builder: (context, movieProvider, child) {
          if (movieProvider.isLoading) {
            return Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFFD700)),
              ),
            );
          }

          if (movieProvider.error.isNotEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Erro ao carregar filmes',
                    style: TextStyle(color: Colors.white, fontSize: 18),
                  ),
                  SizedBox(height: 8),
                  Text(
                    movieProvider.error,
                    style: TextStyle(color: Colors.red),
                  ),
                  SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadMovies,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFFFFD700),
                    ),
                    child: Text(
                      'Tentar novamente',
                      style: TextStyle(color: Color(0xFF0D1B2A)),
                    ),
                  ),
                ],
              ),
            );
          }

          final movies = movieProvider.filteredMovies;

          if (movies.isEmpty) {
            return Center(
              child: Text(
                'Nenhum filme encontrado',
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
            );
          }

          return GridView.builder(
            padding: EdgeInsets.all(16),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.7,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: movies.length,
            itemBuilder: (context, index) {
              final movie = movies[index];
              return _buildMovieCard(movie);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Color(0xFFFFD700),
        child: Icon(Icons.emoji_events, color: Color(0xFF0D1B2A)),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => AchievementsScreen()),
          );
        },
      ),
    );
  }

  Widget _buildMovieCard(Movie movie) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MovieDetailsScreen(movie: movie),
          ),
        );
      },
      child: Card(
        elevation: 5,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Poster
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: movie.posterUrl.isNotEmpty
                  ? Image.network(
                      movie.posterUrl,
                      fit: BoxFit.cover,
                      colorBlendMode: movie.isWatched
                          ? BlendMode.saturation
                          : BlendMode.color,
                      color: movie.isWatched ? null : Colors.grey,
                    )
                  : Container(
                      color: Colors.grey,
                      child: Icon(Icons.movie, size: 50, color: Colors.white),
                    ),
            ),

            // Overlay para filmes não assistidos
            if (!movie.isWatched)
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: Colors.black.withOpacity(0.5),
                ),
                child: Center(
                  child: Text(
                    'Toque para assistir',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),

            // Título do filme
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(10),
                    bottomRight: Radius.circular(10),
                  ),
                  color: Colors.black.withOpacity(0.7),
                ),
                child: Text(
                  movie.title,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
            ),

            // Indicador de filme assistido
            if (movie.isWatched)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.check,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showSearchDialog() {
    showDialog(
      context: context,
      builder: (context) {
        String searchText = _searchQuery;

        return AlertDialog(
          backgroundColor: Color.fromRGBO(11, 18, 34, 1.0),
          title:
              Text('Buscar Filmes', style: TextStyle(color: Color(0xFFFFD700))),
          content: TextField(
            onChanged: (value) {
              searchText = value;
            },
            decoration: InputDecoration(
              hintText: 'Digite o nome do filme',
              prefixIcon: Icon(Icons.search),
            ),
          ),
          actions: [
            TextButton(
              style: ButtonStyle(
                foregroundColor: MaterialStateProperty.all<Color>(Colors.white),
              ),
              onPressed: () {
                Navigator.pop(context);
              },
              child:
                  Text('Cancelar', style: TextStyle(color: Color(0xFFFFD700))),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFFFFD700),
              ),
              onPressed: () {
                setState(() {
                  _searchQuery = searchText;
                });

                final movieProvider =
                    Provider.of<MovieProvider>(context, listen: false);
                movieProvider
                    .setNameFilter(searchText.isEmpty ? null : searchText);

                Navigator.pop(context);
              },
              child: Text('Buscar',
                  style: TextStyle(color: Color.fromRGBO(11, 18, 34, 1.0))),
            ),
          ],
        );
      },
    );
  }

  void _showFilterDialog() {
    final movieProvider = Provider.of<MovieProvider>(context, listen: false);
    final movies = movieProvider.movies;

    // Extrair gêneros únicos
    final Set<String> genres = {};
    for (var movie in movies) {
      genres.addAll(movie.genres);
    }
    final List<String> genresList = genres.toList()..sort();

    // Extrair plataformas únicas
    final Set<String> platforms = {};
    for (var movie in movies) {
      platforms.addAll(movie.platforms);
    }
    final List<String> platformsList = platforms.toList()..sort();

    String selectedGenre = _selectedGenre;
    String selectedPlatform = _selectedPlatform;
    String watchedStatus = ''; // '', 'watched', 'not_watched'

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Theme(
                data: ThemeData(
                  primaryColor: Color(0xFFFFD700),
                  colorScheme: ColorScheme.fromSwatch().copyWith(
                    secondary: Color.fromRGBO(11, 18, 34, 1.0),
                  ),
                  textButtonTheme: TextButtonThemeData(
                    style: TextButton.styleFrom(
                      foregroundColor: Color(0xFFFFD700),
                    ),
                  ),
                ),
                child: AlertDialog(
                  backgroundColor: Color.fromRGBO(11, 18, 34, 1.0),
                  title: Text('Filtrar Filmes',
                      style: TextStyle(color: Color(0xFFFFD700))),
                  content: Scrollbar(
                    thumbVisibility: true,
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Gênero',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFFFD700)),
                          ),
                          SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              FilterChip(
                                showCheckmark: false,
                                labelStyle: TextStyle(color: Colors.black),
                                selectedColor: Color(0xFFFFD700),
                                label: Text('Todos'),
                                selected: selectedGenre.isEmpty,
                                onSelected: (selected) {
                                  setState(() {
                                    selectedGenre = '';
                                  });
                                },
                              ),
                              ...genresList
                                  .where((genre) => genre.trim().isNotEmpty)
                                  .map((genre) {
                                return FilterChip(
                                  labelStyle: TextStyle(color: Colors.black),
                                  showCheckmark: false,
                                  selectedColor: Color(0xFFFFD700),
                                  label: Text(genre),
                                  selected: selectedGenre == genre,
                                  onSelected: (selected) {
                                    setState(() {
                                      selectedGenre = selected ? genre : '';
                                    });
                                  },
                                );
                              }),
                            ],
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Plataforma',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFFFD700)),
                          ),
                          SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              FilterChip(
                                labelStyle: TextStyle(color: Colors.black),
                                showCheckmark: false,
                                selectedColor: Color(0xFFFFD700),
                                label: Text('Todas'),
                                selected: selectedPlatform.isEmpty,
                                onSelected: (selected) {
                                  setState(() {
                                    selectedPlatform = '';
                                  });
                                },
                              ),
                              ...platformsList
                                  .where(
                                      (platform) => platform.trim().isNotEmpty)
                                  .map((platform) {
                                return FilterChip(
                                  labelStyle: TextStyle(color: Colors.black),
                                  showCheckmark: false,
                                  selectedColor: Color(0xFFFFD700),
                                  label: Text(platform),
                                  selected: selectedPlatform == platform,
                                  onSelected: (selected) {
                                    setState(() {
                                      selectedPlatform =
                                          selected ? platform : '';
                                    });
                                  },
                                );
                              }).toList(),
                            ],
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Status de Visualização',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFFFD700)),
                          ),
                          SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              FilterChip(
                                labelStyle: TextStyle(color: Colors.black),
                                selectedColor: Color(0xFFFFD700),
                                showCheckmark: false,
                                label: Text('Todos'),
                                selected: watchedStatus.isEmpty,
                                onSelected: (selected) {
                                  setState(() {
                                    watchedStatus = '';
                                  });
                                },
                              ),
                              FilterChip(
                                labelStyle: TextStyle(color: Colors.black),
                                selectedColor: Color(0xFFFFD700),
                                showCheckmark: false,
                                label: Text('Assistidos'),
                                selected: watchedStatus == 'watched',
                                onSelected: (selected) {
                                  setState(() {
                                    watchedStatus = 'watched';
                                  });
                                },
                              ),
                              FilterChip(
                                labelStyle: TextStyle(color: Colors.black),
                                selectedColor: Color(0xFFFFD700),
                                showCheckmark: false,
                                label: Text('Não assistidos'),
                                selected: watchedStatus == 'not_watched',
                                onSelected: (selected) {
                                  setState(() {
                                    watchedStatus = 'not_watched';
                                  });
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      child: Text('Cancelar'),
                    ),
                    TextButton(
                      onPressed: () {
                        movieProvider.clearFilters();
                        setState(() {
                          _selectedGenre = '';
                          _selectedPlatform = '';
                        });
                        Navigator.pop(context);
                      },
                      child: Text('Limpar Filtros'),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFFFFD700),
                      ),
                      onPressed: () {
                        setState(() {
                          _selectedGenre = selectedGenre;
                          _selectedPlatform = selectedPlatform;
                        });

                        movieProvider.setGenreFilter(
                            selectedGenre.isEmpty ? null : selectedGenre);
                        movieProvider.setPlatformFilter(
                            selectedPlatform.isEmpty ? null : selectedPlatform);
                        movieProvider.setWatchedFilter(
                            watchedStatus.isEmpty ? null : watchedStatus);

                        Navigator.pop(context);
                      },
                      child: Text(
                        'Aplicar',
                        style: TextStyle(color: Colors.black),
                      ),
                    ),
                  ],
                ));
          },
        );
      },
    );
  }
}
