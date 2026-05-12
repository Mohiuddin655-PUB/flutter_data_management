class CacheStats {
  int hits = 0;
  int misses = 0;
  int evictions = 0;
  int expirations = 0;
  int inFlightDedupes = 0;
  int writes = 0;

  double get hitRate {
    final total = hits + misses;
    return total == 0 ? 0.0 : hits / total;
  }

  CacheStats clone() {
    return CacheStats()
      ..hits = hits
      ..misses = misses
      ..writes = writes
      ..evictions = evictions
      ..expirations = expirations
      ..inFlightDedupes = inFlightDedupes;
  }

  Map<String, num> snapshot() => {
        'hits': hits,
        'misses': misses,
        'evictions': evictions,
        'expirations': expirations,
        'inFlightDedupes': inFlightDedupes,
        'writes': writes,
        'hitRate': hitRate,
      };

  void reset() {
    hits = 0;
    misses = 0;
    evictions = 0;
    expirations = 0;
    inFlightDedupes = 0;
    writes = 0;
  }

  @override
  String toString() => 'CacheStats(${snapshot()})';
}
