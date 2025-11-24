import 'dart:math';

import '../models/user_preferences.dart';

/// Representa um filme candidato ao sorteio personalizado.
/// T é o tipo real do seu modelo de filme (ex.: Movie).
class MovieCandidate<T> {
  final T movie;

  final String title;
  final int? releaseYear; // ex.: 1999
  final int? runtimeMinutes; // ex.: 120
  final double voteAverage; // 0..10
  final double popularityNormalized; // 0..1
  final bool isWatched;
  final bool isAdult;
  final Set<String> genres; // ex.: {"Drama", "Comédia"}
  final Set<String> tags; // ex.: {"violence_graphic"}

  MovieCandidate({
    required this.movie,
    required this.title,
    required this.releaseYear,
    required this.runtimeMinutes,
    required this.voteAverage,
    required this.popularityNormalized,
    required this.isWatched,
    required this.isAdult,
    required this.genres,
    required this.tags,
  });
}

class PersonalizedPickerService {
  PersonalizedPickerService._();
  static final PersonalizedPickerService instance =
      PersonalizedPickerService._();

  final _random = Random();

  MovieCandidate<T>? pickMovie<T>(
    List<MovieCandidate<T>> candidates,
    UserPreferences prefs, {
    bool onlyUnwatched = true,
  }) {
    if (candidates.isEmpty) return null;

    // 1) Filtra por assistidos, duração, classificação indicativa e gêneros NÃO gostados
    final filtered = candidates.where((c) {
      if (onlyUnwatched && c.isWatched) return false;

      // Duração
      if (c.runtimeMinutes != null &&
          c.runtimeMinutes! > prefs.maxRuntime + 20) {
        return false;
      }

      // Classificação indicativa (stub por enquanto)
      if (prefs.respectAgeRating && _isAboveUserAgeRating(c, prefs)) {
        return false;
      }

      // 🔹 Filtro forte: se tem gênero marcado como "não gosto", descarta
      /*if (_hasDislikedGenreMatch(c, prefs)) {
        return false;
      }*/

      // Tags de conteúdo (violência gráfica, etc)
      if (!prefs.avoidTags.contains('none')) {
        for (final avoided in prefs.avoidTags) {
          if (c.tags.contains(avoided)) {
            return false;
          }
        }
      }

      return true;
    }).toList();

    if (filtered.isEmpty) return null;

    // 2) Se possível, sorteia apenas entre filmes que batem em ALGUM gênero favorito
    final favPool =
        filtered.where((c) => _hasFavoriteGenreMatch(c, prefs)).toList();
    final pool = favPool.isNotEmpty ? favPool : filtered;

    if (pool.isEmpty) return null;

    // 3) Calcula score e sorteia ponderado
    final scores = <MovieCandidate<T>, double>{};
    double totalScore = 0;

    for (final c in pool) {
      final score = _scoreCandidate(c, prefs);
      if (score <= 0) continue;
      scores[c] = score;
      totalScore += score;
    }

    if (scores.isEmpty || totalScore <= 0) return null;

    final r = _random.nextDouble() * totalScore;
    double acc = 0;
    for (final entry in scores.entries) {
      acc += entry.value;
      if (r <= acc) {
        return entry.key;
      }
    }

    return scores.keys.first;
  }

  bool _hasFavoriteGenreMatch<T>(
    MovieCandidate<T> c,
    UserPreferences prefs,
  ) {
    if (prefs.favoriteGenres.isEmpty) return false;

    final movieKeys = _normalizedGenreSetFromRaw(c.genres);
    final favKeys = _normalizedGenreSetFromRaw(prefs.favoriteGenres);

    if (movieKeys.isEmpty || favKeys.isEmpty) return false;

    return movieKeys.intersection(favKeys).isNotEmpty;
  }

  bool _hasDislikedGenreMatch<T>(
    MovieCandidate<T> c,
    UserPreferences prefs,
  ) {
    if (prefs.dislikedGenres.isEmpty) return false;

    final movieKeys = _normalizedGenreSetFromRaw(c.genres);
    final dislikedKeys = _normalizedGenreSetFromRaw(prefs.dislikedGenres);

    if (movieKeys.isEmpty || dislikedKeys.isEmpty) return false;

    return movieKeys.intersection(dislikedKeys).isNotEmpty;
  }

  Set<String> _normalizedGenreSetFromRaw(Iterable<String> labels) {
    return labels.map(_normalizeGenreLabel).whereType<String>().toSet();
  }

