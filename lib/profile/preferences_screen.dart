import 'package:flutter/material.dart';

import '../models/user_preferences.dart';
import '../services/user_preferences_service.dart';
import '../views/questionnaire/questionnaire_screen.dart';

class PreferencesScreen extends StatefulWidget {
  const PreferencesScreen({super.key});

  @override
  State<PreferencesScreen> createState() => _PreferencesScreenState();
}

class _PreferencesScreenState extends State<PreferencesScreen> {
  UserPreferences? _prefs;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    try {
      final prefs =
          await UserPreferencesService.instance.getCurrentUserPreferences();
      setState(() {
        _prefs = prefs;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _prefs = null;
        _isLoading = false;
      });
    }
  }

  Future<void> _openQuestionnaire() async {
    final result = await Navigator.of(context).push<UserPreferences>(
      MaterialPageRoute(
        builder: (_) => const QuestionnaireScreen(),
      ),
    );

    if (result != null) {
      setState(() {
        _prefs = result;
      });
    } else {
      await _loadPrefs();
    }
  }

  String _scoreLabel(double v) {
    if (v <= 0.33) return 'Baixo';
    if (v <= 0.66) return 'Médio';
    return 'Alto';
  }

  int? _calculateAge(UserPreferences p) {
    if (p.birthYear == null) return null;
    final now = DateTime.now();
    int age = now.year - p.birthYear!;
    if (p.birthMonth != null && p.birthDay != null) {
      final hadBirthdayThisYear = (now.month > p.birthMonth!) ||
          (now.month == p.birthMonth! && now.day >= p.birthDay!);
      if (!hadBirthdayThisYear) {
        age -= 1;
      }
    }
    if (age < 0 || age > 120) return null;
    return age;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      appBar: AppBar(
        backgroundColor: const Color.fromRGBO(11, 18, 34, 1.0),
        title: const Text(
          'Preferências',
          style: TextStyle(color: Color(0xFFFFD700)),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFFFFD700)),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFD700),
                    foregroundColor: const Color(0xFF0D1B2A),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: _openQuestionnaire,
                  icon: const Icon(Icons.quiz),
                  label: const Text(
                    'Responder / atualizar questionário',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFFFFD700),
                        ),
                      )
                    : _prefs == null
                        ? const Center(
                            child: Text(
                              'Você ainda não preencheu o questionário.\nToque no botão acima para começar 🙂',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 16,
                              ),
                            ),
                          )
                        : _buildPrefsSummary(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPrefsSummary(BuildContext context) {
    final p = _prefs!;
    final age = _calculateAge(p);

    return ListView(
      children: [
        const Text(
          'Seu perfil de gostos',
          style: TextStyle(
            color: Color(0xFFFFD700),
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Usamos esse perfil para deixar o “sorteio personalizado” muito mais a sua cara.\n'
          'Mas, de vez em quando, vamos te sugerir algo inesperado de propósito — é assim que surgem novos favoritos 😉',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 16),
        if (age != null) ...[
          _PrefTile(
            title: 'Idade estimada',
            value: '$age anos',
            description:
                'Usamos sua faixa de idade para ajustar nostalgia e, se você quiser, respeitar classificação indicativa.',
          ),
          const SizedBox(height: 8),
        ],
        _PrefTile(
          title: 'Energia dos filmes',
          value: _scoreLabel(p.energy),
          description:
              'Quanto mais alto, mais filmes agitados (ação, comédia, aventura) tendem a aparecer.',
        ),
        _PrefTile(
          title: 'Profundidade emocional',
          value: _scoreLabel(p.depth),
          description:
              'Scores altos indicam mais abertura a dramas, filmes “cabeça” e histórias intensas.',
        ),
        _PrefTile(
          title: 'Busca por conforto',
          value: _scoreLabel(p.comfort),
          description:
              'Quanto maior, mais o app vai priorizar filmes leves e feel-good.',
        ),
        _PrefTile(
          title: 'Vontade de descobrir coisas novas',
          value: _scoreLabel(p.novelty),
          description:
              'Score alto = mais “pérolas escondidas” e filmes fora do óbvio.',
        ),
        _PrefTile(
          title: 'Tolerância a temas pesados',
          value: _scoreLabel(p.intensityTolerance),
          description:
              'Usado para filtrar/evitar filmes muito violentos ou emocionalmente pesados.',
        ),
        _PrefTile(
          title: 'Duração máxima confortável',
          value: '${p.maxRuntime} min',
          description:
              'Vamos evitar sugerir filmes muito mais longos que isso, principalmente no sorteio personalizado.',
        ),
        const SizedBox(height: 12),
        _PrefTile(
          title: 'Nostalgia de infância',
          value: _scoreLabel(p.nostalgiaChildhood),
          description:
              'Quanto maior, mais chances de aparecerem filmes da época da sua infância.',
        ),
        _PrefTile(
          title: 'Nostalgia da adolescência',
          value: _scoreLabel(p.nostalgiaTeen),
          description:
              'Usamos isso pra buscar filmes da época escola/faculdade quando fizer sentido.',
        ),
        _PrefTile(
          title: 'Afinidade com filmes antigos',
          value: _scoreLabel(p.oldMoviesAffinity),
          description:
              'Scores altos indicam mais abertura a clássicos e filmes de décadas passadas.',
        ),
        _PrefTile(
          title: 'Classificação indicativa',
          value: p.respectAgeRating ? 'Respeitar' : 'Mostrar tudo',
          description:
              'Se ativado, evitamos sugerir filmes acima da sua faixa etária.',
        ),
        const SizedBox(height: 16),
        if (p.favoriteGenres.isNotEmpty) ...[
          const Text(
            'Gêneros que você mais gosta',
            style: TextStyle(
              color: Color(0xFFFFD700),
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: p.favoriteGenres.map((g) {
              return Chip(
                label: Text(g),
                backgroundColor: const Color(0xFF1B4332),
                labelStyle: const TextStyle(color: Colors.white),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
        ],
        if (p.dislikedGenres.isNotEmpty) ...[
          const Text(
            'Gêneros que você quase nunca curte',
            style: TextStyle(
              color: Color(0xFFFFD700),
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: p.dislikedGenres.map((g) {
              return Chip(
                label: Text(g),
                backgroundColor: Colors.red.withOpacity(0.25),
                labelStyle: const TextStyle(color: Colors.white),
              );
            }).toList(),
          ),
        ],
        if (p.avoidTags.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text(
            'Coisas que você prefere evitar',
            style: TextStyle(
              color: Color(0xFFFFD700),
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: p.avoidTags.map((tag) {
              final label = _mapAvoidTagToLabel(tag);
              return Chip(
                label: Text(label),
                backgroundColor: Colors.red.withOpacity(0.2),
                labelStyle: const TextStyle(color: Colors.white),
              );
            }).toList(),
          )
        ],
      ],
    );
  }

  String _mapAvoidTagToLabel(String tag) {
    switch (tag) {
      case 'violence_graphic':
        return 'Violência gráfica';
      case 'terror_supernatural':
        return 'Terror sobrenatural';
      case 'sad_heavy':
        return 'Filmes muito tristes';
      case 'sensitive_topics':
        return 'Temas muito sensíveis';
      case 'none':
        return 'Nenhuma restrição';
      default:
        return tag;
    }
  }
}

class _PrefTile extends StatelessWidget {
  final String title;
  final String value;
  final String description;

  const _PrefTile({
    required this.title,
    required this.value,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF1B263B),
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    color: Color(0xFFFFD700),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
