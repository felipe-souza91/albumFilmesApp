// lib/controllers/achievement_controller.dart
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
        'ruleValue': 15,
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

    try {
      await firestoreService.setupAchievements(achievements);
      //print('Successfully set up ${achievements.length} achievements in Firebase');
    } catch (e) {
      //print('Error setting up achievements: $e');
      rethrow;
    }
  }

  // Verificar conquistas para um usuário
  Future<void> checkAchievements(String userId, List<String> watchedMovieIds,
      List<Movie> watchedMovies) async {
    try {
      // Verificar conquistas por quantidade total de filmes
      final int totalWatched = watchedMovieIds.length;

      if (totalWatched >= 100) {
        await firestoreService.unlockAchievement(userId, 'enthusiast');
      }

      if (totalWatched >= 300) {
        await firestoreService.unlockAchievement(userId, 'leonidas');
      }

      if (totalWatched >= 500) {
        await firestoreService.unlockAchievement(userId, 'marathon_master');
      }

      if (totalWatched >= 1000) {
        await firestoreService.unlockAchievement(userId, 'screen_legend');
      }

      // Atualizar progresso para conquistas não desbloqueadas
      await firestoreService.updateAchievementProgress(
          userId, 'enthusiast', totalWatched);
      await firestoreService.updateAchievementProgress(
          userId, 'leonidas', totalWatched);
      await firestoreService.updateAchievementProgress(
          userId, 'marathon_master', totalWatched);
      await firestoreService.updateAchievementProgress(
          userId, 'screen_legend', totalWatched);

      // Verificar conquistas por gênero
      final Map<String, int> genreCounts = {};

      for (var movie in watchedMovies) {
        for (var genre in movie.genres) {
          genreCounts[genre] = (genreCounts[genre] ?? 0) + 1;
        }
      }

      // Verificar conquistas específicas por gênero
      if ((genreCounts['Ação'] ?? 0) >= 20) {
        await firestoreService.unlockAchievement(userId, 'action_fan');
      }

      if ((genreCounts['Romance'] ?? 0) >= 15) {
        await firestoreService.unlockAchievement(userId, 'romance_lover');
      }

      if ((genreCounts['Comédia'] ?? 0) >= 25) {
        await firestoreService.unlockAchievement(userId, 'comedy_master');
      }

      if ((genreCounts['Terror'] ?? 0) >= 10) {
        await firestoreService.unlockAchievement(userId, 'horror_survivor');
      }

      if ((genreCounts['Ficção científica'] ?? 0) >= 12) {
        await firestoreService.unlockAchievement(userId, 'scifi_explorer');
      }

      // Atualizar progresso para conquistas de gênero
      await firestoreService.updateAchievementProgress(
          userId, 'action_fan', genreCounts['Ação'] ?? 0);
      await firestoreService.updateAchievementProgress(
          userId, 'romance_lover', genreCounts['Romance'] ?? 0);
      await firestoreService.updateAchievementProgress(
          userId, 'comedy_master', genreCounts['Comédia'] ?? 0);
      await firestoreService.updateAchievementProgress(
          userId, 'horror_survivor', genreCounts['Terror'] ?? 0);
      await firestoreService.updateAchievementProgress(
          userId, 'scifi_explorer', genreCounts['Ficção científica'] ?? 0);

      // Outras verificações seriam implementadas aqui
    } catch (e) {
      //print('Error checking achievements: $e');
      rethrow;
    }
  }
}
