part of 'base.dart';

class _FallbackStream<T extends Entity, S extends Object> {
  static const Duration _debounce = Duration(milliseconds: 300);

  final DataSource<T> primary;
  final DataSource<T> backup;
  final Future<bool> Function() resolveConnected;
  final Stream<bool> Function() connectivityChanges;
  final Stream<Response<S>> Function(DataSource<T> source) build;
  final void Function(String op, Object e, StackTrace s) report;

  final StreamController<Response<S>> _controller =
      StreamController<Response<S>>();

  StreamSubscription<Response<S>>? _activeSub;
  StreamSubscription<bool>? _connSub;
  Timer? _debounceTimer;
  bool? _currentRemote;
  bool _closed = false;
  int _gen = 0;

  _FallbackStream({
    required this.primary,
    required this.backup,
    required this.resolveConnected,
    required this.connectivityChanges,
    required this.build,
    required this.report,
  }) {
    _controller.onListen = _start;
    _controller.onCancel = _stop;
  }

  Stream<Response<S>> get stream => _controller.stream;

  Future<void> _start() async {
    try {
      final connected = await resolveConnected();
      await _swap(connected);
      _connSub = connectivityChanges().distinct().listen(_scheduleSwap);
    } catch (e, s) {
      report('fallbackStream.start', e, s);
      if (!_closed) {
        _controller.add(Response(status: Status.failure, error: e.toString()));
      }
    }
  }

  Future<void> _stop() async {
    _closed = true;
    _debounceTimer?.cancel();
    _debounceTimer = null;
    final a = _activeSub;
    final c = _connSub;
    _activeSub = null;
    _connSub = null;
    await Future.wait([if (a != null) a.cancel(), if (c != null) c.cancel()]);
    if (!_controller.isClosed) await _controller.close();
  }

  void _scheduleSwap(bool connected) {
    if (_closed) return;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounce, () {
      _debounceTimer = null;
      _swap(connected);
    });
  }

  Future<void> _swap(bool useRemote) async {
    if (_closed) return;
    if (_currentRemote == useRemote && _activeSub != null) return;
    final myGen = ++_gen;
    _currentRemote = useRemote;

    final old = _activeSub;
    _activeSub = null;
    try {
      await old?.cancel();
    } catch (e, s) {
      report('fallbackStream.cancelOld', e, s);
    }

    if (_closed || myGen != _gen) return;

    final source = useRemote ? primary : backup;
    Stream<Response<S>> stream;
    try {
      stream = build(source);
    } catch (e, s) {
      report('fallbackStream.build', e, s);
      if (!_closed) {
        _controller.add(Response(status: Status.failure, error: e.toString()));
      }
      return;
    }

    _activeSub = stream.listen(
      (event) {
        if (_closed || myGen != _gen) return;
        _controller.add(event);
      },
      onError: (Object e, StackTrace s) {
        if (_closed || myGen != _gen) return;
        report('fallbackStream.event', e, s);
        _controller.add(
          Response<S>(status: Status.failure, error: e.toString()),
        );
      },
    );
  }
}
