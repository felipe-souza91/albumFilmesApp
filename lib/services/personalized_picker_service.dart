import 'dart:math';

import '../models/user_preferences.dart';

/// Representa um filme candidato ao sorteio personalizado.
class MovieCandidate<T> {
  final T movie;

  final String title;
  final int? releaseYear;
  final int? runtimeMinutes;
  final double voteAverage;          // nota TMDB, escala 0-10
  final double popularityNormalized; // popularidade normalizada, 0-1
  final bool isWatched;
  final bool isAdult;
  final Set<String> genres;
  final Set<String> tags;

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

/// ─────────────────────────────────────────────────────────────────────────────
/// Serviço de sorteio personalizado — versão revisada.
///
/// COMO O SCORE É CALCULADO (pesos somam 1.00):
///
///  Fator               │ Peso │ Origem no questionário
/// ──────────────────────────────────────────────────────────────────────────
///  Qualidade TMDB      │ 0.13 │ vote_average do TMDB (real, não rating do user)
///  Novelty             │ 0.08 │ pergunta 7 ("descobrir coisas novas?")
///  Gênero              │ 0.37 │ gêneros favoritos / não-gostados
///  Energia             │ 0.07 │ perguntas 1-4 (cor/música → energy)
///  Profundidade        │ 0.07 │ perguntas 1-4 (cor/música → depth)
///  Conforto            │ 0.05 │ perguntas 1, 5 (cor/cansaço → comfort)
///  Nostalgia           │ 0.09 │ data de nasc. + perguntas de nostalgia
///  Intensidade         │ 0.07 │ pergunta 5 ("cansado, prefere...?") + avoidTags
///  Contexto social     │ 0.07 │ pergunta 6 ("assisto sozinho/família...?")
/// ──────────────────────────────────────────────────────────────────────────
///
/// GÊNEROS NÃO-GOSTADOS:
///  Filmes com APENAS gêneros não-gostados (sem nenhum favorito) recebem
///  um multiplicador de 0.04 sobre o score total → ~4% da probabilidade
///  de um filme neutro. Extremamente raros, mas possíveis (exploração).
/// ─────────────────────────────────────────────────────────────────────────────
class PersonalizedPickerService {
  PersonalizedPickerService._();
  static final PersonalizedPickerService instance =
      PersonalizedPickerService._();

  final _random = Random();

  // Filmes com APENAS gêneros não-gostados recebem este multiplicador.
  // 0.04 = "extremamente raro" mas não impossível → preserva exploração.
  static const double _dislikedOnlyPenalty = 0.04;

  MovieCandidate<T>? pickMovie<T>(
    List<MovieCandidate<T>> candidates,
    UserPreferences prefs, {
    bool onlyUnwatched = true,
  }) {
    if (candidates.isEmpty) return null;

    // ── Etapa 1: Hard filters (binários) ──────────────────────────────────
    final filtered = candidates.where((c) {
      if (onlyUnwatched && c.isWatched) return false;

      // Duração: descarta filmes muito além do limite do usuário
      if (c.runtimeMinutes != null &&
          c.runtimeMinutes! > prefs.maxRuntime + 20) {
        return false;
      }

      // Classificação indicativa (stub — implementar quando disponível)
      if (prefs.respectAgeRating && _isAboveUserAgeRating(c, prefs)) {
        return false;
      }

      // Tags de conteúdo explicitamente evitadas pelo usuário
      if (!prefs.avoidTags.contains('none')) {
        for (final avoided in prefs.avoidTags) {
          if (c.tags.contains(avoided)) return false;
        }
      }

      return true;
    }).toList();

    if (filtered.isEmpty) return null;

    // ── Etapa 2: Pool preferencial (gêneros favoritos têm prioridade) ─────
    // Se o usuário tem favoritos, restringe o pool a esses filmes primeiro.
    // Filmes não-gostados ficam fora deste pool, mas entram no fallback
    // com penalidade de score multiplicativa.
    final favPool =
        filtered.where((c) => _hasFavoriteGenreMatch(c, prefs)).toList();
    final pool = favPool.isNotEmpty ? favPool : filtered;

    // ── Etapa 3: Scoring ponderado ─────────────────────────────────────────
    final scores = <MovieCandidate<T>, double>{};
    double totalScore = 0;

    for (final c in pool) {
      double score = _scoreCandidate(c, prefs);

      // Penalidade multiplicativa para filmes com APENAS gêneros não-gostados.
      // O multiplier afeta o score inteiro (não só o fator de gênero),
      // garantindo que esses filmes sejam extremamente raros sem serem
      // completamente removidos — o app quer estimular exploração.
      if (prefs.dislikedGenres.isNotEmpty &&
          _hasAnyDislikedGenre(c, prefs) &&
          !_hasFavoriteGenreMatch(c, prefs)) {
        score *= _dislikedOnlyPenalty;
      }

      if (score <= 0) continue;
      scores[c] = score;
      totalScore += score;
    }

    if (scores.isEmpty || totalScore <= 0) return null;

    // ── Etapa 4: Sorteio ponderado (weighted random) ───────────────────────
    final r = _random.nextDouble() * totalScore;
    double acc = 0;
    for (final entry in scores.entries) {
      acc += entry.value;
      if (r <= acc) return entry.key;
    }

    return scores.keys.first;
  }