  double _scoreCandidate<T>(
    MovieCandidate<T> c,
    UserPreferences prefs,
  ) {
    double score = 0.0;

    // 1) Qualidade e popularidade/novidade
    final ratingNorm = (c.voteAverage / 10.0).clamp(0.0, 1.0);
    final pop = c.popularityNormalized.clamp(0.0, 1.0);
    final novelty = prefs.novelty.clamp(0.0, 1.0);
    final noveltyScore = novelty * (1.0 - pop) + (1.0 - novelty) * pop;

    // Preferência de gênero (favoritos / não gosto)
    final genrePrefScore = _genrePreferenceScore(c, prefs);

    // 1) Base em qualidade + popularidade/novidade
    score += ratingNorm * 0.20;
    score += noveltyScore * 0.10;

    // 2) Gêneros favoritos / evitados (peso dominante)
    score += genrePrefScore * 0.40;

    // 3) Energia / profundidade / conforto (peso moderado)
    final movieEnergy = _estimateMovieEnergy(c);
    final movieDepth = _estimateMovieDepth(c);
    final movieComfort = _estimateMovieComfort(c);

    score += (1 - (prefs.energy - movieEnergy).abs()) * 0.08;
    score += (1 - (prefs.depth - movieDepth).abs()) * 0.08;
    score += (1 - (prefs.comfort - movieComfort).abs()) * 0.04;

    // 4) Nostalgia (peso relevante, mas menor que gênero)
    score += _nostalgiaScore(c, prefs) * 0.10;

    return max(score, 0.0);
  }

  double _genrePreferenceScore<T>(
    MovieCandidate<T> c,
    UserPreferences prefs,
  ) {
    // Se o usuário não marcou nada, neutro
    if (prefs.favoriteGenres.isEmpty && prefs.dislikedGenres.isEmpty) {
      return 0.5;
    }

    final movieKeys = _normalizedGenreSetFromRaw(c.genres);
    final favKeys = _normalizedGenreSetFromRaw(prefs.favoriteGenres);
    final dislikedKeys = _normalizedGenreSetFromRaw(prefs.dislikedGenres);

    if (movieKeys.isEmpty) {
      return 0.5;
    }

    final favHits = movieKeys.intersection(favKeys).length;
    final dislikedHits = movieKeys.intersection(dislikedKeys).length;

    final hasFav = favHits > 0;
    final hasDisliked = dislikedHits > 0;

    // Caso 1: só gêneros não-gostados (nenhum favorito)
    if (!hasFav && hasDisliked) {
      // Bem perto de zero, mas não zero absoluto → chance mínima
      return 0.05;
    }

    // Caso 2: tem favoritos e NÃO tem não-gostados
    if (hasFav && !hasDisliked) {
      final favRatio = favHits / favKeys.length.clamp(1, favKeys.length);
      // 0.7..1.0
      return (0.7 + 0.3 * favRatio).clamp(0.7, 1.0);
    }

    // Caso 3: tem favoritos E também gêneros que não gosta
    if (hasFav && hasDisliked) {
      final favRatio = favHits / favKeys.length.clamp(1, favKeys.length);
      final disRatio =
          dislikedHits / dislikedKeys.length.clamp(1, dislikedKeys.length);

      // Começa em algo em torno de 0.4..0.7, mas penaliza pelos não-gostados
      double base = 0.4 + 0.3 * favRatio;
      base -= 0.3 * disRatio;
      return base.clamp(0.1, 0.6);
    }

    // Caso 4: não bate nem favorito, nem não-gosto
    return 0.4; // meio "ok", mas perde para quem bate favoritos
  }

  /// Converte rótulos de gênero variados (português/inglês) em chaves internas.
  /// Exemplo: "Ação", "Action" -> "action"
  String? _normalizeGenreLabel(String raw) {
    final l = raw.toLowerCase();

    if (l.contains('ação') || l.contains('action')) {
      return 'action';
    }
    if (l.contains('ficção') ||
        l.contains('science fiction') ||
        l.contains('sci-fi') ||
        l.contains('sci fi')) {
      return 'scifi';
    }
    if (l.contains('guerra') || l.contains('war')) {
      return 'war';
    }
    if (l.contains('suspense') || l.contains('thriller')) {
      return 'thriller';
    }
    if (l.contains('terror') || l.contains('horror')) {
      return 'horror';
    }
    if (l.contains('comédia') || l.contains('comedy')) {
      return 'comedy';
    }
    if (l.contains('drama')) {
      return null;
    }
    if (l.contains('romance')) {
      return 'romance';
    }
    if (l.contains('animação') || l.contains('animation')) {
      return 'animation';
    }
    if (l.contains('fantasia') || l.contains('fantasy')) {
      return 'fantasy';
    }
    if (l.contains('família') || l.contains('family')) {
      return 'family';
    }
    if (l.contains('biografia') || l.contains('biography')) {
      return 'biography';
    }

    return null;
  }

