// lib/views/movie_details/movie_details_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/movie.dart';
import '../../providers/movie_provider.dart';
import '../../services/firestore_service.dart';
import '../../widgets/rating_stars.dart';
import '../../widgets/scratch_poster.dart';

class MovieDetailsScreen extends StatefulWidget {
  final Movie movie;

  const MovieDetailsScreen({
    Key? key,
    required this.movie,
  }) : super(key: key);

  @override
  _MovieDetailsScreenState createState() => _MovieDetailsScreenState();
}

class _MovieDetailsScreenState extends State<MovieDetailsScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  bool _isWatched = false;
  double _rating = 0.0;
  bool _isLoading = false;
  bool _showScratchPoster = false;

  @override
  void initState() {
    super.initState();
    _isWatched = widget.movie.isWatched;
    _rating = widget.movie.rating;
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

      setState(() {
        _isWatched = true;
      });

      // Atualizar o provider
      final movieProvider = Provider.of<MovieProvider>(context, listen: false);
      movieProvider.updateMovieWatchedStatus(widget.movie.id.toString(), true);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Filme marcado como assistido!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao marcar filme como assistido: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
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

      setState(() {
        _isWatched = false;
      });

      // Atualizar o provider
      final movieProvider = Provider.of<MovieProvider>(context, listen: false);
      movieProvider.updateMovieWatchedStatus(widget.movie.id.toString(), false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Filme marcado como não assistido!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao marcar filme como não assistido: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _rateMovie(double rating) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    setState(() {
      _isLoading = true;
      _rating = rating;
    });

    try {
      await _firestoreService.rateMovie(
        userId,
        widget.movie.id.toString(),
        rating,
      );

      // Atualizar o provider
      final movieProvider = Provider.of<MovieProvider>(context, listen: false);
      movieProvider.updateMovieRating(widget.movie.id.toString(), rating);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Avaliação salva!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao avaliar filme: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _shareViaWhatsApp() async {
    final text =
        'Acabei de assistir ${widget.movie.title} e dei ${_rating.toString()} estrelas! #MovieAlbum';

    try {
      await Share.share(text, subject: 'Compartilhar via WhatsApp');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao compartilhar: $e')),
      );
    }
  }

  void _showScratchDialog() {
    setState(() {
      _showScratchPoster = true;
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Raspe o pôster para marcar como assistido',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 20),
              ScratchPoster(
                imageUrl: widget.movie.posterUrl,
                width: 300,
                height: 450,
                onScratchComplete: () {
                  Navigator.pop(context);
                  _markAsWatched();
                },
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFFFFD700),
                ),
                child: Text(
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
    return Scaffold(
      backgroundColor: Color(0xFF0D1B2A),
      appBar: AppBar(
        iconTheme: IconThemeData(
          color: Color(0xFFFFD700), // Cor dos ícones de ação
        ),
        title: Text(
          'Detalhes do Filme',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Color.fromRGBO(11, 18, 34, 1.0),
        actions: [
          if (_isWatched)
            IconButton(
              icon: Icon(Icons.share),
              onPressed: _shareViaWhatsApp,
            ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFFD700)),
              ),
            )
          : SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Poster e informações básicas
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Poster
                      GestureDetector(
                        onTap: _isWatched ? null : _showScratchDialog,
                        child: Container(
                          width: 150,
                          height: 225,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
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
                                    child: Icon(
                                      Icons.movie,
                                      size: 50,
                                      color: Colors.white,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                      SizedBox(width: 16),

                      // Informações básicas
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.movie.title,
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Lançamento: ${widget.movie.releaseDate.year}',
                              style: TextStyle(
                                color: Colors.white70,
                              ),
                            ),
                            SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: widget.movie.genres.map((genre) {
                                return Chip(
                                  label: Text(
                                    genre,
                                    style: TextStyle(
                                      color: Color(0xFF0D1B2A),
                                    ),
                                  ),
                                  backgroundColor: Color(0xFFFFD700),
                                );
                              }).toList(),
                            ),
                            SizedBox(height: 16),
                            if (_isWatched)
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Sua avaliação:',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  RatingStars(
                                    rating: _rating,
                                    size: 30,
                                    onRatingChanged: _rateMovie,
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: 24),

                  // Descrição
                  Text(
                    'Sinopse',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    widget.movie.description,
                    style: TextStyle(
                      color: Colors.white70,
                      height: 1.5,
                    ),
                  ),

                  SizedBox(height: 24),

                  // Plataformas disponíveis
                  Text(
                    'Disponível em',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 8),
                  widget.movie.platforms.isEmpty
                      ? Text(
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
                                style: TextStyle(
                                  color: Colors.white,
                                ),
                              ),
                              backgroundColor: Color(0xFF0047AB),
                            );
                          }).toList(),
                        ),

                  SizedBox(height: 24),

                  // Palavras-chave
                  Text(
                    'Palavras-chave',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 8),
                  widget.movie.keywords.isEmpty
                      ? Text(
                          'Informação não disponível',
                          style: TextStyle(
                            color: Colors.white70,
                            fontStyle: FontStyle.italic,
                          ),
                        )
                      : Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: widget.movie.keywords.map((keyword) {
                            return Chip(
                              label: Text(
                                keyword,
                                style: TextStyle(
                                  color: Color(0xFF0D1B2A),
                                ),
                              ),
                              backgroundColor: Colors.white70,
                            );
                          }).toList(),
                        ),
                ],
              ),
            ),
      floatingActionButton: !_isWatched
          ? FloatingActionButton.extended(
              onPressed: _showScratchDialog,
              backgroundColor: Color(0xFFFFD700),
              icon: Icon(Icons.check, color: Color(0xFF0D1B2A)),
              label: Text(
                'Marcar como assistido',
                style: TextStyle(color: Color(0xFF0D1B2A)),
              ),
            )
          : FloatingActionButton.extended(
              onPressed: _markAsUnwatched,
              backgroundColor: Color.fromARGB(255, 224, 48, 30),
              icon: Icon(Icons.check, color: Color(0xFF0D1B2A)),
              label: Text(
                'Marcar como não assistido',
                style: TextStyle(color: Color(0xFF0D1B2A)),
              ),
            ),
    );
  }
}
