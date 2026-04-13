// lib/views/movie_details/movie_details_screen.dart
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/movie.dart';
import '../../models/achievement.dart';
import '../../providers/movie_provider.dart';
import '../../services/firestore_service.dart';
import '../../services/config.dart';
import '../../services/ads_service.dart';
import '../../widgets/rating_stars.dart';
import '../../widgets/scratch_poster.dart';

import '../../controllers/achievement_controller.dart';
import '../achievements/achievement_unlocked_dialog.dart';

enum MovieDetailsOrigin { none, random, smart }

class MovieDetailsScreen extends StatefulWidget {
  final Movie movie;
  final MovieDetailsOrigin origin;
  final Future<Movie?> Function()? onReshuffle;

  const MovieDetailsScreen({
    super.key,
    required this.movie,
    this.origin = MovieDetailsOrigin.none,
    this.onReshuffle,
  });

  @override
  MovieDetailsScreenState createState() => MovieDetailsScreenState();
}

class MovieDetailsScreenState extends State<MovieDetailsScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  bool _isWatched = false;
  double _rating = 0.0;
  bool _isLoading = false;
  bool _isRatingSaving = false;
  bool _isReshuffling = false;

  @override
  void initState() {
    super.initState();
    _isWatched = widget.movie.isWatched;
    _rating = widget.movie.rating;

    // Preload oportunístico: aumenta a chance de o anúncio já estar pronto
    // quando o usuário concluir a ação principal desta tela.
    unawaited(_prepareInterstitial());
  }

  Future<void> _prepareInterstitial() async {
    try {
      if (!Config.adsEnabled) return;
      if (Config.admobInterstitialUnitId.isEmpty) return;

      debugPrint('[Ads][details] preparando interstitial.');
      await AdsService.instance.init();
      await AdsService.instance.preloadInterstitial(
        adUnitId: Config.admobInterstitialUnitId,
      );
    } catch (e) {
      debugPrint('[Ads][details] falha ao preparar interstitial: $e');
    }
  }

  Future<void> _showUnlockedAchievementsPopup(List<String> unlockedIds) async {
    if (unlockedIds.isEmpty || !mounted) return;

    try {
      final snap = await _firestoreService.firestore
          .collection(_firestoreService.achievementsCollection)
          .get();

      final all = snap.docs.map((d) {
        final data = d.data();
        data['id'] ??= d.id;
        return Achievement.fromJson(data);
      }).toList();

      for (final id in unlockedIds) {
        Achievement? achievement;
        try {
          achievement = all.firstWhere((a) => a.id == id);
        } catch (_) {
          achievement = null;
        }

        if (!mounted) return;
        if (achievement == null) continue;

        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => AchievementUnlockedDialog(achievement: achievement!),
        );
      }
    } catch (e) {
      debugPrint('[Achievement] erro ao mostrar popup de conquista: $e');
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

      if (!mounted) return;

      final movieProvider = Provider.of<MovieProvider>(context, listen: false);
      movieProvider.updateMovieWatchedStatus(widget.movie.id.toString(), true);
      movieProvider.updateMovieRating(widget.movie.id.toString(), _rating);

      setState(() {
        _isWatched = true;
        _isLoading = false;
      });

      // Correção importante:
      // o anúncio de "assistido" não pode mais depender do fluxo de
      // conquistas terminar. Primeiro tentamos o anúncio do evento principal;
      // depois processamos conquistas.
      unawaited(_handlePostWatchedFlow(userId));
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao marcar filme como assistido: $e')),
      );
    }
  }

  Future<void> _handlePostWatchedFlow(String userId) async {
    // Pequena folga para o Flutter concluir a pintura do novo estado da tela.
    await Future<void>.delayed(const Duration(milliseconds: 150));

    final watchedAdShown = await _tryShowInterstitial(
      reason: 'watched',
      waitForReady: const Duration(milliseconds: 1200),
    );

    final newlyUnlockedIds = await _handleAchievementUnlockFlow(userId);

    // Se o anúncio do evento "assistido" já apareceu, não tentamos um segundo
    // anúncio aqui para evitar duplicidade no mesmo fluxo.
    if (!mounted || newlyUnlockedIds.isEmpty || watchedAdShown) return;

    await Future<void>.delayed(const Duration(milliseconds: 150));
    await _tryShowInterstitial(
      reason: 'achievement_after_watched',
      waitForReady: const Duration(milliseconds: 1200),
    );
  }

  Future<List<String>> _handleAchievementUnlockFlow(String userId) async {
    try {
      final achievementController =
          AchievementController(firestoreService: _firestoreService);

      final newlyUnlockedIds =
          await achievementController.checkAchievementsForUser(userId);

      debugPrint(
        '[Achievement] conquistas desbloqueadas agora: ${newlyUnlockedIds.join(', ')}',
      );

      if (!mounted || newlyUnlockedIds.isEmpty) {
        return newlyUnlockedIds;
      }

      await _showUnlockedAchievementsPopup(newlyUnlockedIds);
      return newlyUnlockedIds;
    } catch (e) {
      debugPrint('[Achievement] falha ao reavaliar conquistas: $e');
      return const <String>[];
    }
  }

  Future<bool> _tryShowInterstitial({
    required String reason,
    Duration waitForReady = Duration.zero,
  }) async {
    try {
      if (!Config.adsEnabled) {
        debugPrint('[Ads][$reason] ads desabilitados.');
        return false;
      }
      if (Config.admobInterstitialUnitId.isEmpty) {
        debugPrint('[Ads][$reason] adUnitId vazio.');
        return false;
      }

      debugPrint(
        '[Ads][$reason] tentativa iniciada '
        '(ready=${AdsService.instance.hasInterstitialReady}).',
      );

      await AdsService.instance.init();

      if (!AdsService.instance.hasInterstitialReady) {
        await AdsService.instance.preloadInterstitial(
          adUnitId: Config.admobInterstitialUnitId,
        );
      }

      if (waitForReady > Duration.zero &&
          !AdsService.instance.hasInterstitialReady) {
        final deadline = DateTime.now().add(waitForReady);

        while (!AdsService.instance.hasInterstitialReady &&
            DateTime.now().isBefore(deadline)) {
          await Future<void>.delayed(const Duration(milliseconds: 100));
        }
      }

      final shown = await AdsService.instance.showInterstitialIfAvailable(
        adUnitId: Config.admobInterstitialUnitId,
      );

      debugPrint('[Ads][$reason] resultado da tentativa: shown=$shown.');
      return shown;
    } catch (e, stackTrace) {
      debugPrint('[Ads][$reason] excecao ao tentar exibir interstitial: $e');
      if (kDebugMode) {
        debugPrint(stackTrace.toString());
      }
      return false;
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

      if (!mounted) return;

      setState(() {
        _isWatched = false;
      });

      final movieProvider = Provider.of<MovieProvider>(context, listen: false);
      movieProvider.updateMovieWatchedStatus(widget.movie.id.toString(), false);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao marcar filme como não assistido: $e'),
          ),
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
    if (userId == null || _isRatingSaving) return;

    final previousRating = _rating;

    setState(() {
      _isRatingSaving = true;
      _rating = rating;
    });

    try {
      await _firestoreService.rateMovie(
        userId,
        widget.movie.id.toString(),
        rating,
      );

      if (!mounted) return;

      final movieProvider = Provider.of<MovieProvider>(context, listen: false);
      movieProvider.updateMovieRating(widget.movie.id.toString(), rating);

      setState(() {
        _isRatingSaving = false;
      });

      // A nota aparece imediatamente; conquista/anúncio rodam depois.
      unawaited(_handlePostRatingFlow(userId));
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isRatingSaving = false;
        _rating = previousRating;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao salvar avaliação: $e')),
      );
    }
  }

  Future<void> _handlePostRatingFlow(String userId) async {
    final newlyUnlockedIds = await _handleAchievementUnlockFlow(userId);

    if (!mounted || newlyUnlockedIds.isEmpty) return;

    await Future<void>.delayed(const Duration(milliseconds: 150));
    await _tryShowInterstitial(
      reason: 'rating_achievement',
      waitForReady: const Duration(milliseconds: 1200),
    );
  }

  Future<void> _shareViaWhatsApp() async {
    final text =
        'Acabei de assistir ${widget.movie.title} e dei ${_rating.toString()} estrelas! #MovieAlbum';
    final userId = FirebaseAuth.instance.currentUser?.uid;

    try {
      await Share.share(text, subject: 'Compartilhar via WhatsApp');
      if (userId != null) {
        await _firestoreService.incrementUserMetric(userId, 'shares');
        unawaited(_handlePostShareFlow(userId));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao compartilhar: $e')),
        );
      }
    }
  }

  Future<void> _handlePostShareFlow(String userId) async {
    final newlyUnlockedIds = await _handleAchievementUnlockFlow(userId);

    if (!mounted || newlyUnlockedIds.isEmpty) return;

    await Future<void>.delayed(const Duration(milliseconds: 150));
    await _tryShowInterstitial(
      reason: 'share_achievement',
      waitForReady: const Duration(milliseconds: 1200),
    );
  }

  /// Refaz o sorteio (aleatório ou inteligente) usando o callback fornecido
  /// pelo home_screen. Substitui a tela atual pelo novo filme sorteado.
  Future<void> _reshuffle() async {
    if (widget.onReshuffle == null || _isReshuffling) return;

    setState(() => _isReshuffling = true);

    try {
      final novoFilme = await widget.onReshuffle!();
      if (!mounted) return;

      if (novoFilme == null) {
        // onReshuffle já exibiu o SnackBar explicativo
        return;
      }

      // Substitui a tela atual em vez de empilhar uma nova
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => MovieDetailsScreen(
            movie: novoFilme,
            origin: widget.origin,
            onReshuffle: widget.onReshuffle,
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isReshuffling = false);
    }
  }

  void _showScratchDialog() {
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
    // BUG FIX: PopScope garante que o Flutter controla o gesto de voltar antes
    // que o Android aplique o efeito visual do Predictive Back (Android 13+),
    // eliminando o deslocamento lateral da tela ao pressionar o botão voltar.
    return PopScope(
      canPop: true,
      child: Scaffold(
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
                                    onRatingChanged:
                                        _isRatingSaving ? null : _rateMovie,
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
      // Quando veio de um sorteio, exibe o botão de resortear à esquerda
      // usando floatingActionButtonLocation + Stack não é necessário —
      // basta usar floatingActionButtonLocation e um Column no FAB.
      floatingActionButtonLocation: widget.origin != MovieDetailsOrigin.none
          ? FloatingActionButtonLocation.centerFloat
          : FloatingActionButtonLocation.endFloat,
      floatingActionButton: widget.origin != MovieDetailsOrigin.none
          ? Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Botão de resortear (esquerda)
                FloatingActionButton(
                  heroTag: 'reshuffle',
                  onPressed: _isReshuffling ? null : _reshuffle,
                  backgroundColor: const Color(0xFF1B263B),
                  tooltip: widget.origin == MovieDetailsOrigin.smart
                      ? 'Resortear (inteligente)'
                      : 'Resortear (aleatório)',
                  child: _isReshuffling
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFFFFD700),
                          ),
                        )
                      : Icon(
                          widget.origin == MovieDetailsOrigin.smart
                              ? Icons.auto_awesome
                              : Icons.shuffle_rounded,
                          color: const Color(0xFFFFD700),
                        ),
                ),
                const SizedBox(width: 16),
                // Botão principal (direita)
                FloatingActionButton.extended(
                  heroTag: 'watched',
                  onPressed: _isWatched ? _markAsUnwatched : _showScratchDialog,
                  backgroundColor: _isWatched
                      ? const Color.fromARGB(255, 224, 48, 30)
                      : const Color(0xFFFFD700),
                  icon: Icon(Icons.check,
                      color: _isWatched ? Colors.white : const Color(0xFF0D1B2A)),
                  label: Text(
                    _isWatched ? 'Marcar como não assistido' : 'Marcar como assistido',
                    style: TextStyle(
                        color: _isWatched ? Colors.white : const Color(0xFF0D1B2A)),
                  ),
                ),
              ],
            )
          : !_isWatched
              ? FloatingActionButton.extended(
                  heroTag: 'watched',
                  onPressed: _showScratchDialog,
                  backgroundColor: const Color(0xFFFFD700),
                  icon: const Icon(Icons.check, color: Color(0xFF0D1B2A)),
                  label: const Text(
                    'Marcar como assistido',
                    style: TextStyle(color: Color(0xFF0D1B2A)),
                  ),
                )
              : FloatingActionButton.extended(
                  heroTag: 'watched',
                  onPressed: _markAsUnwatched,
                  backgroundColor: const Color.fromARGB(255, 224, 48, 30),
                  icon: const Icon(Icons.check, color: Color(0xFF0D1B2A)),
                  label: const Text(
                    'Marcar como não assistido',
                    style: TextStyle(color: Color(0xFF0D1B2A)),
                  ),
                ),
      ), // Scaffold
    ); // PopScope
  }
}
