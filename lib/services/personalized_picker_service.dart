import 'dart:math';
import 'dart:math' as math;

/// Adapter para acessar campos do seu modelo Movie sem acoplar a estrutura.
abstract class MovieAdapter<T> {
  String id(T m);
  List<String> genres(T m);
  double awardsScore(T m); // 0..1 (vencedores/indicados podem pesar mais)
  double popularity(T m);  // 0..1
  int runtime(T m);        // minutos
  String country(T m);     // ISO ou nome
  String tone(T m);        // 'leve','denso','inspirador'... (opcional: retorne '' se não tiver)
}

class PersonalizedPickerService<T> {
  final MovieAdapter<T> adapter;
  final Random _rng;
  PersonalizedPickerService(this.adapter, {Random? rng}) : _rng = rng ?? Random();

  /// Parâmetros (resultantes do questionário)
  /// - desiredGenres: gêneros favoritos
  /// - maxRuntime: tempo disponível (min)
  /// - mood: 'leve'/'denso'/'inspirador'/...
  /// - preferredCountries: países preferidos
  /// - novelty: 0..1 (0=clássico, 1=experimental) influencia popularidade vs. "exploração"
  T? pickPersonalized(
    List<T> candidates, {
    List<String> desiredGenres = const [],
    int? maxRuntime,
    String? mood,
    List<String> preferredCountries = const [],
    double novelty = 0.5,
    int softmaxTopN = 30,
  }) {
    if (candidates.isEmpty) return null;

    // Score por componente (0..1)
    double simGenero(T m) {
      if (desiredGenres.isEmpty) return 0.5;
      final g = adapter.genres(m).toSet();
      final d = desiredGenres.toSet();
      if (g.isEmpty || d.isEmpty) return 0.4;
      final inter = g.intersection(d).length;
      final uni = g.union(d).length;
      return inter == 0 ? 0.2 : inter / uni;
    }

    double adequacaoTempo(T m) {
      if (maxRuntime == null || maxRuntime! <= 0) return 0.5;
      final r = adapter.runtime(m);
      if (r <= maxRuntime!) return 1.0 - (max(0, maxRuntime! - r) / maxRuntime!)*0.2;
      final diff = r - maxRuntime!;
      if (diff > 60) return 0.0;
      return 1.0 - (diff / 60.0); // linear até 0 em +60min
    }

    double afinidadeTonal(T m) {
      if (mood == null || mood!.isEmpty) return 0.5;
      final t = adapter.tone(m);
      if (t.isEmpty) return 0.5;
      return t == mood ? 1.0 : 0.3; // simples; pode evoluir para matriz de similaridade
    }

    double matchPais(T m) {
      if (preferredCountries.isEmpty) return 0.5;
      final c = adapter.country(m);
      return preferredCountries.contains(c) ? 1.0 : 0.3;
    }

    double pop(T m) => adapter.popularity(m).clamp(0.0, 1.0);
    double award(T m) => adapter.awardsScore(m).clamp(0.0, 1.0);

    // Pesos (podem vir de Remote Config futuramente)
    final wGenre = 0.30;
    final wAward = 0.20;
    final wPop = 0.15 * (1.0 - novelty);   // mais clássico → mais peso em popularidade
    final wTempo = 0.15;
    final wTone = 0.10;
    final wCountry = 0.10;

    final scored = <(T item, double score)>[];
    for (final m in candidates) {
      final s = wGenre * simGenero(m) +
          wAward * award(m) +
          wPop * pop(m) +
          wTempo * adequacaoTempo(m) +
          wTone * afinidadeTonal(m) +
          wCountry * matchPais(m);
      scored.add((m, s));
    }

    // Ordena por score e aplica softmax sobre top-N para manter surpresa
    scored.sort((a, b) => b.$2.compareTo(a.$2));
    final top = scored.take(softmaxTopN).toList();
    final tau = 0.15; // temperatura: menor = mais exploratório
    final exps = top.map((e) => math.exp(e.$2 / tau)).toList();
    final sum = exps.fold<double>(0.0, (p, c) => p + c);
    final probs = exps.map((e) => e / sum).toList();

    // Roleta ponderada
    double r = _rng.nextDouble();
    for (int i = 0; i < top.length; i++) {
      if (r < probs[i]) return top[i].$1;
      r -= probs[i];
    }
    return top.first.$1;
  }
}