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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadMovies();
    });
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
        const SnackBar(
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

  /// Deriva tags de conteúdo do filme para uso no sorteio inteligente.
  /// As tags refletem intensidade/temática e são usadas pelo [PersonalizedPickerService]
  /// para ajustar o score de acordo com a tolerância de intensidade do usuário.
  Set<String> _deriveTagsFromMovie(Movie movie) {
    final tags = <String>{};
    final g = movie.genres.map((e) => e.toLowerCase()).toSet();
    final k = movie.keywords.map((e) => e.toLowerCase()).toSet();

    bool containsAny(Set<String> base, List<String> needles) {
      return base.any((v) => needles.any((n) => v.contains(n)));
    }

    if (containsAny(g, ['terror', 'horror', 'suspense', 'thriller']) ||
        containsAny(k, ['terror', 'horror', 'assustador', 'thriller'])) {
      tags.add('terror_supernatural');
    }

    // Ação e guerra = conteúdo potencialmente violento
    if (containsAny(g, ['guerra', 'war', 'crime']) ||
        containsAny(k, ['violento', 'guerra', 'crime', 'luta', 'batalha'])) {
      tags.add('violence_graphic');
    }

    if (containsAny(g, ['drama', 'biografia', 'biography']) &&
        containsAny(k, ['triste', 'tragédia', 'pesado', 'luto', 'death'])) {
      tags.add('sad_heavy');
    }

    // Tag de conteúdo família/infantil — usada pelo fator de socialMode
    if (containsAny(g, ['família', 'family', 'animação', 'animation'])) {
      tags.add('family_friendly');
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

    final movies =
        movieProvider.filteredMovies.where((m) => !m.isWatched).toList();

    if (movies.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nenhum filme disponível para sortear.')),
      );
      return;
    }

    final candidates = movies.map((m) {
      return MovieCandidate<Movie>(
        movie: m,
        title: m.title,
        releaseYear: _releaseYearFromMovie(m),
        runtimeMinutes: null, // não disponível no modelo atual
        // BUG FIX: Antes usava m.rating (estrelas do usuário, sempre 0 para
        // não-assistidos), tornando o fator de qualidade inútil.
        // Agora usa m.voteAverage (nota TMDB, 0-10), que é um sinal real de
        // qualidade cinematográfica. Filmes antigos no Firestore recebem 5.0
        // (neutro) via fallback no Movie.fromJson.
        voteAverage: m.voteAverage,
        // BUG FIX: Antes hardcoded em 0.5, cegando o fator de novelty.
        // Agora usa a popularidade normalizada salva pelo TMDBService.
        // Filmes sem o campo (importados antes da correção) recebem 0.5.
        popularityNormalized: (m as dynamic).popularityNorm ?? 0.5,
        isWatched: m.isWatched,
        isAdult: false,
        genres: m.genres.toSet(),
        tags: _deriveTagsFromMovie(m),
      );
    }).toList();

    final picked =
        PersonalizedPickerService.instance.pickMovie<Movie>(candidates, prefs);

    if (picked == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Não encontramos nenhum filme com a sua cara usando essas preferências.\n'
            'Tente ajustar o questionário ou use o sorteio simples.',
          ),
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MovieDetailsScreen(movie: picked.movie),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Color(0xFFFFD700)),
        title: const Text(
          'Meu Album',
          style: TextStyle(color: Color(0xFFFFD700)),
        ),
        backgroundColor: const Color.fromRGBO(11, 18, 34, 1.0),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: _showSearchDialog,
          ),
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
          ),
          IconButton(
            tooltip: 'Sorteio personalizado',
            icon: const Icon(Icons.auto_awesome),
            onPressed: () => _sortearFilmePersonalizado(context),
          ),
          IconButton(
            icon: const Icon(Icons.shuffle_rounded),
            onPressed: () => _sortearFilme(context),
          ),
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfileScreen()),
              );
            },
          ),
        ],
      ),
      body: Consumer<MovieProvider>(
        builder: (context, movieProvider, child) {
          if (movieProvider.isLoading) {
            return const Center(
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
                  const Text(
                    'Erro ao carregar filmes',
                    style: TextStyle(color: Colors.white, fontSize: 18),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    movieProvider.error,
                    style: const TextStyle(color: Colors.red),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadMovies,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFD700),
                    ),
                    child: const Text(
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
          final totalCount = allMovies.length;
          final watchedCount = allMovies.where((m) => m.isWatched).length;

          if (movies.isEmpty) {
            return const Center(
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
        backgroundColor: const Color(0xFFFFD700),
        child: const Icon(Icons.emoji_events, color: Color(0xFF0D1B2A)),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => const AchievementsScreen()),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        child: Stack(
          fit: StackFit.expand,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: movie.posterUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: movie.posterUrl,
                      fit: BoxFit.cover,
                      fadeInDuration: const Duration(milliseconds: 120),
                      fadeOutDuration: const Duration(milliseconds: 80),
                      memCacheWidth: 350,
                      placeholder: (context, url) => Container(
                        color: const Color.fromARGB(255, 20, 30, 50),
                        child: const Center(
                          child: Icon(Icons.local_movies,
                              color: Colors.white24, size: 30),
                        ),
                      ),
                      errorWidget: (context, url, error) => const Center(
                          child: Icon(Icons.broken_image,
                              color: Colors.white54)),
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
                      child: const Icon(Icons.movie,
                          size: 50, color: Colors.white),
                    ),
            ),
            if (!movie.isWatched)
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: const Color.fromARGB(0, 32, 32, 32),
                ),
              ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(10),
                    bottomRight: Radius.circular(10),
                  ),
                  color: Color.fromARGB(185, 0, 0, 0),
                ),
                child: Text(
                  movie.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            if (movie.isWatched)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check, color: Colors.white, size: 16),
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
          backgroundColor: const Color.fromRGBO(11, 18, 34, 1.0),
          title: const Text('Buscar Filmes',
              style: TextStyle(color: Color(0xFFFFD700))),
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
            onChanged: (value) => searchText = value,
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
              style: const ButtonStyle(
                foregroundColor:
                    WidgetStatePropertyAll<Color>(Color(0xFFFFD700)),
              ),
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFD700)),
              onPressed: () {
                setState(() => _searchQuery = searchText);
                final movieProvider =
                    Provider.of<MovieProvider>(context, listen: false);
                movieProvider
                    .setNameFilter(searchText.isEmpty ? null : searchText);
                Navigator.pop(context);
              },
              child: const Text('Buscar',
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

    final Set<String> genres = {};
    for (var movie in movies) genres.addAll(movie.genres);
    final List<String> genresList = genres.toList()..sort();

    final Set<String> platforms = {};
    for (var movie in movies) platforms.addAll(movie.platforms);
    final List<String> platformsList = platforms.toList()..sort();

    List<String> selectedGenre = _selectedGenres;
    List<String> selectedPlatform = _selectedPlatforms;
    String watchedStatus = '';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Theme(
              data: ThemeData(
                primaryColor: const Color(0xFFFFD700),
                colorScheme: ColorScheme.fromSwatch().copyWith(
                  secondary: const Color.fromRGBO(11, 18, 34, 1.0),
                ),
                textButtonTheme: TextButtonThemeData(
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFFFD700),
                  ),
                ),
              ),
              child: AlertDialog(
                backgroundColor: const Color.fromRGBO(11, 18, 34, 1.0),
                title: const Text('Filtrar Filmes',
                    style: TextStyle(color: Color(0xFFFFD700))),
                content: Scrollbar(
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Gênero',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFFFD700))),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            FilterChip(
                              showCheckmark: false,
                              labelStyle: const TextStyle(color: Colors.black),
                              selectedColor: const Color(0xFFFFD700),
                              label: const Text('Todos'),
                              selected: selectedGenre.isEmpty,
                              onSelected: (selected) {
                                setState(() => selectedGenre = []);
                              },
                            ),
                            ...genresList
                                .where((genre) => genre.trim().isNotEmpty)
                                .map((genre) {
                              return FilterChip(
                                labelStyle:
                                    const TextStyle(color: Colors.black),
                                showCheckmark: false,
                                selectedColor: const Color(0xFFFFD700),
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
                        const SizedBox(height: 16),
                        const Text('Plataforma',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFFFD700))),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            FilterChip(
                              labelStyle:
                                  const TextStyle(color: Colors.black),
                              showCheckmark: false,
                              selectedColor: const Color(0xFFFFD700),
                              label: const Text('Todas'),
                              selected: selectedPlatform.isEmpty,
                              onSelected: (_) {
                                setState(() => selectedPlatform = []);
                              },
                            ),
                            ...platformsList
                                .where(
                                    (platform) => platform.trim().isNotEmpty)
                                .map((platform) {
                              return FilterChip(
                                labelStyle:
                                    const TextStyle(color: Colors.black),
                                showCheckmark: false,
                                selectedColor: const Color(0xFFFFD700),
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
                        const SizedBox(height: 16),
                        const Text('Status de Visualização',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFFFD700))),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            FilterChip(
                              labelStyle:
                                  const TextStyle(color: Colors.black),
                              selectedColor: const Color(0xFFFFD700),
                              showCheckmark: false,
                              label: const Text('Todos'),
                              selected: watchedStatus.isEmpty,
                              onSelected: (_) {
                                setState(() => watchedStatus = '');
                              },
                            ),
                            FilterChip(
                              labelStyle:
                                  const TextStyle(color: Colors.black),
                              selectedColor: const Color(0xFFFFD700),
                              showCheckmark: false,
                              label: const Text('Assistidos'),
                              selected: watchedStatus == 'watched',
                              onSelected: (_) {
                                setState(() => watchedStatus = 'watched');
                              },
                            ),
                            FilterChip(
                              labelStyle:
                                  const TextStyle(color: Colors.black),
                              selectedColor: const Color(0xFFFFD700),
                              showCheckmark: false,
                              label: const Text('Não assistidos'),
                              selected: watchedStatus == 'not_watched',
                              onSelected: (_) {
                                setState(
                                    () => watchedStatus = 'not_watched');
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
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancelar'),
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
                    child: const Text('Limpar Filtros'),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFFD700)),
                    onPressed: () {
                      setState(() {
                        _selectedGenres = selectedGenre;
                        _selectedPlatforms = selectedPlatform;
                      });
                      movieProvider.setGenreFilter(
                          selectedGenre.isEmpty ? null : selectedGenre);
                      movieProvider.setPlatformFilter(
                          selectedPlatform.isEmpty
                              ? null
                              : selectedPlatform);
                      movieProvider.setWatchedFilter(
                          watchedStatus.isEmpty ? null : watchedStatus);
                      Navigator.pop(context);
                    },
                    child: const Text('Aplicar',
                        style: TextStyle(color: Colors.black)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
