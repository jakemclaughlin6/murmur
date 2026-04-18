import 'dart:async';
import 'dart:io';

import 'package:murmur/core/text/sentence.dart';
import 'package:murmur/features/tts/isolate/messages.dart';
import 'package:murmur/features/tts/isolate/tts_cache.dart';
import 'package:murmur/features/tts/isolate/tts_client.dart';
import 'package:murmur/features/tts/model/model_manifest.dart';
import 'package:murmur/features/tts/queue/just_audio_player.dart';

/// Thrown into a pending [Completer] when [TtsQueue.skipForward] cancels it.
class _SkipCancelled {
  const _SkipCancelled();
}

/// Orchestrator: TtsClient + TtsCache + AudioPlayerHandle.
/// Driven by `ttsQueueProvider`; the reader calls `setChapter(...)`
/// on chapter load.
class TtsQueue {
  TtsQueue({
    required this.client,
    required this.cache,
    required this.player,
    required this.onSentenceStart,
  }) {
    _eventSub =
        client.events.whereType<SentenceReady>().listen(_onSentenceReady);
    _completedSub =
        player.completedStream.listen((_) => _onPlayerCompleted());
  }

  final TtsClient client;
  final TtsCache cache;
  final AudioPlayerHandle player;
  final void Function(int sentenceIdx) onSentenceStart;

  String? _bookId;
  int _chapterIdx = 0;
  int _currentIdx = 0;
  int _currentVoiceSid =
      ModelManifest.byVoiceId(ModelManifest.defaultVoiceId)!.sid;
  List<Sentence> _sentences = const [];

  static const int _ringSize = 3;
  final List<int> _recent = [];
  final Map<int, Completer<String>> _awaiting = {};

  StreamSubscription<SentenceReady>? _eventSub;
  StreamSubscription<void>? _completedSub;
  bool _disposed = false;
  Future<void> _pendingCapWork = Future<void>.value();

  void setChapter({
    required String bookId,
    required int chapterIdx,
    required List<Sentence> sentences,
  }) {
    _bookId = bookId;
    _chapterIdx = chapterIdx;
    _sentences = sentences;
    _currentIdx = 0;
    _recent.clear();
    _awaiting.clear();
    if (sentences.isNotEmpty) _requestSynth(0);
  }

  void _requestSynth(int idx) {
    if (_bookId == null) return;
    if (idx < 0 || idx >= _sentences.length) return;
    if (_awaiting.containsKey(idx)) return;
    if (File(cache.pathFor(_bookId!, _chapterIdx, idx)).existsSync()) return;
    _awaiting[idx] = Completer<String>();
    client.send(SynthSentence(
      bookId: _bookId!,
      chapterIdx: _chapterIdx,
      sentenceIdx: idx,
      text: _sentences[idx].text,
      voiceSid: _currentVoiceSid,
    ));
  }

  void _onSentenceReady(SentenceReady e) {
    final c = _awaiting.remove(e.sentenceIdx);
    if (c != null && !c.isCompleted) c.complete(e.wavPath);
    if (_bookId != null) {
      cache.markRecentlyUsed(_bookId!, _chapterIdx, e.sentenceIdx);
      cache.evictLru(_bookId!, _chapterIdx);
      final bookId = _bookId!;
      _pendingCapWork = _pendingCapWork.then((_) async {
        if (_disposed) return;
        try {
          await cache.enforceSoftCap(bookId);
        } catch (_) {/* benign — cache dir may have been wiped under test */}
      });
    }
  }

  Future<void> play(int fromIdx) async {
    if (_bookId == null) return;
    if (fromIdx < 0 || fromIdx >= _sentences.length) return;
    _currentIdx = fromIdx;
    await _playIdx(fromIdx);
    _requestSynth(fromIdx + 1);
  }

  Future<void> _playIdx(int idx) async {
    final path = cache.pathFor(_bookId!, _chapterIdx, idx);
    String wav;
    if (File(path).existsSync()) {
      wav = path;
    } else {
      _requestSynth(idx);
      wav = await _awaiting[idx]!.future;
    }
    await player.setFile(wav);
    await player.play();
    _rememberRecent(idx);
    onSentenceStart(idx);
  }

  void _rememberRecent(int idx) {
    _recent.remove(idx);
    _recent.add(idx);
    while (_recent.length > _ringSize) {
      _recent.removeAt(0);
    }
  }

  void _onPlayerCompleted() {
    if (_disposed || _bookId == null) return;
    final next = _currentIdx + 1;
    if (next >= _sentences.length) return;
    _currentIdx = next;
    unawaited(_playIdx(next).then((_) => _requestSynth(next + 1)));
  }

  void skipForward() {
    if (_bookId == null) return;
    final inflight = _currentIdx;
    if (_awaiting.containsKey(inflight)) {
      client.send(Cancel(inflight));
      final c = _awaiting.remove(inflight)!;
      if (!c.isCompleted) c.completeError(const _SkipCancelled());
    }
    final next = _currentIdx + 1;
    if (next >= _sentences.length) return;
    _currentIdx = next;
    unawaited(_playIdx(next).then((_) => _requestSynth(next + 1)));
  }

  Future<void> skipBackward() async {
    if (_bookId == null) return;
    final prev = _currentIdx - 1;
    if (prev < 0) return;
    _currentIdx = prev;
    await _playIdx(prev);
    _requestSynth(prev + 1);
  }

  Future<void> setSpeed(double s) async {
    await player.setSpeed(s);
  }

  Future<void> setVoice(String voiceId) async {
    final entry = ModelManifest.byVoiceId(voiceId);
    if (entry == null) return;
    _currentVoiceSid = entry.sid;
    client.send(SetVoice(entry.sid));
    if (_bookId != null) {
      final dir = Directory(
          '${cache.cacheRoot.path}/${_bookId!}/$_chapterIdx');
      if (dir.existsSync()) {
        try { await dir.delete(recursive: true); } catch (_) {/* benign */}
      }
      // Just clear the maps — no completeError on pending completers.
      // setVoice is a user-initiated action; no reader code awaits play()
      // concurrently with a voice switch. If that ever changes, complete
      // with _SkipCancelled here for consistency with skipForward.
      _awaiting.clear();
      _recent.clear();
      _requestSynth(_currentIdx);
    }
  }

  Future<void> pause() async { await player.pause(); }
  Future<void> resume() async { await player.play(); }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _eventSub?.cancel();
    await _completedSub?.cancel();
    try { await _pendingCapWork; } catch (_) {/* benign */}
    try {
      await player.pause();
    } catch (_) {/* benign */}
    await client.dispose();
  }
}
