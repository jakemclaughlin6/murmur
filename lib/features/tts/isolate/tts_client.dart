// lib/features/tts/isolate/tts_client.dart
import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/services.dart';

import 'package:murmur/features/tts/isolate/messages.dart';
import 'package:murmur/features/tts/isolate/tts_cache.dart';
import 'package:murmur/features/tts/isolate/tts_worker_main.dart';

/// Thin stream wrapper that adds `whereType<S>()` so callers can do
/// `client.events.whereType<SentenceReady>()` without extra imports.
class TtsEventStream {
  TtsEventStream(this._inner);
  final Stream<TtsEvent> _inner;

  StreamSubscription<TtsEvent> listen(
    void Function(TtsEvent)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) =>
      _inner.listen(
        onData,
        onError: onError,
        onDone: onDone,
        cancelOnError: cancelOnError,
      );

  Stream<S> whereType<S extends TtsEvent>() =>
      _inner.where((e) => e is S).cast<S>();

}

/// UI-side handle to the TTS worker.
///
/// Two modes:
///   - In-process (tests): engineFactory != null. No Isolate.spawn;
///     the shared message loop runs on the calling isolate via a
///     StreamController.
///   - Isolate (prod): engineFactory == null. Spawns a real isolate
///     running `ttsWorkerMain`.
class TtsClient {
  TtsClient._({
    required this.cache,
    required StreamController<TtsEvent> events,
    required void Function(TtsCommand) sendRaw,
    required Set<int> pendingDiscard,
    required Future<void> Function() teardown,
  })  : _events = events,
        _sendRaw = sendRaw,
        _pendingDiscard = pendingDiscard,
        _teardown = teardown;

  final TtsCache cache;
  final StreamController<TtsEvent> _events;
  final void Function(TtsCommand) _sendRaw;
  final Set<int> _pendingDiscard;
  final Future<void> Function() _teardown;

  TtsEventStream get events => TtsEventStream(_events.stream);

  static Future<TtsClient> spawn({
    required TtsCache cache,
    required int initialVoiceSid,
    TtsEngineFactory? engineFactory,
  }) {
    if (engineFactory != null) {
      return _spawnInProcess(
        cache: cache,
        initialVoiceSid: initialVoiceSid,
        engineFactory: engineFactory,
      );
    }
    return _spawnIsolate(cache: cache, initialVoiceSid: initialVoiceSid);
  }

  /// Shared filter: swallow SentenceReady for cancelled sentences and
  /// delete the wav on disk.
  static void _emitFiltered({
    required TtsEvent e,
    required Set<int> pendingDiscard,
    required StreamController<TtsEvent> sink,
  }) {
    if (e is SentenceReady && pendingDiscard.remove(e.sentenceIdx)) {
      try {
        final f = File(e.wavPath);
        if (f.existsSync()) f.deleteSync();
      } catch (_) {/* benign */}
      return;
    }
    if (sink.isClosed) return;
    sink.add(e);
  }

  static Future<TtsClient> _spawnInProcess({
    required TtsCache cache,
    required int initialVoiceSid,
    required TtsEngineFactory engineFactory,
  }) async {
    final cmdCtl = StreamController<TtsCommand>();
    final evtCtl = StreamController<TtsEvent>.broadcast();
    final pendingDiscard = <int>{};
    final engine = engineFactory();

    // Load the engine before returning so callers know init succeeded.
    await engine.load();

    // Emit ModelLoaded and run the loop in a deferred Future so the
    // caller can attach a listener before ModelLoaded fires.
    final loopDone = Future<void>(() async {
      _emitFiltered(
        e: const ModelLoaded(),
        pendingDiscard: pendingDiscard,
        sink: evtCtl,
      );
      await runSharedMessageLoop(
        engine: engine,
        cache: cache,
        commands: cmdCtl.stream,
        emit: (e) => _emitFiltered(
          e: e,
          pendingDiscard: pendingDiscard,
          sink: evtCtl,
        ),
        initialVoiceSid: initialVoiceSid,
      );
    });

    return TtsClient._(
      cache: cache,
      events: evtCtl,
      sendRaw: cmdCtl.add,
      pendingDiscard: pendingDiscard,
      teardown: () async {
        await loopDone;
        await cmdCtl.close();
        await evtCtl.close();
      },
    );
  }

  static Future<TtsClient> _spawnIsolate({
    required TtsCache cache,
    required int initialVoiceSid,
  }) async {
    final fromWorker = ReceivePort();
    final rootToken = RootIsolateToken.instance!;
    final evtCtl = StreamController<TtsEvent>.broadcast();
    final pendingDiscard = <int>{};

    SendPort? toWorker;
    final toWorkerReady = Completer<SendPort>();

    final sub = fromWorker.listen((dynamic msg) {
      if (msg is SendPort) {
        toWorker = msg;
        if (!toWorkerReady.isCompleted) toWorkerReady.complete(msg);
        return;
      }
      if (msg is TtsEvent) {
        _emitFiltered(e: msg, pendingDiscard: pendingDiscard, sink: evtCtl);
      }
    });

    final iso = await Isolate.spawn<TtsWorkerBootstrap>(
      ttsWorkerMain,
      TtsWorkerBootstrap(
        rootToken: rootToken,
        toClient: fromWorker.sendPort,
        initialVoiceSid: initialVoiceSid,
      ),
      errorsAreFatal: true,
      debugName: 'tts-worker',
    );

    try {
      await toWorkerReady.future.timeout(const Duration(seconds: 30));
    } on TimeoutException {
      iso.kill(priority: Isolate.immediate);
      await sub.cancel();
      fromWorker.close();
      await evtCtl.close();
      throw StateError('TTS worker failed to start within 30s');
    }

    return TtsClient._(
      cache: cache,
      events: evtCtl,
      sendRaw: (cmd) => toWorker?.send(cmd),
      pendingDiscard: pendingDiscard,
      teardown: () async {
        await sub.cancel();
        fromWorker.close();
        await evtCtl.close();
      },
    );
  }

  void send(TtsCommand cmd) {
    if (cmd is Cancel) {
      _pendingDiscard.add(cmd.sentenceIdx);
    }
    _sendRaw(cmd);
  }

  /// Sends Dispose, awaits DisposeAck (with a 2 s safety timeout),
  /// then tears down.
  Future<void> dispose() async {
    final ackFut = _events.stream
        .firstWhere((e) => e is DisposeAck)
        .timeout(const Duration(seconds: 2), onTimeout: () => const DisposeAck());
    _sendRaw(const Dispose());
    await ackFut;
    await _teardown();
  }
}
