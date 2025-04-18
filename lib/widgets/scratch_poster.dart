// lib/widgets/scratch_poster.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'dart:ui' as ui;

class ScratchPoster extends StatefulWidget {
  final String imageUrl;
  final double width;
  final double height;
  final Function onScratchComplete;
  final double scratchThreshold;

  const ScratchPoster({
    Key? key,
    required this.imageUrl,
    required this.width,
    required this.height,
    required this.onScratchComplete,
    this.scratchThreshold = 0.7, // 70% raspado para considerar completo
  }) : super(key: key);

  @override
  _ScratchPosterState createState() => _ScratchPosterState();
}

class _ScratchPosterState extends State<ScratchPoster> {
  late ui.Image? _image;
  bool _isImageLoaded = false;
  final List<Offset> _scratchPoints = [];
  final double _brushSize = 30.0;
  double _scratchedPercentage = 0.0;
  bool _isComplete = false;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    final imageProvider = NetworkImage(widget.imageUrl);
    final ImageStream stream = imageProvider.resolve(ImageConfiguration());
    final Completer<ui.Image> completer = Completer<ui.Image>();

    final ImageStreamListener listener =
        ImageStreamListener((ImageInfo info, bool _) {
      completer.complete(info.image);
    });

    stream.addListener(listener);

    _image = await completer.future;
    setState(() {
      _isImageLoaded = true;
    });

    stream.removeListener(listener);
  }

  void _updateScratchedPercentage() {
    // Cálculo simplificado da porcentagem raspada
    final totalPixels = widget.width * widget.height;
    final scratchedPixels = _scratchPoints.length * (_brushSize * _brushSize);
    final percentage = (scratchedPixels / totalPixels).clamp(0.0, 1.0);

    setState(() {
      _scratchedPercentage = percentage;

      if (!_isComplete && _scratchedPercentage >= widget.scratchThreshold) {
        _isComplete = true;
        widget.onScratchComplete();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_isImageLoaded) {
      return Container(
        width: widget.width,
        height: widget.height,
        color: Colors.grey[300],
        child: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Container(
      width: widget.width,
      height: widget.height,
      child: Stack(
        children: [
          // Imagem original (colorida)
          Image.network(
            widget.imageUrl,
            width: widget.width,
            height: widget.height,
            fit: BoxFit.cover,
          ),

          // Camada de raspagem
          GestureDetector(
            onPanDown: (details) {
              setState(() {
                _scratchPoints.add(details.localPosition);
              });
              _updateScratchedPercentage();
            },
            onPanUpdate: (details) {
              setState(() {
                _scratchPoints.add(details.localPosition);
              });
              _updateScratchedPercentage();
            },
            child: CustomPaint(
              size: Size(widget.width, widget.height),
              painter: ScratchPainter(
                scratchPoints: _scratchPoints,
                brushSize: _brushSize,
              ),
            ),
          ),

          // Indicador de progresso (opcional)
          Positioned(
            bottom: 10,
            right: 10,
            child: Container(
              padding: EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${(_scratchedPercentage * 100).toInt()}%',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ScratchPainter extends CustomPainter {
  final List<Offset> scratchPoints;
  final double brushSize;

  ScratchPainter({
    required this.scratchPoints,
    required this.brushSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = Colors.grey.withOpacity(0.8)
      ..style = PaintingStyle.fill;

    // Desenhar retângulo cinza cobrindo toda a imagem
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);

    // Configurar para modo de composição "clear" para criar efeito de raspagem
    paint.blendMode = BlendMode.clear;

    // Desenhar círculos nos pontos de raspagem
    for (var point in scratchPoints) {
      canvas.drawCircle(point, brushSize / 2, paint);
    }
  }

  @override
  bool shouldRepaint(ScratchPainter oldDelegate) {
    return oldDelegate.scratchPoints != scratchPoints;
  }
}