  bool _isAboveUserAgeRating<T>(
    MovieCandidate<T> c,
    UserPreferences prefs,
  ) {
    // Quando tiver classificação indicativa real, implemente aqui.
    return false;
  }

  double _estimateMovieEnergy<T>(MovieCandidate<T> c) {
    final g = c.genres.map((e) => e.toLowerCase()).toSet();
    double energy = 0.5;
    if (g.any((g) => g.contains('ação') || g.contains('action'))) {
      energy += 0.3;
    }
    if (g.any((g) => g.contains('aventura') || g.contains('adventure'))) {
      energy += 0.2;
    }
    if (g.any((g) =>
        g.contains('comédia') ||
        g.contains('comedy') ||
        g.contains('animação') ||
        g.contains('animation'))) {
      energy += 0.2;
    }
    if (g.any((g) =>
        g.contains('drama') ||
        g.contains('romance') ||
        g.contains('biografia') ||
        g.contains('biography'))) {
      energy -= 0.1;
    }
    if (g.any((g) =>
        g.contains('terror') ||
        g.contains('horror') ||
        g.contains('suspense') ||
        g.contains('thriller'))) {
      energy += 0.1;
    }
    return energy.clamp(0.0, 1.0);
  }

  double _estimateMovieDepth<T>(MovieCandidate<T> c) {
    final g = c.genres.map((e) => e.toLowerCase()).toSet();
    double depth = 0.5;
    if (g.any((g) =>
        g.contains('drama') ||
        g.contains('biografia') ||
        g.contains('biography'))) {
      depth += 0.3;
    }
    if (g.any((g) =>
        g.contains('ficção científica') ||
        g.contains('science fiction') ||
        g.contains('sci-fi'))) {
      depth += 0.2;
    }
    if (g.any((g) =>
        g.contains('terror') ||
        g.contains('horror') ||
        g.contains('suspense') ||
        g.contains('thriller'))) {
      depth += 0.1;
    }
    if (g.any((g) =>
        g.contains('comédia') ||
        g.contains('comedy') ||
        g.contains('animação') ||
        g.contains('animation'))) {
      depth -= 0.2;
    }
    return depth.clamp(0.0, 1.0);
  }

  double _estimateMovieComfort<T>(MovieCandidate<T> c) {
    final g = c.genres.map((e) => e.toLowerCase()).toSet();
    double comfort = 0.5;
    if (g.any((g) =>
        g.contains('comédia') ||
        g.contains('comedy') ||
        g.contains('animação') ||
        g.contains('animation'))) {
      comfort += 0.15;
    }
    if (g.any((g) => g.contains('romance'))) {
      comfort += 0.2;
    }
    if (g.any((g) =>
        g.contains('terror') ||
        g.contains('horror') ||
        g.contains('suspense') ||
        g.contains('thriller') ||
        g.contains('guerra') ||
        g.contains('war'))) {
      comfort -= 0.3;
    }
    return comfort.clamp(0.0, 1.0);
  }

  double _nostalgiaScore<T>(
    MovieCandidate<T> c,
    UserPreferences prefs,
  ) {
    if (prefs.birthYear == null || c.releaseYear == null) return 0.0;

    final year = c.releaseYear!;
    final birthYear = prefs.birthYear!;
    final ageAtRelease = year - birthYear;

    double nostalgia = 0.0;

    if (ageAtRelease >= 0 && ageAtRelease <= 10) {
      nostalgia += prefs.nostalgiaChildhood;
    } else if (ageAtRelease >= 11 && ageAtRelease <= 18) {
      nostalgia += prefs.nostalgiaTeen;
    }

    if (ageAtRelease < 0) {
      nostalgia += prefs.oldMoviesAffinity * 0.8;
    }

    final nowYear = DateTime.now().year;
    final ageNow = nowYear - birthYear;
    final yearsDiff = ageNow - ageAtRelease;
    if (yearsDiff >= 20) {
      nostalgia += prefs.oldMoviesAffinity * 0.4;
    }

    return nostalgia.clamp(0.0, 1.0);
  }
}
