// lib/views/movie_details/movie_details_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/movie.dart';
import '../../models/achievement.dart';
import '../../providers/movie_provider.dart';
import '../../services/firestore_service.dart';
import '../../widgets/rating_stars.dart';
import '../../widgets/scratch_poster.dart';

import '../../controllers/achievement_controller.dart';
import '../achievements/achievement_unlocked_dialog.dart';

class MovieDetailsScreen extends StatefulWidget {
  final Movie movie;

  const MovieDetailsScreen({
    super.key,
    required this.movie,
  });

  @override
  MovieDetailsScreenState createState() => MovieDetailsScreenState();
}

class MovieDetailsScreenState extends State<MovieDetailsScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  bool _isWatched = false;
  double _rating = 0.0;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _isWatched = widget.movie.isWatched;
    _rating = widget.movie.rating;
  }

  Future<void> _showUnlockedAchievementsPopup(List<String> unlockedIds) async {
    if (unlockedIds.isEmpty) return;
    if (!mounted) return;

    try {
      // Carrega todas as conquistas para mapear id -> Achievement
      final snap = await _firestoreService.firestore
          .collection(_firestoreService.achievementsCollection)
          .get();

      final all = snap.docs.map((d) => Achievement.fromJson(d.data())).toList();

      // Mostra um dialog por conquista desbloqueada agora
      for (final id in unlockedIds) {
        Achievement? ach;
        try {
          ach = all.firstWhere((a) => a.id == id);
        } catch (_) {
          ach = null;
        }

        if (!mounted) return;

        if (ach != null) {
          await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (_) => AchievementUnlockedDialog(achievement: ach!),
          );
        }
      }
    } catch (_) {
      // se falhar carregar conquistas, não quebra a experiência do usuário
    }
  }

  Future<void> _markAsWatched() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await _firestoreService.markMovieAsWatched(
        userId,
        widget.movie.id.toString(),
        rating: _rating,
      );

      setState(() {
        _isWatched = true;
      });

      if (!mounted) return;

      // Atualizar o provider
      final movieProvider = Provider.of<MovieProvider>(context, listen: false);
      movieProvider.updateMovieWatchedStatus(widget.movie.id.toString(), true);

      // ✅ Checar conquistas e capturar as recém-desbloqueadas
      final watchedMovies =
          movieProvider.movies.where((m) => m.isWatched).toList();
      final watchedIds = watchedMovies.map((m) => m.id.toString()).toList();

      final achievementController =
          AchievementController(firestoreService: _firestoreService);

      final newlyUnlockedIds = await achievementController.checkAchievements(
        userId,
        watchedIds,
        watchedMovies,
      );

      // Feedback padrão
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Filme marcado como assistido!')),
      );

      // 🎉 Pop-up de conquistas desbloqueadas agora
      await _showUnlockedAchievementsPopup(newlyUnlockedIds);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao marcar filme como assistido: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _markAsUnwatched() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await _firestoreService.markMovieAsUnwatched(
        userId,
        widget.movie.id.toString(),
        rating: _rating,
      );

      setState(() {
        _isWatched = false;
      });

      if (!mounted) return;

      // Atualizar o provider
      final movieProvider = Provider.of<MovieProvider>(context, listen: false);
      movieProvider.updateMovieWatchedStatus(widget.movie.id.toString(), false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Filme marcado como não assistido!')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Erro ao marcar filme como não assistido: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _rateMovie(double rating) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    setState(() {
      _isLoading = true;
      _rating = rating;
    });

    try {
      await _firestoreService.rateMovie(
        userId,
        widget.movie.id.toString(),
        rating,
      );

      if (!mounted) return;

      // Atualizar o provider
      final movieProvider = Provider.of<MovieProvider>(context, listen: false);
      movieProvider.updateMovieRating(widget.movie.id.toString(), rating);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Avaliação atualizada!')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao salvar avaliação: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _shareViaWhatsApp() async {
    final text =
        'Acabei de assistir ${widget.movie.title} e dei ${_rating.toString()} estrelas! #MovieAlbum';

    try {
      await Share.share(text, subject: 'Compartilhar via WhatsApp');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao compartilhar: $e')),
        );
      }
    }
  }

  void _showScratchDialog() {
    setState(() {});

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Raspe o pôster para marcar como assistido',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ScratchPoster(
                imageUrl: widget.movie.posterUrl,
                width: 300,
                height: 450,
                onScratchComplete: () {
                  Navigator.pop(context);
                  _markAsWatched();
                },
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFD700),
                ),
                child: const Text(
                  'Cancelar',
                  style: TextStyle(color: Colors.black),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Color(0xFFFFD700)),
        title: const Text(
          'Detalhes do Filme',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color.fromRGBO(11, 18, 34, 1.0),
        actions: [
          if (_isWatched)
            IconButton(
              icon: const Icon(Icons.share),
              onPressed: _shareViaWhatsApp,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFFD700)),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onTap: _isWatched ? null : _showScratchDialog,
                        child: Container(
                          width: 150,
                          height: 225,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black26,
                                blurRadius: 5,
                                offset: Offset(0, 3),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: widget.movie.posterUrl.isNotEmpty
                                ? Image.network(
                                    widget.movie.posterUrl,
                                    fit: BoxFit.cover,
                                    colorBlendMode: _isWatched
                                        ? BlendMode.saturation
                                        : BlendMode.color,
                                    color: _isWatched ? null : Colors.grey,
                                  )
                                : Container(
                                    color: Colors.grey,
                                    child: const Icon(
                                      Icons.movie,
                                      size: 50,
                                      color: Colors.white,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.movie.title,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Lançamento: ${widget.movie.releaseDate.year}',
                              style: const TextStyle(color: Colors.white70),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: widget.movie.genres.map((genre) {
                                return Chip(
                                  label: Text(
                                    genre,
                                    style: const TextStyle(
                                      color: Color(0xFF0D1B2A),
                                    ),
                                  ),
                                  backgroundColor: const Color(0xFFFFD700),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 16),
                            if (_isWatched)
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Sua avaliação:',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  RatingStars(
                                    rating: _rating,
                                    size: 30,
                                    onRatingChanged: _rateMovie,
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Sinopse',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.movie.description,
                    style: const TextStyle(color: Colors.white70, height: 1.5),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Disponível em',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  widget.movie.platforms.isEmpty
                      ? const Text(
                          'Informação não disponível',
                          style: TextStyle(
                            color: Colors.white70,
                            fontStyle: FontStyle.italic,
                          ),
                        )
                      : Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: widget.movie.platforms.map((platform) {
                            return Chip(
                              label: Text(
                                platform,
                                style: const TextStyle(color: Colors.white),
                              ),
                              backgroundColor: const Color(0xFF0047AB),
                            );
                          }).toList(),
                        ),
                ],
              ),
            ),
      floatingActionButton: !_isWatched
          ? FloatingActionButton.extended(
              onPressed: _showScratchDialog,
              backgroundColor: const Color(0xFFFFD700),
              icon: const Icon(Icons.check, color: Color(0xFF0D1B2A)),
              label: const Text(
                'Marcar como assistido',
                style: TextStyle(color: Color(0xFF0D1B2A)),
              ),
            )
          : FloatingActionButton.extended(
              onPressed: _markAsUnwatched,
              backgroundColor: const Color.fromARGB(255, 224, 48, 30),
              icon: const Icon(Icons.check, color: Color(0xFF0D1B2A)),
              label: const Text(
                'Marcar como não assistido',
                style: TextStyle(color: Color(0xFF0D1B2A)),
              ),
            ),
    );
  }
}
