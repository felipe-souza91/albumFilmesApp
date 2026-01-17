import '../services/firestore_service.dart';
import '../models/movie.dart';

class AchievementController {
  final FirestoreService firestoreService;

  AchievementController({
    required this.firestoreService,
  });

  // Configurar conquistas iniciais no Firebase
  Future<void> setupInitialAchievements() async {
    final List<Map<String, dynamic>> achievements = [
      // Conquistas por Quantidade Total de Filmes
      {
        'id': 'enthusiast',
        'name': 'Entusiasta do Cinema',
        'description':
            'Você já explorou 100 mundos cinematográficos! Continue assistindo para se tornar uma lenda.',
        'iconUrl': 'assets/icons/achievements/film_reel.png',
        'category': 'quantity',
        'ruleType': 'count',
        'ruleValue': 100,
        'ruleCriteria': {'type': 'total_movies'},
      },
      {
        'id': 'leonidas',
        'name': 'Leonidas do Cinema',
        'description':
            'ESTA É A TELA! Você conquistou 300 filmes com bravura espartana.',
        'iconUrl': 'assets/icons/achievements/shield.png',
        'category': 'quantity',
        'ruleType': 'count',
        'ruleValue': 300,
        'ruleCriteria': {'type': 'total_movies'},
      },
      {
        'id': 'marathon_master',
        'name': 'Mestre da Maratona',
        'description': '500 filmes? Você é praticamente um cinema ambulante!',
        'iconUrl': 'assets/icons/achievements/trophy.png',
        'category': 'quantity',
        'ruleType': 'count',
        'ruleValue': 500,
        'ruleCriteria': {'type': 'total_movies'},
      },
      {
        'id': 'screen_legend',
        'name': 'Lenda da Tela Grande',
        'description':
            'Mil filmes assistidos! Você é uma enciclopédia viva do cinema.',
        'iconUrl': 'assets/icons/achievements/star.png',
        'category': 'quantity',
        'ruleType': 'count',
        'ruleValue': 1000,
        'ruleCriteria': {'type': 'total_movies'},
      },

      // Conquistas por Gênero
      {
        'id': 'action_fan',
        'name': 'Adrenalina Pulsando',
        'description':
            'Explosões, perseguições e tiroteios: você domina a ação!',
        'iconUrl': 'assets/icons/achievements/grenade.png',
        'category': 'genre',
        'ruleType': 'count',
        'ruleValue': 20,
        'ruleCriteria': {'type': 'genre', 'genre': 'Ação'},
      },
      {
        'id': 'romance_lover',
        'name': 'Coração Mole',
        'description': 'Suspiros e lágrimas: o romance conquistou seu coração.',
        'iconUrl': 'assets/icons/achievements/heart.png',
        'category': 'genre',
        'ruleType': 'count',
        'ruleValue': 15,
        'ruleCriteria': {'type': 'genre', 'genre': 'Romance'},
      },
      {
        'id': 'comedy_master',
        'name': 'Mestre do Riso',
        'description':
            'Você riu até chorar com 25 comédias. Continue espalhando alegria!',
        'iconUrl': 'assets/icons/achievements/comedy_mask.png',
        'category': 'genre',
        'ruleType': 'count',
        'ruleValue': 25,
        'ruleCriteria': {'type': 'genre', 'genre': 'Comédia'},
      },
      {
        'id': 'horror_survivor',
        'name': 'Noite de Arrepios',
        'description':
            'Você enfrentou 10 sustos e sobreviveu para contar a história.',
        'iconUrl': 'assets/icons/achievements/pumpkin.png',
        'category': 'genre',
        'ruleType': 'count',
        'ruleValue': 10,
        'ruleCriteria': {'type': 'genre', 'genre': 'Terror'},
      },
      {
        'id': 'scifi_explorer',
        'name': 'Explorador de Galáxias',
        'description':
            'Você viajou por 12 universos sci-fi. Que a força esteja com você!',
        'iconUrl': 'assets/icons/achievements/spaceship.png',
        'category': 'genre',
        'ruleType': 'count',
        'ruleValue': 12,
        'ruleCriteria': {'type': 'genre', 'genre': 'Ficção científica'},
      },

      // Conquistas por Diretores ou Franquias
      {
        'id': 'tarantino_fan',
        'name': 'Discípulo de Tarantino',
        'description':
            'Diálogos afiados e sangue na tela: você é fã do mestre Tarantino.',
        'iconUrl': 'assets/icons/achievements/sunglasses.png',
        'category': 'director',
        'ruleType': 'count',
        'ruleValue': 5,
        'ruleCriteria': {'type': 'director', 'director': 'Quentin Tarantino'},
      },
      {
        'id': 'lotr_fan',
        'name': 'Caçador de Anéis',
        'description': 'Você percorreu a Terra Média e destruiu o Um Anel!',
        'iconUrl': 'assets/icons/achievements/ring.png',
        'category': 'franchise',
        'ruleType': 'collection',
        'ruleValue': 3,
        'ruleCriteria': {
          'type': 'franchise',
          'franchise': 'O Senhor dos Anéis'
        },
      },
      {
        'id': 'mad_max_fan',
        'name': 'Velocista de Mad Max',
        'description':
            'Você sobreviveu ao deserto pós-apocalíptico com estilo.',
        'iconUrl': 'assets/icons/achievements/car.png',
        'category': 'franchise',
        'ruleType': 'count',
        'ruleValue': 4,
        'ruleCriteria': {'type': 'franchise', 'franchise': 'Mad Max'},
      },

      // Conquistas por Época ou Origem
      {
        'id': '80s_nostalgia',
        'name': 'Nostalgia dos Anos 80',
        'description': 'Você voltou no tempo para os dias de neon e VHS!',
        'iconUrl': 'assets/icons/achievements/cassette.png',
        'category': 'era',
        'ruleType': 'count',
        'ruleValue': 10,
        'ruleCriteria': {'type': 'decade', 'decade': '1980'},
      },
      {
        'id': '2000s_journey',
        'name': 'Viagem ao Novo Milênio',
        'description':
            'Os anos 2000 trouxeram CGI e você aproveitou cada pixel!',
        'iconUrl': 'assets/icons/achievements/flip_phone.png',
        'category': 'era',
        'ruleType': 'count',
        'ruleValue': 20,
        'ruleCriteria': {'type': 'decade', 'decade': '2000'},
      },
      {
        'id': 'global_cinema',
        'name': 'Cinema Global',
        'description': 'Você explorou o cinema de todos os cantos do mundo.',
        'iconUrl': 'assets/icons/achievements/globe.png',
        'category': 'origin',
        'ruleType': 'countries',
        'ruleValue': 5,
        'ruleCriteria': {'type': 'countries', 'count': 5},
      },

      // Conquistas Sociais
      {
        'id': 'cinema_ambassador',
        'name': 'Embaixador do Cinema',
        'description':
            'Você está espalhando a paixão pelo cinema para o mundo!',
        'iconUrl': 'assets/icons/achievements/megaphone.png',
        'category': 'social',
        'ruleType': 'count',
        'ruleValue': 5,
        'ruleCriteria': {'type': 'shares'},
      },
      {
        'id': 'classics_curator',
        'name': 'Curador de Clássicos',
        'description':
            'Você está guiando outros com suas escolhas cinematográficas.',
        'iconUrl': 'assets/icons/achievements/list.png',
        'category': 'social',
        'ruleType': 'count',
        'ruleValue': 10,
        'ruleCriteria': {'type': 'public_list'},
      },
      {
        'id': 'born_critic',
        'name': 'Crítico Nato',
        'description': 'Suas opiniões estão moldando o futuro do cinema!',
        'iconUrl': 'assets/icons/achievements/notebook.png',
        'category': 'social',
        'ruleType': 'count',
        'ruleValue': 20,
        'ruleCriteria': {'type': 'ratings'},
      },

      // Conquistas Especiais (Desafios)
      {
        'id': 'weekend_marathon',
        'name': 'Maratona de Fim de Semana',
        'description':
            'Você transformou seu fim de semana em um festival de cinema!',
        'iconUrl': 'assets/icons/achievements/popcorn.png',
        'category': 'special',
        'ruleType': 'weekend',
        'ruleValue': 5,
        'ruleCriteria': {'type': 'weekend_movies'},
      },
      {
        'id': 'classic_rediscovered',
        'name': 'Clássico Redescoberto',
        'description':
            'Você voltou às raízes do cinema e encontrou um tesouro!',
        'iconUrl': 'assets/icons/achievements/projector.png',
        'category': 'special',
        'ruleType': 'before_year',
        'ruleValue': 1950,
        'ruleCriteria': {'type': 'before_year', 'year': 1950},
      },
      {
        'id': 'indie_explorer',
        'name': 'Explorador de Indies',
        'description': 'Você descobriu joias escondidas fora do mainstream.',
        'iconUrl': 'assets/icons/achievements/camera.png',
        'category': 'special',
        'ruleType': 'count',
        'ruleValue': 5,
        'ruleCriteria': {'type': 'indie_movies'},
      },
    ];

    await firestoreService.setupAchievements(achievements);
  }

