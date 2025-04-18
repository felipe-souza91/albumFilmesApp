// lib/models/movie.dart
class Movie {
  final int id;
  final String title;
  final String description;
  final List<String> genres;
  final List<String> platforms;
  final DateTime releaseDate;
  final List<String> keywords;
  final String posterUrl;
  final bool isWatched;
  final double rating;

  Movie({
    required this.id,
    required this.title,
    required this.description,
    required this.genres,
    required this.platforms,
    required this.releaseDate,
    required this.keywords,
    required this.posterUrl,
    this.isWatched = false,
    this.rating = 0.0,
  });

  factory Movie.fromJson(Map<String, dynamic> json) {
    return Movie(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      genres: List<String>.from(json['genres'] ?? []),
      platforms: List<String>.from(json['platforms'] ?? []),
      releaseDate: json['releaseDate'] != null
          ? DateTime.parse(json['releaseDate'])
          : DateTime.now(),
      keywords: List<String>.from(json['keywords'] ?? []),
      posterUrl: json['posterUrl'] ?? '',
      isWatched: json['isWatched'] ?? false,
      rating: (json['rating'] ?? 0.0).toDouble(),
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
      'posterUrl': posterUrl,
      'isWatched': isWatched,
      'rating': rating,
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
    String? posterUrl,
    bool? isWatched,
    double? rating,
  }) {
    return Movie(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      genres: genres ?? this.genres,
      platforms: platforms ?? this.platforms,
      releaseDate: releaseDate ?? this.releaseDate,
      keywords: keywords ?? this.keywords,
      posterUrl: posterUrl ?? this.posterUrl,
      isWatched: isWatched ?? this.isWatched,
      rating: rating ?? this.rating,
    );
  }
}
