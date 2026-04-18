import 'dart:async';

import 'package:murmur/features/tts/queue/just_audio_player.dart';

/// Records every call and lets tests trigger completion synchronously.
class FakeAudioPlayerHandle implements AudioPlayerHandle {
  final List<String> calls = [];
  final List<String> setFilePaths = [];
  final List<double> setSpeedValues = [];
  final _completedCtl = StreamController<void>.broadcast();
  final _playingCtl = StreamController<bool>.broadcast();
  bool disposed = false;

  void simulateCompleted() => _completedCtl.add(null);

  @override
  Future<void> setFile(String path) async {
    calls.add('setFile');
    setFilePaths.add(path);
  }

  @override
  Future<void> play() async {
    calls.add('play');
    _playingCtl.add(true);
  }

  @override
  Future<void> pause() async {
    calls.add('pause');
    _playingCtl.add(false);
  }

  @override
  Future<void> stop() async {
    calls.add('stop');
    _playingCtl.add(false);
  }

  @override
  Future<void> setSpeed(double s) async {
    calls.add('setSpeed');
    setSpeedValues.add(s);
  }

  @override
  Future<void> seek(Duration d) async {
    calls.add('seek');
  }

  @override
  Stream<bool> get isPlayingStream => _playingCtl.stream;

  @override
  Stream<void> get completedStream => _completedCtl.stream;

  @override
  Future<void> dispose() async {
    calls.add('dispose');
    disposed = true;
    await _completedCtl.close();
    await _playingCtl.close();
  }
}
