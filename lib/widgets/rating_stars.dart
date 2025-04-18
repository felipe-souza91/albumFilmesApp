// lib/widgets/rating_stars.dart
import 'package:flutter/material.dart';

class RatingStars extends StatelessWidget {
  final double rating;
  final double size;
  final Color color;
  final Color borderColor;
  final Color backgroundColor;
  final ValueChanged<double>? onRatingChanged;
  final bool allowHalfRating;

  const RatingStars({
    Key? key,
    this.rating = 0.0,
    this.size = 24.0,
    this.color = Colors.amber,
    this.borderColor = Colors.amber,
    this.backgroundColor = Colors.grey,
    this.onRatingChanged,
    this.allowHalfRating = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        return GestureDetector(
          onTap: onRatingChanged == null
              ? null
              : () => onRatingChanged!(index + 1.0),
          onHorizontalDragUpdate: onRatingChanged == null
              ? null
              : (details) {
                  final RenderBox box = context.findRenderObject() as RenderBox;
                  final localPosition =
                      box.globalToLocal(details.globalPosition);
                  final starWidth = box.size.width / 5;
                  final starPosition = localPosition.dx / starWidth;

                  double newRating;
                  if (allowHalfRating) {
                    // Arredondar para 0.5 mais próximo
                    newRating = (starPosition * 2).round() / 2;
                  } else {
                    // Arredondar para inteiro mais próximo
                    newRating = starPosition.round().toDouble();
                  }

                  // Limitar entre 0 e 5
                  newRating = newRating.clamp(0.0, 5.0);

                  onRatingChanged!(newRating);
                },
          child: _buildStar(index),
        );
      }),
    );
  }

  Widget _buildStar(int index) {
    IconData iconData;
    Color starColor;

    if (index + 0.5 < rating) {
      // Estrela cheia
      iconData = Icons.star;
      starColor = color;
    } else if (index < rating) {
      // Meia estrela
      iconData = Icons.star_half;
      starColor = color;
    } else {
      // Estrela vazia
      iconData = Icons.star_border;
      starColor = backgroundColor;
    }

    return Icon(
      iconData,
      color: starColor,
      size: size,
    );
  }
}
