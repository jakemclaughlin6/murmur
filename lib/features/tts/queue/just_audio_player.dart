import 'dart:async';

import 'package:just_audio/just_audio.dart';

/// DI seam over a single-source audio player. TTS-08: one WAV per
/// `setFile`; no StreamAudioSource, no ConcatenatingAudioSource.
/// TTS-09: `setSpeed` here is the sole runtime speed knob — sherpa
/// `length_scale` stays at 1.0.
abstract class AudioPlayerHandle {
  Future<void> setFile(String path);
  Future<void> play();
  Future<void> pause();
  Future<void> stop();
  Future<void> setSpeed(double s);
  Future<void> seek(Duration d);
  Stream<bool> get isPlayingStream;

  /// Emits once each time the currently-loaded source reaches
  /// `ProcessingState.completed`.
  Stream<void> get completedStream;

  Future<void> dispose();
}

/// Production impl over `just_audio.AudioPlayer`. `completedStream`
/// is derived from `playerStateStream` filtered to
/// `processingState == completed`, de-duplicated so a single source
/// only fires one event (just_audio emits `completed` for as long as
/// the player stays in that state).
class JustAudioPlayerHandle implements AudioPlayerHandle {
  JustAudioPlayerHandle([AudioPlayer? inner])
      : _player = inner ?? AudioPlayer() {
    _sub = _player.playerStateStream.listen((s) {
      if (s.processingState == ProcessingState.completed &&
          !_firedForCurrent) {
        _firedForCurrent = true;
        _completedCtl.add(null);
      }
    });
  }

  final AudioPlayer _player;
  late final StreamSubscription<PlayerState> _sub;
  final _completedCtl = StreamController<void>.broadcast();
  bool _firedForCurrent = true; // no source yet → nothing to complete

  @override
  Future<void> setFile(String path) async {
    _firedForCurrent = false;
    await _player.setAudioSource(AudioSource.file(path));
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> setSpeed(double s) => _player.setSpeed(s);

  @override
  Future<void> seek(Duration d) => _player.seek(d);

  @override
  Stream<bool> get isPlayingStream => _player.playingStream;

  @override
  Stream<void> get completedStream => _completedCtl.stream;

  @override
  Future<void> dispose() async {
    await _sub.cancel();
    await _completedCtl.close();
    await _player.dispose();
  }
}