  // ────────────────────────────────────────────────────────────────────────────
  // SCORE PRINCIPAL
  // ────────────────────────────────────────────────────────────────────────────

  double _scoreCandidate<T>(MovieCandidate<T> c, UserPreferences prefs) {
    // 1) Qualidade: nota TMDB normalizada 0-1
    //    BUG FIX: antes usava m.rating do usuário (sempre 0 para não-assistidos),
    //    tornando este fator completamente inútil.
    final ratingNorm = (c.voteAverage / 10.0).clamp(0.0, 1.0);

    // 2) Novelty: combina popularidade real com preferência de descoberta do usuário
    //    BUG FIX: antes popularityNormalized era sempre 0.5 (hardcoded),
    //    cegando o fator de novelty.
    final pop = c.popularityNormalized.clamp(0.0, 1.0);
    final novelty = prefs.novelty.clamp(0.0, 1.0);
    // novelty alto → prefere obscuros (1-pop); novelty baixo → prefere populares (pop)
    final noveltyScore = novelty * (1.0 - pop) + (1.0 - novelty) * pop;

    // 3) Gênero: fator dominante
    final genrePrefScore = _genrePreferenceScore(c, prefs);

    // 4) Perfil psicológico (energia, profundidade, conforto)
    final movieEnergy  = _estimateMovieEnergy(c);
    final movieDepth   = _estimateMovieDepth(c);
    final movieComfort = _estimateMovieComfort(c);

    // 5) Nostalgia: alinhamento temporal com a vida do usuário
    final nostalgiaScore = _nostalgiaScore(c, prefs);

    // 6) NOVO: Intensidade — conecta intensityTolerance ao score
    //    Antes, a pergunta "filmes tensos/dramáticos quando cansado?" era derivada
    //    em intensityTolerance mas nunca usada no sorteio.
    final intensityScore = _intensityFitScore(c, prefs);

    // 7) NOVO: Contexto social — conecta socialMode ao score
    //    Antes, "assisto sozinho/família/amigos?" derivava socialMode que
    //    nunca era usado no sorteio.
    final socialScore = _socialFitScore(c, prefs);

    // Pesos (somam 1.00):
    double score = 0.0;
    score += ratingNorm      * 0.13;
    score += noveltyScore    * 0.08;
    score += genrePrefScore  * 0.37;
    score += (1 - (prefs.energy  - movieEnergy).abs())  * 0.07;
    score += (1 - (prefs.depth   - movieDepth).abs())   * 0.07;
    score += (1 - (prefs.comfort - movieComfort).abs()) * 0.05;
    score += nostalgiaScore  * 0.09;
    score += intensityScore  * 0.07;
    score += socialScore     * 0.07;

    return max(score, 0.0);
  }

