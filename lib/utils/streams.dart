import 'dart:async';

/// Junta varias listas que se actualizan solas en una sola lista ordenada
/// con [compare]. Emite recién cuando todas emitieron al menos una vez (así
/// no se muestra una lista a medias) y después con cada cambio. Si una
/// falla, falla el resultado.
Stream<List<T>> mergeLatest<T>(
  List<Stream<List<T>>> streams, {
  int Function(T a, T b)? compare,
}) {
  if (streams.isEmpty) return Stream.value(List<T>.empty());
  final latest = <int, List<T>>{};
  final subs = <StreamSubscription<List<T>>>[];
  late final StreamController<List<T>> controller;
  controller = StreamController<List<T>>(
    onListen: () {
      for (var i = 0; i < streams.length; i++) {
        subs.add(
          streams[i].listen((list) {
            latest[i] = list;
            if (latest.length < streams.length) return;
            final all = [for (final l in latest.values) ...l];
            if (compare != null) all.sort(compare);
            controller.add(all);
          }, onError: controller.addError),
        );
      }
    },
    onCancel: () async {
      for (final sub in subs) {
        await sub.cancel();
      }
    },
  );
  return controller.stream;
}
