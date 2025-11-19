import 'dart:math';

/// Serviço de sorteio simples (padrão).
class RandomPickerService<T> {
  final Random _rng;
  RandomPickerService({Random? rng}) : _rng = rng ?? Random();

  /// Sorteia um item aleatório da lista (excluindo [exclude]) .
  T? pickRandom(List<T> candidates, {bool Function(T)? exclude}) {
    final filtered = exclude == null ? candidates : candidates.where((e) => !exclude(e)).toList();
    if (filtered.isEmpty) return null;
    return filtered[_rng.nextInt(filtered.length)];
  }
}