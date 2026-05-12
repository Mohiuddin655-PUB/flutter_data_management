class CacheConfig {
  final int maxSize;
  final Duration? defaultTtl;
  final bool deduplicateInFlight;
  final Duration evictionInterval;

  const CacheConfig({
    this.maxSize = 128,
    this.defaultTtl,
    this.deduplicateInFlight = true,
    this.evictionInterval = const Duration(seconds: 30),
  }) : assert(maxSize > 0, 'maxSize must be positive');
}
