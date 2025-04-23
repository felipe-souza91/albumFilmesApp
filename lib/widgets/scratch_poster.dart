// lib/widgets/scratch_poster.dart
import 'package:flutter/material.dart';
import 'package:scratcher/scratcher.dart';

class ScratchPoster extends StatefulWidget {
  final String imageUrl;
  final double width;
  final double height;
  final Function onScratchComplete;
  final double scratchThreshold;

  const ScratchPoster({
    super.key,
    required this.imageUrl,
    required this.width,
    required this.height,
    required this.onScratchComplete,
    this.scratchThreshold = 0.7, // 70% raspado para considerar completo
  });

  @override
  State<ScratchPoster> createState() => _ScratchPosterState();
}

class _ScratchPosterState extends State<ScratchPoster> {
  double _progress = 0.0;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Imagem de fundo (colorida)
        Image.network(
          widget.imageUrl,
          width: widget.width,
          height: widget.height,
          fit: BoxFit.cover,
        ),

        // Camada de raspagem com Scratcher
        Scratcher(
          brushSize: 40,
          threshold: widget.scratchThreshold * 100, // precisa ser em %
          color: Colors.grey,
          onThreshold: () {
            widget.onScratchComplete();
          },
          onChange: (value) {
            setState(() {
              _progress = value;
            });
          },
          child: Container(
            width: widget.width,
            height: widget.height,
            color: Colors.transparent,
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
              '${_progress.toStringAsFixed(0)}%',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
