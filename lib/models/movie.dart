// lib/models/movie.dart
class Movie {
  final int id;
  final String title;
  final String description;
  final List<String> genres;
  final List<String> platforms;
  final DateTime releaseDate;
  final List<String> keywords;
  final List<String> productionCountries;
  final String director;
  final String originalLanguage;
  final String posterUrl;
  final bool isWatched;
  final double rating;

  /// Nota do TMDB (vote_average), escala 0-10.
  /// Filmes já no Firestore sem este campo recebem 5.0 (neutro) como fallback.
  /// Antes, o picker usava [rating] (estrelas do usuário, sempre 0 para
  /// não-assistidos), tornando o fator de qualidade completamente inútil.
  final double voteAverage;

  /// Popularidade normalizada do TMDB, escala 0-1 (calculada como popularity/500).
  /// Usada pelo fator de novelty no sorteio personalizado.
  /// Filmes já no Firestore sem este campo recebem 0.5 (neutro) como fallback.
  /// CORREÇÃO: antes era hardcoded em 0.5 diretamente no home_screen.dart,
  /// cegando o fator de novelty para todos os filmes.
  final double popularityNorm;

  Movie({
    required this.id,
    required this.title,
    required this.description,
    required this.genres,
    required this.platforms,
    required this.releaseDate,
    required this.keywords,
    this.productionCountries = const [],
    this.director = '',
    this.originalLanguage = '',
    required this.posterUrl,
    this.isWatched = false,
    this.rating = 0.0,
    this.voteAverage = 5.0,
    this.popularityNorm = 0.5,
  });

  factory Movie.fromJson(Map<String, dynamic> json) {
    return Movie(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      description: json['description'],
      genres: List<String>.from(json['genres'] ?? ['Desconhecido']),
      platforms: List<String>.from(json['platforms'] ?? ['Desconhecida']),
      releaseDate: json['releaseDate'] != null
          ? DateTime.tryParse(json['releaseDate']) ?? DateTime(2000)
          : DateTime(2000),
      keywords: List<String>.from(json['keywords'] ?? []),
      productionCountries: List<String>.from(json['productionCountries'] ?? []),
      director: json['director'] ?? '',
      originalLanguage: json['originalLanguage'] ?? '',
      posterUrl: json['posterUrl'] ?? '',
      isWatched: json['isWatched'] ?? false,
      rating: (json['rating'] ?? 0.0).toDouble(),
      // Fallback 5.0 = neutro para filmes importados antes desta correção
      voteAverage: (json['voteAverage'] as num?)?.toDouble() ?? 5.0,
      // Fallback 0.5 = neutro para filmes importados antes desta correção
      popularityNorm: (json['popularityNorm'] as num?)?.toDouble() ?? 0.5,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'genres': genres,
      'platforms': platforms,
      'releaseDate': releaseDate.toIso8601String(),
      'keywords': keywords,
      'productionCountries': productionCountries,
      'director': director,
      'originalLanguage': originalLanguage,
      'posterUrl': posterUrl,
      'isWatched': isWatched,
      'rating': rating,
      'voteAverage': voteAverage,
      'popularityNorm': popularityNorm,
    };
  }

  Movie copyWith({
    int? id,
    String? title,
    String? description,
    List<String>? genres,
    List<String>? platforms,
    DateTime? releaseDate,
    List<String>? keywords,
    List<String>? productionCountries,
    String? director,
    String? originalLanguage,
    String? posterUrl,
    bool? isWatched,
    double? rating,
    double? voteAverage,
    double? popularityNorm,
  }) {
    return Movie(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      genres: genres ?? this.genres,
      platforms: platforms ?? this.platforms,
      releaseDate: releaseDate ?? this.releaseDate,
      keywords: keywords ?? this.keywords,
      productionCountries: productionCountries ?? this.productionCountries,
      director: director ?? this.director,
      originalLanguage: originalLanguage ?? this.originalLanguage,
      posterUrl: posterUrl ?? this.posterUrl,
      isWatched: isWatched ?? this.isWatched,
      rating: rating ?? this.rating,
      voteAverage: voteAverage ?? this.voteAverage,
      popularityNorm: popularityNorm ?? this.popularityNorm,
    );
  }
}
