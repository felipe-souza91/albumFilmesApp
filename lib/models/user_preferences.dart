import 'package:cloud_firestore/cloud_firestore.dart';

/// Perfil psicológico do usuário derivado do questionário.
/// Esses campos vão alimentar o sorteio personalizado.
class UserPreferences {
  final double energy; // 0..1 – filmes agitados
  final double depth; // 0..1 – filmes profundos/intensos
  final double comfort; // 0..1 – busca por filmes leves/feel-good
  final double novelty; // 0..1 – vontade de ver coisas diferentes
  final double intensityTolerance; // 0..1 – tolerância a temas pesados
  final double socialMode; // 0..1 – 0=família, 1=sozinho

  final int maxRuntime; // minutos
  final List<String> avoidTags; // ex: ["violence_graphic", "sad_heavy"]

  final List<String> favoriteGenres; // gêneros que a pessoa AMA
  final List<String> dislikedGenres; // gêneros que a pessoa evita

  // Data de nascimento (opcional)
  final int? birthYear;
  final int? birthMonth;
  final int? birthDay;

  // Nostalgia e afinidade com filmes antigos
  final double nostalgiaChildhood; // 0..1 – revisitar infância
  final double nostalgiaTeen; // 0..1 – revisitar adolescência
  final double oldMoviesAffinity; // 0..1 – curtir filmes antigos

  // Se o usuário quer respeitar classificação indicativa pela idade
  final bool respectAgeRating;

  final DateTime updatedAt;

  const UserPreferences({
    required this.energy,
    required this.depth,
    required this.comfort,
    required this.novelty,
    required this.intensityTolerance,
    required this.socialMode,
    required this.maxRuntime,
    required this.avoidTags,
    required this.birthYear,
    required this.birthMonth,
    required this.birthDay,
    required this.nostalgiaChildhood,
    required this.nostalgiaTeen,
    required this.oldMoviesAffinity,
    required this.respectAgeRating,
    required this.favoriteGenres,
    required this.dislikedGenres,
    required this.updatedAt,
  });

  factory UserPreferences.empty() {
    return UserPreferences(
      energy: 0.5,
      depth: 0.5,
      comfort: 0.5,
      novelty: 0.5,
      intensityTolerance: 0.5,
      socialMode: 0.5,
      maxRuntime: 120,
      avoidTags: const [],
      birthYear: null,
      birthMonth: null,
      birthDay: null,
      nostalgiaChildhood: 0.5,
      nostalgiaTeen: 0.5,
      oldMoviesAffinity: 0.5,
      respectAgeRating: false,
      favoriteGenres: const [],
      dislikedGenres: const [],
      updatedAt: DateTime.now(),
    );
  }

  factory UserPreferences.fromMap(Map<String, dynamic> map) {
    final derived = map['derivedScores'] as Map<String, dynamic>? ?? {};
    return UserPreferences(
      energy: (derived['energy'] as num?)?.toDouble() ?? 0.5,
      depth: (derived['depth'] as num?)?.toDouble() ?? 0.5,
      comfort: (derived['comfort'] as num?)?.toDouble() ?? 0.5,
      novelty: (derived['novelty'] as num?)?.toDouble() ?? 0.5,
      intensityTolerance:
          (derived['intensityTolerance'] as num?)?.toDouble() ?? 0.5,
      socialMode: (derived['socialMode'] as num?)?.toDouble() ?? 0.5,
      nostalgiaChildhood:
          (derived['nostalgiaChildhood'] as num?)?.toDouble() ?? 0.5,
      nostalgiaTeen: (derived['nostalgiaTeen'] as num?)?.toDouble() ?? 0.5,
      oldMoviesAffinity:
          (derived['oldMoviesAffinity'] as num?)?.toDouble() ?? 0.5,
      maxRuntime: map['maxRuntime'] as int? ?? 120,
      avoidTags: List<String>.from(map['avoidTags'] ?? const []),
      birthYear: map['birthYear'] as int?,
      birthMonth: map['birthMonth'] as int?,
      birthDay: map['birthDay'] as int?,
      respectAgeRating: map['respectAgeRating'] as bool? ?? false,
      favoriteGenres: List<String>.from(map['favoriteGenres'] ?? const []),
      dislikedGenres: List<String>.from(map['dislikedGenres'] ?? const []),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'derivedScores': {
        'energy': energy,
        'depth': depth,
        'comfort': comfort,
        'novelty': novelty,
        'intensityTolerance': intensityTolerance,
        'socialMode': socialMode,
        'nostalgiaChildhood': nostalgiaChildhood,
        'nostalgiaTeen': nostalgiaTeen,
        'oldMoviesAffinity': oldMoviesAffinity,
      },
      'maxRuntime': maxRuntime,
      'avoidTags': avoidTags,
      'birthYear': birthYear,
      'birthMonth': birthMonth,
      'birthDay': birthDay,
      'respectAgeRating': respectAgeRating,
      'favoriteGenres': favoriteGenres,
      'dislikedGenres': dislikedGenres,
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  UserPreferences copyWith({
    double? energy,
    double? depth,
    double? comfort,
    double? novelty,
    double? intensityTolerance,
    double? socialMode,
    int? maxRuntime,
    List<String>? avoidTags,
    int? birthYear,
    int? birthMonth,
    int? birthDay,
    double? nostalgiaChildhood,
    double? nostalgiaTeen,
    double? oldMoviesAffinity,
    bool? respectAgeRating,
    List<String>? favoriteGenres,
    List<String>? dislikedGenres,
    DateTime? updatedAt,
  }) {
    return UserPreferences(
      energy: energy ?? this.energy,
      depth: depth ?? this.depth,
      comfort: comfort ?? this.comfort,
      novelty: novelty ?? this.novelty,
      intensityTolerance: intensityTolerance ?? this.intensityTolerance,
      socialMode: socialMode ?? this.socialMode,
      maxRuntime: maxRuntime ?? this.maxRuntime,
      avoidTags: avoidTags ?? this.avoidTags,
      birthYear: birthYear ?? this.birthYear,
      birthMonth: birthMonth ?? this.birthMonth,
      birthDay: birthDay ?? this.birthDay,
      nostalgiaChildhood: nostalgiaChildhood ?? this.nostalgiaChildhood,
      nostalgiaTeen: nostalgiaTeen ?? this.nostalgiaTeen,
      oldMoviesAffinity: oldMoviesAffinity ?? this.oldMoviesAffinity,
      respectAgeRating: respectAgeRating ?? this.respectAgeRating,
      favoriteGenres: favoriteGenres ?? this.favoriteGenres,
      dislikedGenres: dislikedGenres ?? this.dislikedGenres,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
