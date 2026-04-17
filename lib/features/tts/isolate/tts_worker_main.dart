// lib/features/tts/isolate/tts_worker_main.dart
import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'package:murmur/features/tts/audio/wav_wrap.dart';
import 'package:murmur/features/tts/isolate/messages.dart';
import 'package:murmur/features/tts/isolate/sherpa_tts_engine.dart';
import 'package:murmur/features/tts/isolate/tts_cache.dart';
import 'package:murmur/features/tts/model/paths.dart';

/// Bootstrap payload crossed via `Isolate.spawn`. All fields are
/// primitives / SendPort / RootIsolateToken so they survive cross-
/// isolate copy.
class TtsWorkerBootstrap {
  final RootIsolateToken rootToken;
  final SendPort toClient;
  final int initialVoiceSid;
  const TtsWorkerBootstrap({
    required this.rootToken,
    required this.toClient,
    required this.initialVoiceSid,
  });
}

/// Marker implemented only by test fakes. The shared message loop
/// consults it to honor a programmable pre-generate delay. The real
/// SherpaTtsEngine does NOT implement this, so production has zero
/// inserted latency.
abstract class SynthDelayed {
  Duration get synthDelay;
}

/// Top-level isolate entry (must be static).
///
/// Pitfall 1: BackgroundIsolateBinaryMessenger.ensureInitialized MUST
/// run before any plugin call. Pitfall 8: engine resources MUST be
/// released before Isolate.exit.
Future<void> ttsWorkerMain(TtsWorkerBootstrap args) async {
  BackgroundIsolateBinaryMessenger.ensureInitialized(args.rootToken);

  final supportDir = await getApplicationSupportDirectory();
  final kokoroPaths = KokoroPaths.forSupportDir(supportDir.path);
  final cacheRoot = Directory('${supportDir.path}/tts_cache');
  if (!cacheRoot.existsSync()) cacheRoot.createSync(recursive: true);
  final cache = TtsCache(cacheRoot: cacheRoot);

  final engine = SherpaTtsEngine(kokoroPaths);
  try {
    await engine.load();
  } catch (e) {
    args.toClient.send(TtsError(null, e));
    Isolate.exit(args.toClient, const DisposeAck());
  }
  args.toClient.send(const ModelLoaded());

  final recv = ReceivePort();
  args.toClient.send(recv.sendPort);

  final cmdStream = recv.cast<TtsCommand>();
  await runSharedMessageLoop(
    engine: engine,
    cache: cache,
    commands: cmdStream,
    emit: args.toClient.send,
    initialVoiceSid: args.initialVoiceSid,
  );

  recv.close();
  Isolate.exit(args.toClient, const DisposeAck());
}

/// Shared message loop used by both the in-process (tests) and isolate
/// (prod) paths. Returns when Dispose arrives (after emitting
/// DisposeAck).
Future<void> runSharedMessageLoop({
  required TtsEngine engine,
  required TtsCache cache,
  required Stream<TtsCommand> commands,
  required void Function(TtsEvent) emit,
  required int initialVoiceSid,
}) async {
  var currentSid = initialVoiceSid;

  await for (final msg in commands) {
    switch (msg) {
      case SetVoice(:final sid):
        currentSid = sid;
      case Cancel():
        break; // D-12 soft cancel: client discards the matching SentenceReady.
      case SynthSentence(
          :final bookId,
          :final chapterIdx,
          :final sentenceIdx,
          :final text
        ):
        try {
          if (engine is SynthDelayed &&
              (engine as SynthDelayed).synthDelay > Duration.zero) {
            await Future<void>.delayed((engine as SynthDelayed).synthDelay);
          }
          final r = engine.generate(text: text, sid: currentSid, speed: 1.0);
          final bytes = wavWrap(r.samples, sampleRate: r.sampleRate);
          final path = cache.pathFor(bookId, chapterIdx, sentenceIdx);
          await File(path).writeAsBytes(bytes, flush: true);
          emit(SentenceReady(sentenceIdx, path));
        } catch (e) {
          emit(TtsError(sentenceIdx, e));
        }
      case Dispose():
        await engine.dispose();
        emit(const DisposeAck());
        return;
    }
  }
}
