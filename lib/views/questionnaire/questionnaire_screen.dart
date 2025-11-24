import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../models/user_preferences.dart';
import '../../services/user_preferences_service.dart';

class QuestionnaireScreen extends StatefulWidget {
  const QuestionnaireScreen({super.key});

  @override
  State<QuestionnaireScreen> createState() => _QuestionnaireScreenState();
}

class _QuestionnaireScreenState extends State<QuestionnaireScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _isSaving = false;

  // respostas (índices das opções)
  int? _colorMain; // 0..3
  int? _colorLeast; // 0..3
  int? _musicStyle; // 0..3
  int? _musicPurpose; // 0..3
  int? _whenTired; // 0..3
  int? _withWhom; // 0..3
  int? _noveltyChoice; // 0..2

  int? _nostalgiaChildhood; // 0..2
  int? _nostalgiaTeen; // 0..2
  int? _oldMovies; // 0..2

  bool _respectAgeRating = false;

  final Set<String> _avoidTags = {};
  double _maxRuntime = 120;

  final Set<String> _favoriteGenres = {};
  final Set<String> _dislikedGenres = {};

  final List<String> _genreOptions = const [
    'Ação',
    'Comédia',
    //  'Drama',
    'Romance',
    'Terror',
    'Ficção científica',
    'Animação',
    'Suspense / Thriller',
    'Fantasia',
    'Guerra / Histórico',
    'Biografia',
  ];

  DateTime? _birthDate;

  bool get _isLastPage => _currentPage == 2;

  bool get _canGoNext {
    if (_currentPage == 0) {
      // data de nascimento é opcional
      return _colorMain != null &&
          _colorLeast != null &&
          _musicStyle != null &&
          _musicPurpose != null;
    } else if (_currentPage == 1) {
      return _whenTired != null &&
          _withWhom != null &&
          _noveltyChoice != null &&
          _nostalgiaChildhood != null &&
          _nostalgiaTeen != null;
    } else {
      // página 3 sempre pode avançar (maxRuntime/avoidTags sempre têm default)
      return true;
    }
  }

  Future<void> _nextPageOrFinish() async {
    if (!_canGoNext) return;

    if (_isLastPage) {
      await _saveQuestionnaire();
    } else {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _prevPage() {
    if (_currentPage == 0) return;
    _pageController.previousPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final initialDate = DateTime(now.year - 25);
    final firstDate = DateTime(1930);
    final lastDate = DateTime(now.year - 5, now.month, now.day);

    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      helpText: 'Escolha seu aniversário (opcional)',
      cancelText: 'Pular',
      confirmText: 'OK',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFFFFD700),
              surface: Color(0xFF0D1B2A),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _birthDate = picked;
      });
    }
  }

  Future<void> _saveQuestionnaire() async {
    setState(() {
      _isSaving = true;
    });

    try {
      final prefs = _buildUserPreferencesFromAnswers();
      await UserPreferencesService.instance.saveCurrentUserPreferences(prefs);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Questionário salvo! Vamos te conhecer melhor 😉'),
        ),
      );
      Navigator.of(context).pop(prefs); // volta com o perfil pronto
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao salvar questionário: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  UserPreferences _buildUserPreferencesFromAnswers() {
    // defaults de segurança
    int colorMain = _colorMain ?? 1;
    int colorLeast = _colorLeast ?? 0;
    int musicStyle = _musicStyle ?? 0;
    int musicPurpose = _musicPurpose ?? 0;
    int whenTired = _whenTired ?? 0;
    int withWhom = _withWhom ?? 0;
    int noveltyChoice = _noveltyChoice ?? 1;
    int nostalgiaChildhoodChoice = _nostalgiaChildhood ?? 1;
    int nostalgiaTeenChoice = _nostalgiaTeen ?? 1;
    int oldMoviesChoice = _oldMovies ?? 1;

    // ENERGY: cores + música mais animada + uso pra animar
    double energyFromColor;
    switch (colorMain) {
      case 0: // quente/vibrante
        energyFromColor = 0.9;
        break;
      case 1: // suave/leve
        energyFromColor = 0.4;
        break;
      case 2: // escura/misteriosa
        energyFromColor = 0.5;
        break;
      case 3: // terrosa/nos
        energyFromColor = 0.6;
        break;
      default:
        energyFromColor = 0.5;
    }

    double energyFromMusic;
    switch (musicStyle) {
      case 0: // pop/dance
        energyFromMusic = 0.9;
        break;
      case 1: // rock/rap
        energyFromMusic = 0.7;
        break;
      case 2: // jazz/clássica/lo-fi
        energyFromMusic = 0.4;
        break;
      case 3: // MPB/indie
        energyFromMusic = 0.5;
        break;
      default:
        energyFromMusic = 0.5;
    }

    double energyFromPurpose;
    switch (musicPurpose) {
      case 0: // me animar
        energyFromPurpose = 0.9;
        break;
      case 1: // relaxar
        energyFromPurpose = 0.3;
        break;
      case 2: // pensar/sentir
        energyFromPurpose = 0.4;
        break;
      case 3: // fundo
        energyFromPurpose = 0.5;
        break;
      default:
        energyFromPurpose = 0.5;
    }

    double energy = (energyFromColor + energyFromMusic + energyFromPurpose) / 3;
    energy = energy.clamp(0.0, 1.0);

    // DEPTH: cores escuras + música complexa + procurar filmes dramáticos
    double depthFromColor;
    switch (colorMain) {
      case 2: // escura
        depthFromColor = 0.9;
        break;
      case 3: // terrosa
        depthFromColor = 0.7;
        break;
      case 1: // suave
        depthFromColor = 0.5;
        break;
      case 0: // vibrante
        depthFromColor = 0.3;
        break;
      default:
        depthFromColor = 0.5;
    }

    double depthFromMusic;
    switch (musicStyle) {
      case 2: // jazz/clássica/lo-fi
        depthFromMusic = 0.9;
        break;
      case 3: // MPB/indie
        depthFromMusic = 0.7;
        break;
      case 1: // rock/rap
        depthFromMusic = 0.6;
        break;
      case 0: // pop/dance
        depthFromMusic = 0.4;
        break;
      default:
        depthFromMusic = 0.5;
    }

    double depthFromWhenTired;
    switch (whenTired) {
      case 2: // dramático
        depthFromWhenTired = 0.9;
        break;
      case 1: // inspirador
        depthFromWhenTired = 0.7;
        break;
      case 0: // leve
        depthFromWhenTired = 0.4;
        break;
      case 3: // tenso
        depthFromWhenTired = 0.6;
        break;
      default:
        depthFromWhenTired = 0.5;
    }

    double depth = (depthFromColor + depthFromMusic + depthFromWhenTired) / 3;
    depth = depth.clamp(0.0, 1.0);

    // COMFORT: filmes leves/feel-good
    double comfortFromColor;
    switch (colorMain) {
      case 1: // suave
        comfortFromColor = 0.9;
        break;
      case 3: // terroso
        comfortFromColor = 0.7;
        break;
      case 0: // vibrante
        comfortFromColor = 0.6;
        break;
      case 2: // escura
        comfortFromColor = 0.3;
        break;
      default:
        comfortFromColor = 0.5;
    }

    double comfortFromWhenTired;
    switch (whenTired) {
      case 0: // leve
        comfortFromWhenTired = 0.9;
        break;
      case 1: // inspirador
        comfortFromWhenTired = 0.7;
        break;
      case 2: // dramático
        comfortFromWhenTired = 0.4;
        break;
      case 3: // tenso
        comfortFromWhenTired = 0.3;
        break;
      default:
        comfortFromWhenTired = 0.5;
    }

    double comfort = (comfortFromColor + comfortFromWhenTired) / 2;
    comfort = comfort.clamp(0.0, 1.0);

    // NOVELTY: preferência por descobertas
    double novelty;
    switch (noveltyChoice) {
      case 0: // já sei que vou gostar
        novelty = 0.2;
        break;
      case 1: // famosos
        novelty = 0.5;
        break;
      case 2: // pérolas escondidas
        novelty = 0.9;
        break;
      default:
        novelty = 0.5;
    }

    // INTENSITY TOLERANCE: quão ok com coisas pesadas
    double intensityFromWhenTired;
    switch (whenTired) {
      case 3: // tenso
        intensityFromWhenTired = 0.9;
        break;
      case 2: // dramático
        intensityFromWhenTired = 0.8;
        break;
      case 1: // inspirador
        intensityFromWhenTired = 0.6;
        break;
      case 0: // leve
        intensityFromWhenTired = 0.3;
        break;
      default:
        intensityFromWhenTired = 0.5;
    }

    double penalty = 0.0;
    if (_avoidTags.contains('violence_graphic')) penalty += 0.3;
    if (_avoidTags.contains('terror_supernatural')) penalty += 0.2;
    if (_avoidTags.contains('sad_heavy')) penalty += 0.2;

    double intensityTolerance =
        max(0.0, intensityFromWhenTired - penalty).clamp(0.0, 1.0);

    // SOCIAL MODE: 0=família, 1=sozinho
    double socialMode;
    switch (withWhom) {
      case 0: // sozinho
        socialMode = 1.0;
        break;
      case 1: // parceiro(a)
        socialMode = 0.7;
        break;
      case 3: // amigos
        socialMode = 0.5;
        break;
      case 2: // família
      default:
        socialMode = 0.2;
    }

    // Nostalgia infância/adolescência
    double mapNostalgia(int choice) {
      switch (choice) {
        case 0:
          return 0.2;
        case 1:
          return 0.5;
        case 2:
          return 0.9;
        default:
          return 0.5;
      }
    }

    final nostalgiaChildhood = mapNostalgia(nostalgiaChildhoodChoice);
    final nostalgiaTeen = mapNostalgia(nostalgiaTeenChoice);

    // Afinidade com filmes antigos
    double oldMoviesAffinity;
    switch (oldMoviesChoice) {
      case 0: // quase nunca atraem
        oldMoviesAffinity = 0.2;
        break;
      case 1: // depende
        oldMoviesAffinity = 0.5;
        break;
      case 2: // amo clássicos
        oldMoviesAffinity = 0.9;
        break;
      default:
        oldMoviesAffinity = 0.5;
    }

    // Data de nascimento (opcional)
    int? birthYear = _birthDate?.year;
    int? birthMonth = _birthDate?.month;
    int? birthDay = _birthDate?.day;

    final prefs = UserPreferences(
      energy: energy,
      depth: depth,
      comfort: comfort,
      novelty: novelty,
      intensityTolerance: intensityTolerance,
      socialMode: socialMode,
      maxRuntime: _maxRuntime.round(),
      avoidTags: _avoidTags.toList(),
      birthYear: birthYear,
      birthMonth: birthMonth,
      birthDay: birthDay,
      nostalgiaChildhood: nostalgiaChildhood,
      nostalgiaTeen: nostalgiaTeen,
      oldMoviesAffinity: oldMoviesAffinity,
      respectAgeRating: _respectAgeRating,
      favoriteGenres: _favoriteGenres.toList(),
      dislikedGenres: _dislikedGenres.toList(),
      updatedAt: DateTime.now(),
    );
    return prefs;
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      appBar: AppBar(
        backgroundColor: const Color.fromRGBO(11, 18, 34, 1.0),
        title: const Text(
          'Questionário de Preferências',
          style: TextStyle(color: Color(0xFFFFD700)),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Color(0xFFFFD700)),
      ),
      body: Column(
        children: [
          const SizedBox(height: 8),
          _buildStepIndicator(),
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              onPageChanged: (idx) {
                setState(() {
                  _currentPage = idx;
                });
              },
              children: [
                _buildPage1(context),
                _buildPage2(context),
                _buildPage3(context),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                if (_currentPage > 0)
                  TextButton(
                    onPressed: _isSaving ? null : _prevPage,
                    child: const Text(
                      'Voltar',
                      style: TextStyle(color: Color(0xFFFFD700)),
                    ),
                  )
                else
                  const SizedBox(width: 72),
                const Spacer(),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFD700),
                    foregroundColor: const Color(0xFF0D1B2A),
                  ),
                  onPressed:
                      (!_canGoNext || _isSaving) ? null : _nextPageOrFinish,
                  child: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(_isLastPage ? 'Concluir' : 'Próximo'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (i) {
        final isActive = i == _currentPage;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          height: 8,
          width: isActive ? 32 : 8,
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFFFFD700) : Colors.grey.shade600,
            borderRadius: BorderRadius.circular(16),
          ),
        );
      }),
    );
  }

  // TELA 1 – cores + música + aniversário
  Widget _buildPage1(BuildContext context) {
    String birthLabel;
    if (_birthDate == null) {
      birthLabel = 'Selecionar data (opcional)';
    } else {
      final d = _birthDate!;
      birthLabel =
          '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Primeiro, vamos entender a sua vibe 🎨🎧',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Qual o seu aniversário? (opcional)',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFFFFD700)),
              foregroundColor: const Color(0xFFFFD700),
            ),
            onPressed: _pickBirthDate,
            icon: const Icon(Icons.cake),
            label: Text(birthLabel),
          ),
          const SizedBox(height: 8),
          const Text(
            'Usamos isso para encontrar filmes nostálgicos da sua infância e adolescência.',
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 24),
          const Text(
            '1) Qual dessas paletas combina mais com você?',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          _ColorPaletteSelector(
            selectedIndex: _colorMain,
            onSelected: (idx) => setState(() => _colorMain = idx),
          ),
          const SizedBox(height: 16),
          const Text(
            '2) E qual você menos se identifica?',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          _ColorPaletteSelector(
            selectedIndex: _colorLeast,
            onSelected: (idx) => setState(() => _colorLeast = idx),
          ),
          const SizedBox(height: 24),
          const Text(
            '3) Que tipo de música te acompanha mais no dia a dia?',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          _OptionChips(
            options: const [
              'Pop / Dance / Eletrônica',
              'Rock / Rap',
              'Jazz / Clássica / Lo-fi',
              'MPB / Indie / Folk',
            ],
            selectedIndex: _musicStyle,
            onSelected: (idx) => setState(() => _musicStyle = idx),
          ),
          const SizedBox(height: 16),
          const Text(
            '4) Música pra você serve mais para…',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          _OptionChips(
            options: const [
              'Me animar',
              'Relaxar',
              'Pensar / sentir coisas profundas',
              'Ficar de fundo enquanto faço outras coisas',
            ],
            selectedIndex: _musicPurpose,
            onSelected: (idx) => setState(() => _musicPurpose = idx),
          ),
        ],
      ),
    );
  }

  // TELA 2 – estado mental, contexto e nostalgia
  Widget _buildPage2(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Agora, como você vive os filmes 🧠',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                ),
          ),
          const SizedBox(height: 16),
          const Text(
            '5) Quando você está cansado, que tipo de filme mais te atrai?',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          _OptionChips(
            options: const [
              'Algo leve pra relaxar',
              'Algo inspirador',
              'Algo dramático pra sentir o impacto',
              'Algo tenso que me prenda',
            ],
            selectedIndex: _whenTired,
            onSelected: (idx) => setState(() => _whenTired = idx),
          ),
          const SizedBox(height: 16),
          const Text(
            '6) Você mais assiste filmes…',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          _OptionChips(
            options: const [
              'Sozinho(a)',
              'Com parceiro(a)',
              'Com família',
              'Com amigos',
            ],
            selectedIndex: _withWhom,
            onSelected: (idx) => setState(() => _withWhom = idx),
          ),
          const SizedBox(height: 16),
          const Text(
            '7) E sobre descobrir filmes novos?',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          _OptionChips(
            options: const [
              'Prefiro algo que já sei que vou gostar',
              'Gosto dos famosos que todo mundo já viu',
              'Amo descobrir pérolas escondidas',
            ],
            selectedIndex: _noveltyChoice,
            onSelected: (idx) => setState(() => _noveltyChoice = idx),
          ),
          const SizedBox(height: 24),
          const Text(
            'Você gosta de rever filmes da sua infância?',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          _OptionChips(
            options: const [
              'Quase nunca',
              'Às vezes',
              'Amo demais!',
            ],
            selectedIndex: _nostalgiaChildhood,
            onSelected: (idx) => setState(() => _nostalgiaChildhood = idx),
          ),
          const SizedBox(height: 16),
          const Text(
            'E filmes da sua adolescência?',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          _OptionChips(
            options: const [
              'Quase nunca',
              'Às vezes',
              'Amo demais!',
            ],
            selectedIndex: _nostalgiaTeen,
            onSelected: (idx) => setState(() => _nostalgiaTeen = idx),
          ),
          const SizedBox(height: 24),
          const Text(
            'Quais gêneros você mais gosta?',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Você pode escolher até 5. Esses gêneros terão um peso especial no sorteio personalizado.',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _genreOptions.map((genre) {
              final selected = _favoriteGenres.contains(genre);
              return FilterChip(
                label: Text(
                  genre,
                  style: TextStyle(
                    color: selected ? const Color(0xFF0D1B2A) : Colors.white,
                  ),
                ),
                selected: selected,
                selectedColor: const Color(0xFFFFD700),
                backgroundColor: const Color(0xFF1B263B),
                onSelected: (value) {
                  setState(() {
                    if (value) {
                      if (_favoriteGenres.length < 5) {
                        _favoriteGenres.add(genre);
                        // se estava em "não gosto", remove
                        _dislikedGenres.remove(genre);
                      }
                    } else {
                      _favoriteGenres.remove(genre);
                    }
                  });
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          const Text(
            'E quais gêneros quase nunca te animam?',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Eles terão menos chance de aparecer no sorteio personalizado.',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _genreOptions.map((genre) {
              final selected = _dislikedGenres.contains(genre);
              return FilterChip(
                label: Text(
                  genre,
                  style: TextStyle(
                    color: selected ? const Color(0xFF0D1B2A) : Colors.white,
                  ),
                ),
                selected: selected,
                selectedColor: Colors.redAccent,
                backgroundColor: const Color(0xFF1B263B),
                onSelected: (value) {
                  setState(() {
                    if (value) {
                      _dislikedGenres.add(genre);
                      // se estava em favoritos, remove
                      _favoriteGenres.remove(genre);
                    } else {
                      _dislikedGenres.remove(genre);
                    }
                  });
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // TELA 3 – limites, filmes antigos e classificação
  Widget _buildPage3(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Por fim, seus limites e conforto ⚠️',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                ),
          ),
          const SizedBox(height: 16),
          const Text(
            '8) Tem algum tipo de filme que você prefere evitar?',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              _buildAvoidChip(
                label: 'Violência gráfica',
                tag: 'violence_graphic',
              ),
              _buildAvoidChip(
                label: 'Terror sobrenatural',
                tag: 'terror_supernatural',
              ),
              _buildAvoidChip(
                label: 'Filmes muito tristes',
                tag: 'sad_heavy',
              ),
              _buildAvoidChip(
                label: 'Temas muito sensíveis',
                tag: 'sensitive_topics',
              ),
              _buildAvoidChip(
                label: 'Nenhum em especial',
                tag: 'none',
                isExclusive: true,
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            '9) Duração confortável de filme',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Slider(
            min: 60,
            max: 240,
            divisions: 18,
            label: '${_maxRuntime.round()} min',
            value: _maxRuntime,
            onChanged: (v) {
              setState(() {
                _maxRuntime = v;
              });
            },
          ),
          Text(
            'Até ${_maxRuntime.round()} minutos',
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 16),
          const Text(
            '10) E os filmes mais antigos (por exemplo, antes dos anos 90)?',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          _OptionChips(
            options: const [
              'Quase nunca me atraem',
              'Depende do dia',
              'Amo clássicos',
            ],
            selectedIndex: _oldMovies,
            onSelected: (idx) => setState(() => _oldMovies = idx),
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            activeColor: const Color(0xFFFFD700),
            title: const Text(
              'Respeitar classificação indicativa pela sua idade',
              style: TextStyle(color: Colors.white),
            ),
            subtitle: const Text(
              'Se ligado, vamos evitar sugerir filmes acima da sua faixa etária.',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
            value: _respectAgeRating,
            onChanged: (v) {
              setState(() {
                _respectAgeRating = v;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAvoidChip({
    required String label,
    required String tag,
    bool isExclusive = false,
  }) {
    final isSelected = _avoidTags.contains(tag);
    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          color: isSelected ? const Color(0xFF0D1B2A) : Colors.white,
        ),
      ),
      selected: isSelected,
      selectedColor: const Color(0xFFFFD700),
      backgroundColor: const Color(0xFF1B263B),
      checkmarkColor: const Color(0xFF0D1B2A),
      onSelected: (_) {
        setState(() {
          if (isExclusive) {
            if (isSelected) {
              _avoidTags.remove(tag);
            } else {
              _avoidTags
                ..clear()
                ..add(tag);
            }
          } else {
            _avoidTags.remove('none');
            if (isSelected) {
              _avoidTags.remove(tag);
            } else {
              _avoidTags.add(tag);
            }
          }
        });
      },
    );
  }
}

/// Paletas de cor com tema escuro
class _ColorPaletteSelector extends StatelessWidget {
  final int? selectedIndex;
  final ValueChanged<int> onSelected;

  const _ColorPaletteSelector({
    required this.selectedIndex,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final palettes = [
      [Colors.orange, Colors.redAccent, Colors.amber],
      [Colors.lightBlue, Colors.teal, Colors.cyan],
      [Colors.deepPurple, Colors.indigo, Colors.black87],
      [Colors.brown, Colors.green, Colors.orange.shade200],
    ];

    final labels = [
      'Quente / vibrante',
      'Suave / leve',
      'Escura / misteriosa',
      'Terrosa / nostálgica',
    ];

    return Column(
      children: List.generate(palettes.length, (i) {
        final isSelected = selectedIndex == i;
        final colors = palettes[i];
        return GestureDetector(
          onTap: () => onSelected(i),
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 6),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF1B263B),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color:
                    isSelected ? const Color(0xFFFFD700) : Colors.grey.shade600,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                ...colors.map(
                  (c) => Expanded(
                    child: Container(
                      height: 32,
                      color: c,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: Text(
                    labels[i],
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}

/// Chips de seleção única com tema do app
class _OptionChips extends StatelessWidget {
  final List<String> options;
  final int? selectedIndex;
  final ValueChanged<int> onSelected;

  const _OptionChips({
    required this.options,
    required this.selectedIndex,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: List.generate(options.length, (i) {
        final selected = selectedIndex == i;
        return ChoiceChip(
          label: Text(
            options[i],
            style: TextStyle(
              color: selected ? const Color(0xFF0D1B2A) : Colors.white,
            ),
          ),
          selected: selected,
          selectedColor: const Color(0xFFFFD700),
          backgroundColor: const Color(0xFF1B263B),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: selected ? const Color(0xFFFFD700) : Colors.grey.shade600,
            ),
          ),
          onSelected: (_) => onSelected(i),
        );
      }),
    );
  }
}
