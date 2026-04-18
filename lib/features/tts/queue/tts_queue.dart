import 'dart:async';
import 'dart:io';

import 'package:murmur/core/text/sentence.dart';
import 'package:murmur/features/tts/isolate/messages.dart';
import 'package:murmur/features/tts/isolate/tts_cache.dart';
import 'package:murmur/features/tts/isolate/tts_client.dart';
import 'package:murmur/features/tts/model/model_manifest.dart';
import 'package:murmur/features/tts/queue/just_audio_player.dart';

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
  final int _currentVoiceSid =
      ModelManifest.byVoiceId(ModelManifest.defaultVoiceId)!.sid;
  List<Sentence> _sentences = const [];

  static const int _ringSize = 3;
  final List<int> _recent = [];
  final Map<int, Completer<String>> _awaiting = {};

  StreamSubscription<SentenceReady>? _eventSub;
  StreamSubscription<void>? _completedSub;
  bool _disposed = false;

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
      unawaited(cache.enforceSoftCap(_bookId!));
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

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _eventSub?.cancel();
    await _completedSub?.cancel();
    try {
      await player.pause();
    } catch (_) {/* benign */}
    await client.dispose();
  }
}
