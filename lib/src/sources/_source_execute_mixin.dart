part of 'base.dart';

mixin _SourceExecuteMixin<T extends Entity> {
  Future<Response<S>> _execute<S extends Object>(
    Future<Response<S>> Function() callback,
  ) async {
    try {
      return await callback();
    } catch (error, st) {
      return Response<S>(status: Status.failure, error: '$error\n$st');
    }
  }

  Stream<Response<S>> _executeStream<S extends Object>(
    Stream<Response<S>> Function() callback,
  ) {
    Stream<Response<S>> source;
    try {
      source = callback();
    } catch (error, st) {
      return Stream.value(
        Response<S>(status: Status.failure, error: '$error\n$st'),
      );
    }
    return source.transform(
      StreamTransformer<Response<S>, Response<S>>.fromHandlers(
        handleError: (error, st, sink) {
          sink.add(Response<S>(status: Status.failure, error: '$error\n$st'));
        },
      ),
    );
  }
}