  // ────────────────────────────────────────────────────────────────────────────
  // FATORES INDIVIDUAIS
  // ────────────────────────────────────────────────────────────────────────────

  /// Score de preferência de gênero (0.0 a 1.0).
  double _genrePreferenceScore<T>(MovieCandidate<T> c, UserPreferences prefs) {
    if (prefs.favoriteGenres.isEmpty && prefs.dislikedGenres.isEmpty) {
      return 0.5; // sem preferências definidas → neutro
    }

    final movieKeys    = _normalizedGenreSetFromRaw(c.genres);
    final favKeys      = _normalizedGenreSetFromRaw(prefs.favoriteGenres);
    final dislikedKeys = _normalizedGenreSetFromRaw(prefs.dislikedGenres);

    if (movieKeys.isEmpty) return 0.5;

    final favHits     = movieKeys.intersection(favKeys).length;
    final dislikedHits = movieKeys.intersection(dislikedKeys).length;
    final hasFav      = favHits > 0;
    final hasDisliked = dislikedHits > 0;

    // Só não-gostados → mínimo; penalidade multiplicativa é aplicada externamente
    if (!hasFav && hasDisliked) return 0.0;

    // Favorito puro: ótimo
    if (hasFav && !hasDisliked) {
      final favRatio = favHits / favKeys.length.clamp(1, favKeys.length);
      return (0.70 + 0.30 * favRatio).clamp(0.70, 1.0);
    }

    // Favorito + não-gostado: pondera as duas forças opostas
    if (hasFav && hasDisliked) {
      final favRatio = favHits / favKeys.length.clamp(1, favKeys.length);
      final disRatio = dislikedHits / dislikedKeys.length.clamp(1, dislikedKeys.length);
      double base = 0.40 + 0.30 * favRatio;
      base -= 0.25 * disRatio;
      return base.clamp(0.10, 0.65);
    }

    return 0.40; // gênero neutro (sem match)
  }

  /// NOVO: Alinhamento entre intensityTolerance e nível de conteúdo do filme.
  ///
  /// Conecta a pergunta 5 do questionário ("quando cansado, filmes tensos?")
  /// ao scoring. Antes, intensityTolerance era derivada mas nunca usada.
  double _intensityFitScore<T>(MovieCandidate<T> c, UserPreferences prefs) {
    final hasIntenseContent = c.tags.contains('violence_graphic') ||
        c.tags.contains('terror_supernatural') ||
        c.tags.contains('sad_heavy');

    final tolerance = prefs.intensityTolerance; // 0=muito sensível, 1=curte intensidade

    if (!hasIntenseContent) {
      // Conteúdo leve: excelente para baixa tolerância, ok para alta
      return tolerance < 0.40 ? 0.90 : 0.70;
    }

    // Conteúdo intenso: escala linear com a tolerância
    if (tolerance >= 0.70) return 0.90; // alta → ótimo
    if (tolerance >= 0.40) return 0.50; // média → neutro
    return 0.15;                         // baixa → forte penalização
  }

  /// NOVO: Alinhamento entre socialMode e tipo de conteúdo do filme.
  ///
  /// Conecta a pergunta 6 ("com quem você assiste?") ao scoring.
  /// Antes, socialMode era derivado mas completamente ignorado no sorteio.
  double _socialFitScore<T>(MovieCandidate<T> c, UserPreferences prefs) {
    final g = c.genres.map((e) => e.toLowerCase()).toSet();
    final socialMode = prefs.socialMode; // 0=família, 1=sozinho

    final isFamilyFriendly = c.tags.contains('family_friendly') ||
        g.any((s) =>
            s.contains('família') || s.contains('family') ||
            s.contains('animação') || s.contains('animation'));

    final isLightComedy =
        g.any((s) => s.contains('comédia') || s.contains('comedy'));

    final isIntense = c.tags.contains('violence_graphic') ||
        c.tags.contains('terror_supernatural');

    if (socialMode < 0.30) {
      // Modo família: fortemente prefere conteúdo seguro para todos
      if (isFamilyFriendly) return 1.00;
      if (isLightComedy)    return 0.80;
      if (isIntense)        return 0.15;
      return 0.60;
    }

    if (socialMode > 0.70) {
      // Modo solo: mais aberto a intensidade; infantil é menos atrativo
      if (isIntense)                       return 0.80;
      if (isFamilyFriendly && !isLightComedy) return 0.45;
      return 0.70;
    }

    // Modo misto (casal/amigos): equilíbrio
    if (isFamilyFriendly) return 0.70;
    if (isIntense)        return 0.60;
    return 0.65;
  }

