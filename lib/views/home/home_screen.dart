// lib/views/home/home_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/movie.dart';
import '../../providers/movie_provider.dart';
import '../../services/firestore_service.dart';
import '../movie_details/movie_details_screen.dart';
import '/profile/profile_screen.dart';
import '../achievements/achievements_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../services/user_preferences_service.dart';
import '../../services/personalized_picker_service.dart';
import '../../models/user_preferences.dart';
import '../../services/personalized_picker_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  HomeScreenState createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  final FirestoreService _firestoreService = FirestoreService();

  List<String> _selectedGenres = [];
  List<String> _selectedPlatforms = [];
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

  Set<String> _deriveTagsFromMovie(Movie movie) {
    final tags = <String>{};
    final g = movie.genres.map((e) => e.toLowerCase()).toSet();
    final k = movie.keywords.map((e) => e.toLowerCase()).toSet();

    bool containsAny(Set<String> base, List<String> needles) {
      return base.any((v) => needles.any((n) => v.contains(n)));
    }

    // Terror / suspense
    if (containsAny(g, ['terror', 'horror', 'suspense', 'thriller']) ||
        containsAny(k, ['terror', 'horror', 'assustador', 'thriller'])) {
      tags.add('terror_supernatural');
    }

    // Violência / guerra / crime
    if (containsAny(g, ['guerra', 'war', 'crime', 'ação', 'action']) ||
        containsAny(k, ['violento', 'guerra', 'crime', 'luta'])) {
      tags.add('violence_graphic');
    }

    // Dramas bem pesados
    if (containsAny(g, ['drama', 'biografia', 'biography']) &&
        containsAny(k, ['triste', 'tragédia', 'pesado', 'luto'])) {
      tags.add('sad_heavy');
    }

    return tags;
  }

  int? _releaseYearFromMovie(Movie movie) {
    try {
      return movie.releaseDate.year;
    } catch (_) {
      return null;
    }
  }

  Future<void> _sortearFilmePersonalizado(BuildContext context) async {
    final movieProvider = Provider.of<MovieProvider>(context, listen: false);

    // 1) Carrega preferências do usuário
    final prefs =
        await UserPreferencesService.instance.getCurrentUserPreferences();

    if (prefs == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Antes, responda o questionário de preferências em Perfil > Preferências 😉',
          ),
        ),
      );
      return;
    }

    // 2) Pega a lista de filmes filtrados (igual à usada na tela)
    final movies =
        movieProvider.filteredMovies.where((m) => !m.isWatched).toList();

    if (movies.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nenhum filme disponível para sortear.'),
        ),
      );
      return;
    }

    // Como não temos popularidade nem runtime, vamos aproximar:
    // - voteAverage: usar movie.rating (assumindo 0..10)
    // - popularityNormalized: usar 0.5 para todos por enquanto.
    double normPop(Movie m) => 0.5;

    final candidates = movies.map((m) {
      return MovieCandidate<Movie>(
        movie: m,
        title: m.title,
        releaseYear: _releaseYearFromMovie(m),
        runtimeMinutes: null, // não temos duração no modelo ainda
        voteAverage: m.rating.clamp(0.0, 10.0),
        popularityNormalized: normPop(m),
        isWatched: m.isWatched,
        isAdult: false, // se um dia tiver flag +18, ajusta aqui
        genres: m.genres.toSet(),
        tags: _deriveTagsFromMovie(m),
      );
    }).toList();

    // 3) Usa o serviço de sorteio personalizado
    final picked =
        PersonalizedPickerService.instance.pickMovie<Movie>(candidates, prefs);

    if (picked == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Não encontramos nenhum filme com a sua cara usando essas preferências.\nTente ajustar o questionário ou usar o sorteio simples.',
          ),
        ),
      );
      return;
    }

    final filmeSorteado = picked.movie;

    // 4) Abre a tela de detalhes do filme sorteado
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
            tooltip: 'Sorteio personalizado',
            icon: const Icon(Icons.auto_awesome),
            onPressed: () {
              _sortearFilmePersonalizado(context);
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
          final allMovies = movieProvider.movies;

// total de filmes carregados
          final totalCount = allMovies.length;

// quantos assistidos (olhando sempre a lista completa, não só filtrada)
          final watchedCount = allMovies.where((m) => m.isWatched).length;

          if (movies.isEmpty) {
            return Center(
              child: Text(
                'Nenhum filme encontrado',
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (totalCount > 0)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Text(
                    '$watchedCount / $totalCount filmes assistidos',
                    style: const TextStyle(
                      color: Color(0xFFFFD700),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              const SizedBox(height: 4),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
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
                ),
              ),
            ],
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
                  ? CachedNetworkImage(
                      imageUrl: movie.posterUrl,
                      fit: BoxFit.cover,

                      // ✅ “parece mais rápido”
                      fadeInDuration: const Duration(milliseconds: 120),
                      fadeOutDuration: const Duration(milliseconds: 80),

                      // ✅ carrega uma imagem menor (grid 2 colunas)
                      // ajuste fino: 350 costuma ficar bom pra poster em grid
                      memCacheWidth: 350,

                      // ✅ placeholder bem mais leve
                      placeholder: (context, url) => Container(
                        color: const Color.fromARGB(255, 20, 30, 50),
                        child: const Center(
                          child: Icon(Icons.local_movies,
                              color: Colors.white24, size: 30),
                        ),
                      ),

                      errorWidget: (context, url, error) => const Center(
                          child:
                              Icon(Icons.broken_image, color: Colors.white54)),

                      // ✅ render mais leve
                      filterQuality: FilterQuality.low,

                      colorBlendMode: movie.isWatched
                          ? BlendMode.saturation
                          : BlendMode.color,
                      color: movie.isWatched
                          ? null
                          : const Color.fromARGB(255, 53, 53, 53),
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
                  color: const Color.fromARGB(0, 32, 32, 32),
                ),
                /*child: Center(
                  child: Text(
                    'Toque para assistir',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      shadows: const [
                        Shadow(
                          color: Colors.black,
                          offset: Offset(1, 1),
                          blurRadius: 2,
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),*/
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
                  color: const Color.fromARGB(185, 0, 0, 0),
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
            textInputAction: TextInputAction.search,
            onSubmitted: (_) {
              setState(() => _searchQuery = searchText);
              final movieProvider =
                  Provider.of<MovieProvider>(context, listen: false);
              movieProvider
                  .setNameFilter(searchText.isEmpty ? null : searchText);
              Navigator.pop(context);
            },
            onChanged: (value) {
              searchText = value;
            },
            style: const TextStyle(color: Color(0xFFFFD700)),
            cursorColor: const Color(0xFFFFD700),
            decoration: InputDecoration(
              hintText: 'Digite o nome do filme',
              hintStyle: const TextStyle(color: Colors.white54),
              prefixIcon: const Icon(Icons.search, color: Color(0xFFFFD700)),
              filled: true,
              fillColor: Colors.white10,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Colors.white24),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide:
                    const BorderSide(color: Color(0xFFFFD700), width: 2),
              ),
            ),
          ),
          actions: [
            TextButton(
              style: ButtonStyle(
                foregroundColor: WidgetStatePropertyAll<Color>(Colors.grey),
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

    List<String> selectedGenre = _selectedGenres;
    List<String> selectedPlatform = _selectedPlatforms;
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
                                    selectedGenre = [];
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
                                  selected: selectedGenre.contains(genre),
                                  onSelected: (selected) {
                                    setState(() {
                                      if (selected) {
                                        _selectedGenres.add(genre);
                                      } else {
                                        _selectedGenres.remove(genre);
                                      }
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
                                    selectedPlatform = [];
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
                                  selected: selectedPlatform.contains(platform),
                                  onSelected: (selected) {
                                    setState(() {
                                      if (selected) {
                                        _selectedPlatforms.add(platform);
                                      } else {
                                        _selectedPlatforms.remove(platform);
                                      }
                                    });
                                  },
                                );
                              }),
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
                          _selectedGenres = [];
                          _selectedPlatforms = [];
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
                          _selectedGenres = selectedGenre;
                          _selectedPlatforms = selectedPlatform;
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
