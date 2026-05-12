import 'dart:async' show StreamSubscription, StreamController;

import '../operations/cache_delegate.dart' show DataCacheDelegate;
import '../operations/connectivity_delegate.dart' show DataConnectivityDelegate;

/// Signature for a repository's offline-queue drain callback. Registered
/// with [DM.register] under a unique key per repository.
typedef DataRepoDrainCallback = Future<void> Function();

/// Process-wide registry that connects the repository layer to the
/// host app's connectivity stream and persistent cache.
///
/// Every [DataRepository] reads its connectivity state from [DM.i] and
/// persists its offline queue through [DM.i.cache]. When connectivity
/// returns, [DM] calls every registered drain callback so each
/// repository can replay its queued operations.
///
/// Configure it once at app start, before constructing any repository.
///
/// ### Simple example
///
/// ```dart
/// void main() {
///   DM.i.configure(
///     connectivity: MyConnectivityDelegate(),
///     cache: HiveCacheDelegate(),
///   );
///   runApp(const MyApp());
/// }
/// ```
///
/// ### Advanced example — reactively rebuild widgets on connectivity
///
/// ```dart
/// StreamBuilder<bool>(
///   stream: DM.i.connectivityChanges,
///   builder: (_, snap) {
///     final online = snap.data ?? true;
///     return Banner(visible: !online, text: 'Offline');
///   },
/// )
/// ```
class DM {
  DM._();

  /// The singleton instance.
  static final DM i = DM._();

  DataConnectivityDelegate? _connectivity;
  DataCacheDelegate? _cache;
  StreamSubscription<bool>? _sub;
  bool _draining = false;
  final Map<String, DataRepoDrainCallback> _drains = {};
  final StreamController<bool> _connController =
      StreamController<bool>.broadcast();

  /// The currently configured connectivity delegate, if any.
  DataConnectivityDelegate? get connectivity => _connectivity;

  /// The currently configured persistent cache delegate, if any. The
  /// offline queue and restore flags are stored here.
  DataCacheDelegate? get cache => _cache;

  /// Whether a cache delegate has been configured.
  bool get hasCache => _cache != null;

  /// Broadcast stream of connectivity changes (`true` = connected).
  /// Emits whenever the configured [DataConnectivityDelegate] reports
  /// a change.
  Stream<bool> get connectivityChanges => _connController.stream;

  /// Wires up the global connectivity source and cache delegate. Safe
  /// to call multiple times — the previous connectivity subscription
  /// is cancelled first.
  ///
  /// When [connectivity] reports a transition to *connected*, every
  /// registered drain callback runs (see [drainAll]).
  ///
  /// ```dart
  /// DM.i.configure(
  ///   connectivity: ConnectivityPlusDelegate(),
  ///   cache: HiveCacheDelegate(),
  /// );
  /// ```
  void configure({
    DataConnectivityDelegate? connectivity,
    DataCacheDelegate? cache,
  }) {
    _connectivity = connectivity;
    _cache = cache;
    _sub?.cancel();
    _sub = null;
    if (connectivity != null) {
      _sub = connectivity.onChanged.listen((connected) {
        _connController.add(connected);
        if (connected) drainAll();
      });
    }
  }

  /// Whether the device currently has connectivity. Returns `true`
  /// when no [DataConnectivityDelegate] is configured.
  Future<bool> get isConnected async {
    final c = _connectivity;
    if (c == null) return true;
    return c.isConnected;
  }

  /// Registers a drain callback under [key]. Repositories call this
  /// internally on construction so their offline queues are drained
  /// when connectivity returns. Replacing an existing key is allowed.
  void register(String key, DataRepoDrainCallback drain) {
    _drains[key] = drain;
  }

  /// Removes the drain callback for [key]. No-op if absent.
  void unregister(String key) {
    _drains.remove(key);
  }

  /// Invokes every registered drain callback sequentially. Re-entrant
  /// calls are coalesced — if a drain is already in progress, the
  /// second call returns immediately.
  ///
  /// Called automatically on every transition to *connected*. Call
  /// manually when you want to force an immediate retry, e.g. after a
  /// user pulls to refresh.
  Future<void> drainAll() async {
    if (_draining) return;
    _draining = true;
    try {
      final list = List<DataRepoDrainCallback>.of(_drains.values);
      for (final d in list) {
        try {
          await d();
        } catch (_) {}
      }
    } finally {
      _draining = false;
    }
  }

  /// Cancels the connectivity subscription, clears registered drains,
  /// and closes the connectivity change stream. Call only when
  /// tearing down the entire app (e.g. in tests).
  Future<void> dispose() async {
    await _sub?.cancel();
    _sub = null;
    _drains.clear();
    _connectivity = null;
    _cache = null;
    await _connController.close();
  }
}
