import 'dart:async' show StreamController, StreamSubscription;

import '../utils/fetch_options.dart' show DataFetchOptions;
import '../utils/query.dart' show DataQuery;
import '../utils/selection.dart' show DataSelection;
import '../utils/sorting.dart' show DataSorting;
import 'delegate.dart' show DataDelegate;
import 'snapshots.dart'
    show DataGetsSnapshot, DataGetSnapshot, DataAggregateSnapshot;

abstract class MulticastDataDelegate extends DataDelegate {
  final bool multicastListen;
  final bool multicastListenById;
  final bool multicastListenCount;
  final bool multicastListenByQuery;

  final Map<String, _MulticastStream<DataGetsSnapshot>> _listenCache = {};
  final Map<String, _MulticastStream<DataGetSnapshot>> _docCache = {};
  final Map<String, _MulticastStream<DataAggregateSnapshot>> _countCache = {};
  final Map<_QueryCacheKey, _MulticastStream<DataGetsSnapshot>> _queryCache =
      {};

  bool _disposed = false;

  MulticastDataDelegate({
    this.multicastListen = true,
    this.multicastListenById = true,
    this.multicastListenCount = true,
    this.multicastListenByQuery = true,
  });

  bool get isDisposed => _disposed;

  int get activeStreamCount =>
      _listenCache.length +
      _docCache.length +
      _countCache.length +
      _queryCache.length;

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    final all = <_MulticastStream<dynamic>>[
      ..._listenCache.values,
      ..._docCache.values,
      ..._countCache.values,
      ..._queryCache.values,
    ];
    _listenCache.clear();
    _docCache.clear();
    _countCache.clear();
    _queryCache.clear();
    await Future.wait(all.map((e) => e.dispose()));
  }

  Stream<T> _multicast<T, K>(
    Map<K, _MulticastStream<T>> cache,
    K key,
    Stream<T> Function() factory,
  ) {
    if (_disposed) return factory();
    final existing = cache[key];
    if (existing != null && !existing.isClosed) return existing.subscribe();
    late _MulticastStream<T> entry;
    entry = _MulticastStream<T>(factory, () {
      if (identical(cache[key], entry)) cache.remove(key);
    });
    cache[key] = entry;
    return entry.subscribe();
  }

  @override
  Stream<DataGetsSnapshot> listen(String path);

  @override
  Stream<DataGetsSnapshot> onListen(String path) {
    if (!multicastListen) return listen(path);
    return _multicast(_listenCache, path, () => listen(path));
  }

  @override
  Stream<DataGetSnapshot> listenById(String path);

  @override
  Stream<DataGetSnapshot> onListenById(String path) {
    if (!multicastListenById) return listenById(path);
    return _multicast(_docCache, path, () => listenById(path));
  }

  @override
  Stream<DataAggregateSnapshot> listenCount(String path);

  @override
  Stream<DataAggregateSnapshot> onListenCount(String path) {
    if (!multicastListenCount) return listenCount(path);
    return _multicast(_countCache, path, () => listenCount(path));
  }

  @override
  Stream<DataGetsSnapshot> listenByQuery(
    String path, {
    Iterable<DataQuery> queries = const [],
    Iterable<DataSelection> selections = const [],
    Iterable<DataSorting> sorts = const [],
    DataFetchOptions options = const DataFetchOptions(),
  });

  @override
  Stream<DataGetsSnapshot> onListenByQuery(
    String path, {
    Iterable<DataQuery> queries = const [],
    Iterable<DataSelection> selections = const [],
    Iterable<DataSorting> sorts = const [],
    DataFetchOptions options = const DataFetchOptions(),
  }) {
    Stream<DataGetsSnapshot> source() => listenByQuery(
          path,
          queries: queries,
          selections: selections,
          sorts: sorts,
          options: options,
        );
    if (!multicastListenByQuery) return source();
    final key = _QueryCacheKey(path, queries, selections, sorts, options);
    return _multicast(_queryCache, key, source);
  }
}

class _QueryCacheKey {
  final String path;
  final List<Object?> _components;
  final int _hashCode;

  _QueryCacheKey(
    this.path,
    Iterable<DataQuery> queries,
    Iterable<DataSelection> selections,
    Iterable<DataSorting> sorts,
    DataFetchOptions options,
  )   : _components = [
          ...queries,
          null,
          ...selections,
          null,
          ...sorts,
          null,
          options,
        ],
        _hashCode = Object.hash(
          path,
          Object.hashAll(queries),
          Object.hashAll(selections),
          Object.hashAll(sorts),
          options,
        );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! _QueryCacheKey) return false;
    if (_hashCode != other._hashCode) return false;
    if (path != other.path) return false;
    final a = _components;
    final b = other._components;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => _hashCode;
}

class _MulticastStream<T> {
  final Stream<T> Function() _factory;
  final void Function() _onTearDown;
  final StreamController<T> _broadcast = StreamController<T>.broadcast();
  final Set<StreamController<T>> _views = {};

  StreamSubscription<T>? _upstream;
  ({T value})? _last;
  int _listenerCount = 0;
  bool _disposed = false;

  _MulticastStream(this._factory, this._onTearDown);

  bool get isClosed => _disposed || _broadcast.isClosed;

  Stream<T> subscribe() {
    late StreamController<T> view;
    StreamSubscription<T>? sub;

    view = StreamController<T>(
      onListen: () {
        _listenerCount++;
        _views.add(view);
        _ensureUpstream();
        final last = _last;
        if (last != null && !view.isClosed) view.add(last.value);
        sub = _broadcast.stream.listen(
          (event) {
            if (!view.isClosed) view.add(event);
          },
          onError: (Object e, StackTrace s) {
            if (!view.isClosed) view.addError(e, s);
          },
          onDone: () {
            if (!view.isClosed) view.close();
          },
        );
      },
      onCancel: () async {
        _listenerCount--;
        _views.remove(view);
        await sub?.cancel();
        sub = null;
        _maybeTearDown();
      },
    );

    return view.stream;
  }

  void _ensureUpstream() {
    if (_upstream != null || _disposed) return;
    try {
      _upstream = _factory().listen(
        (event) {
          _last = (value: event);
          if (!_broadcast.isClosed) _broadcast.add(event);
        },
        onError: (Object e, StackTrace s) {
          if (!_broadcast.isClosed) _broadcast.addError(e, s);
        },
        onDone: () {
          if (!_broadcast.isClosed) _broadcast.close();
        },
      );
    } catch (e, s) {
      if (!_broadcast.isClosed) _broadcast.addError(e, s);
    }
  }

  void _maybeTearDown() {
    if (_listenerCount > 0 || _disposed) return;
    _disposed = true;
    _upstream?.cancel();
    _upstream = null;
    if (!_broadcast.isClosed) _broadcast.close();
    _onTearDown();
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _upstream?.cancel();
    _upstream = null;
    final viewsSnapshot = List<StreamController<T>>.from(_views);
    _views.clear();
    if (!_broadcast.isClosed) await _broadcast.close();
    for (final v in viewsSnapshot) {
      if (!v.isClosed) await v.close();
    }
  }
}