  /// BUG FIX: Nostalgia sem double-counting.
  ///
  /// Antes, um filme da infância podia receber nostalgiaChildhood +
  /// oldMoviesAffinity * 0.4 (double-count). Agora as faixas são exclusivas.
  double _nostalgiaScore<T>(MovieCandidate<T> c, UserPreferences prefs) {
    if (prefs.birthYear == null || c.releaseYear == null) return 0.0;

    final ageAtRelease = c.releaseYear! - prefs.birthYear!;

    // Infância (0-10 anos ao lançamento)
    if (ageAtRelease >= 0 && ageAtRelease <= 10) {
      return prefs.nostalgiaChildhood;
    }

    // Adolescência (11-18 anos)
    if (ageAtRelease >= 11 && ageAtRelease <= 18) {
      return prefs.nostalgiaTeen;
    }

    // Adulto jovem (19-25 anos): leve bônus nostálgico
    if (ageAtRelease >= 19 && ageAtRelease <= 25) {
      return ((prefs.nostalgiaChildhood + prefs.nostalgiaTeen) / 2) * 0.30;
    }

    // Anterior ao nascimento = clássico
    if (ageAtRelease < 0) {
      return prefs.oldMoviesAffinity * 0.70;
    }

    return 0.0; // conteúdo recente (após os 25 anos) → sem bônus nostalgia
  }

  // ────────────────────────────────────────────────────────────────────────────
  // HELPERS DE GÊNERO
  // ────────────────────────────────────────────────────────────────────────────

  bool _hasFavoriteGenreMatch<T>(MovieCandidate<T> c, UserPreferences prefs) {
    if (prefs.favoriteGenres.isEmpty) return false;
    final movieKeys = _normalizedGenreSetFromRaw(c.genres);
    final favKeys   = _normalizedGenreSetFromRaw(prefs.favoriteGenres);
    if (movieKeys.isEmpty || favKeys.isEmpty) return false;
    return movieKeys.intersection(favKeys).isNotEmpty;
  }

  bool _hasAnyDislikedGenre<T>(MovieCandidate<T> c, UserPreferences prefs) {
    if (prefs.dislikedGenres.isEmpty) return false;
    final movieKeys    = _normalizedGenreSetFromRaw(c.genres);
    final dislikedKeys = _normalizedGenreSetFromRaw(prefs.dislikedGenres);
    if (movieKeys.isEmpty || dislikedKeys.isEmpty) return false;
    return movieKeys.intersection(dislikedKeys).isNotEmpty;
  }

  Set<String> _normalizedGenreSetFromRaw(Iterable<String> labels) {
    return labels.map(_normalizeGenreLabel).whereType<String>().toSet();
  }