  /// Verificar conquistas para um usuário.
  /// Retorna uma lista de IDs que foram desbloqueadas AGORA (para mostrar popup).
  Future<List<String>> checkAchievements(
    String userId,
    List<String> watchedMovieIds,
    List<Movie> watchedMovies,
  ) async {
    final newlyUnlocked = <String>[];

    Future<void> unlockIf(bool condition, String achievementId) async {
      if (!condition) return;

      // 🔥 IMPORTANTE: unlockAchievement precisa retornar bool (true = desbloqueou agora)
      final unlockedNow =
          await firestoreService.unlockAchievement(userId, achievementId);

      if (unlockedNow == true) {
        newlyUnlocked.add(achievementId);
      }
    }

    // 1) Quantidade total de filmes
    final int totalWatched = watchedMovieIds.length;

    await unlockIf(totalWatched >= 100, 'enthusiast');
    await unlockIf(totalWatched >= 300, 'leonidas');
    await unlockIf(totalWatched >= 500, 'marathon_master');
    await unlockIf(totalWatched >= 1000, 'screen_legend');

    await firestoreService.updateAchievementProgress(
        userId, 'enthusiast', totalWatched);
    await firestoreService.updateAchievementProgress(
        userId, 'leonidas', totalWatched);
    await firestoreService.updateAchievementProgress(
        userId, 'marathon_master', totalWatched);
    await firestoreService.updateAchievementProgress(
        userId, 'screen_legend', totalWatched);

    // 2) Conquistas por gênero
    final Map<String, int> genreCounts = {};

    for (final movie in watchedMovies) {
      for (final genre in movie.genres) {
        genreCounts[genre] = (genreCounts[genre] ?? 0) + 1;
      }
    }

    final int actionCount = genreCounts['Ação'] ?? 0;
    final int romanceCount = genreCounts['Romance'] ?? 0;
    final int comedyCount = genreCounts['Comédia'] ?? 0;
    final int horrorCount = genreCounts['Terror'] ?? 0;
    final int scifiCount = genreCounts['Ficção científica'] ?? 0;

    await unlockIf(actionCount >= 20, 'action_fan');
    await unlockIf(romanceCount >= 15, 'romance_lover');
    await unlockIf(comedyCount >= 25, 'comedy_master');
    await unlockIf(horrorCount >= 10, 'horror_survivor');
    await unlockIf(scifiCount >= 12, 'scifi_explorer');

    await firestoreService.updateAchievementProgress(
        userId, 'action_fan', actionCount);
    await firestoreService.updateAchievementProgress(
        userId, 'romance_lover', romanceCount);
    await firestoreService.updateAchievementProgress(
        userId, 'comedy_master', comedyCount);
    await firestoreService.updateAchievementProgress(
        userId, 'horror_survivor', horrorCount);
    await firestoreService.updateAchievementProgress(
        userId, 'scifi_explorer', scifiCount);

    // 3) Conquistas por época (décadas / clássicos)
    int count80s = 0;
    int count2000s = 0;
    int countBefore1950 = 0;

    for (final movie in watchedMovies) {
      final year = movie.releaseDate.year;
      if (year >= 1980 && year <= 1989) count80s++;
      if (year >= 2000 && year <= 2009) count2000s++;
      if (year < 1950) countBefore1950++;
    }

    await unlockIf(count80s >= 10, '80s_nostalgia');
    await firestoreService.updateAchievementProgress(
        userId, '80s_nostalgia', count80s);

    await unlockIf(count2000s >= 20, '2000s_journey');
    await firestoreService.updateAchievementProgress(
        userId, '2000s_journey', count2000s);

    // "classic_rediscovered" é antes de 1950; se quiser exigir mais que 1, ajusta aqui
    await unlockIf(countBefore1950 >= 1, 'classic_rediscovered');
    await firestoreService.updateAchievementProgress(
        userId, 'classic_rediscovered', countBefore1950);

    // TODO: global_cinema, social e outras conquistas especiais

    return newlyUnlocked;
  }
}