  /// Normaliza rótulos de gênero (pt-BR / en) para chaves internas.
  ///
  /// BUG FIX: Drama agora mapeia para 'drama' (antes retornava null,
  /// impossibilitando marcar Drama como favorito ou não-gostado com efeito real).
  String? _normalizeGenreLabel(String raw) {
    final l = raw.toLowerCase();
    if (l.contains('ação')      || l.contains('action'))          return 'action';
    if (l.contains('ficção')    || l.contains('science fiction')
                                 || l.contains('sci-fi')
                                 || l.contains('sci fi')) {
      return 'scifi';
    }
    if (l.contains('guerra')    || l.contains('war'))              return 'war';
    if (l.contains('suspense')  || l.contains('thriller'))         return 'thriller';
    if (l.contains('terror')    || l.contains('horror'))           return 'horror';
    if (l.contains('comédia')   || l.contains('comedy'))           return 'comedy';
    // BUG FIX: drama agora reconhecido (antes retornava null)
    if (l.contains('drama'))                                        return 'drama';
    if (l.contains('romance'))                                      return 'romance';
    if (l.contains('animação')  || l.contains('animation'))        return 'animation';
    if (l.contains('fantasia')  || l.contains('fantasy'))          return 'fantasy';
    if (l.contains('família')   || l.contains('family'))           return 'family';
    if (l.contains('biografia') || l.contains('biography'))        return 'biography';
    return null; // gênero desconhecido → ignorado no scoring de preferências
  }

  // ────────────────────────────────────────────────────────────────────────────
  // ESTIMATIVAS DE PERFIL DO FILME (a partir dos gêneros)
  // ────────────────────────────────────────────────────────────────────────────

  double _estimateMovieEnergy<T>(MovieCandidate<T> c) {
    final g = c.genres.map((e) => e.toLowerCase()).toSet();
    double energy = 0.5;
    if (g.any((s) => s.contains('ação')     || s.contains('action')))   energy += 0.30;
    if (g.any((s) => s.contains('aventura') || s.contains('adventure'))) energy += 0.20;
    if (g.any((s) => s.contains('comédia')  || s.contains('comedy')
                  || s.contains('animação') || s.contains('animation'))) {
      energy += 0.15;
    }
    if (g.any((s) => s.contains('drama')    || s.contains('romance')
                  || s.contains('biografia')|| s.contains('biography'))) {
      energy -= 0.15;
    }
    if (g.any((s) => s.contains('terror')   || s.contains('horror')
                  || s.contains('suspense') || s.contains('thriller'))) {
      energy += 0.10;
    }
    return energy.clamp(0.0, 1.0);
  }

  double _estimateMovieDepth<T>(MovieCandidate<T> c) {
    final g = c.genres.map((e) => e.toLowerCase()).toSet();
    double depth = 0.5;
    if (g.any((s) => s.contains('drama')    || s.contains('biografia')
                  || s.contains('biography'))) {
      depth += 0.30;
    }
    if (g.any((s) => s.contains('ficção')   || s.contains('science fiction')
                  || s.contains('sci-fi'))) {
      depth += 0.20;
    }
    if (g.any((s) => s.contains('guerra')   || s.contains('war')))       depth += 0.15;
    if (g.any((s) => s.contains('terror')   || s.contains('horror')
                  || s.contains('suspense') || s.contains('thriller'))) {
      depth += 0.10;
    }
    if (g.any((s) => s.contains('comédia')  || s.contains('comedy')
                  || s.contains('animação') || s.contains('animation'))) {
      depth -= 0.20;
    }
    return depth.clamp(0.0, 1.0);
  }

  double _estimateMovieComfort<T>(MovieCandidate<T> c) {
    final g = c.genres.map((e) => e.toLowerCase()).toSet();
    double comfort = 0.5;
    if (g.any((s) => s.contains('comédia')  || s.contains('comedy')
                  || s.contains('animação') || s.contains('animation'))) {
      comfort += 0.20;
    }
    if (g.any((s) => s.contains('romance')))                              comfort += 0.20;
    if (g.any((s) => s.contains('família')  || s.contains('family')))    comfort += 0.15;
    if (g.any((s) => s.contains('terror')   || s.contains('horror')
                  || s.contains('suspense') || s.contains('thriller')
                  || s.contains('guerra')   || s.contains('war'))) {
      comfort -= 0.30;
    }
    return comfort.clamp(0.0, 1.0);
  }

  bool _isAboveUserAgeRating<T>(MovieCandidate<T> c, UserPreferences prefs) {
    // Stub — implementar com classificação indicativa real quando disponível
    return false;
  }
}
