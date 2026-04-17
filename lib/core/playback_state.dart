import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'playback_state.g.dart';

/// Immutable playback cursor shared between reader and TTS (CD-04 / PBK-08).
///
/// Reader reads; TTS writes. Neither feature imports the other.
class PlaybackState {
  final String? bookId;
  final int chapterIdx;
  final int sentenceIdx;
  final bool isPlaying;
  final double speed;
  final String voiceId;

  const PlaybackState({
    required this.bookId,
    required this.chapterIdx,
    required this.sentenceIdx,
    required this.isPlaying,
    required this.speed,
    required this.voiceId,
  });

  const PlaybackState.idle()
      : bookId = null,
        chapterIdx = 0,
        sentenceIdx = 0,
        isPlaying = false,
        speed = 1.0,
        voiceId = 'af_bella';

  /// [allowNullBookId] distinguishes "leave bookId alone" from
  /// "explicitly clear it". Default false preserves existing bookId.
  PlaybackState copyWith({
    String? bookId,
    bool allowNullBookId = false,
    int? chapterIdx,
    int? sentenceIdx,
    bool? isPlaying,
    double? speed,
    String? voiceId,
  }) {
    return PlaybackState(
      bookId: allowNullBookId ? bookId : (bookId ?? this.bookId),
      chapterIdx: chapterIdx ?? this.chapterIdx,
      sentenceIdx: sentenceIdx ?? this.sentenceIdx,
      isPlaying: isPlaying ?? this.isPlaying,
      speed: speed ?? this.speed,
      voiceId: voiceId ?? this.voiceId,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlaybackState &&
          bookId == other.bookId &&
          chapterIdx == other.chapterIdx &&
          sentenceIdx == other.sentenceIdx &&
          isPlaying == other.isPlaying &&
          speed == other.speed &&
          voiceId == other.voiceId;

  @override
  int get hashCode =>
      Object.hash(bookId, chapterIdx, sentenceIdx, isPlaying, speed, voiceId);

  @override
  String toString() =>
      'PlaybackState(bookId: $bookId, ch: $chapterIdx, sent: $sentenceIdx, '
      'playing: $isPlaying, speed: $speed, voice: $voiceId)';
}

/// Coordination seam between reader and TTS. keepAlive ensures the
/// cursor survives widget rebuilds for the reader session.
@Riverpod(keepAlive: true)
class PlaybackStateNotifier extends _$PlaybackStateNotifier {
  @override
  PlaybackState build() => const PlaybackState.idle();

  void setSentence(int i) => state = state.copyWith(sentenceIdx: i);

  void setChapter(int i, {int sentence = 0}) =>
      state = state.copyWith(chapterIdx: i, sentenceIdx: sentence);

  void setBook(String? bookId) {
    if (state.bookId == bookId) return;
    state = state.copyWith(
      bookId: bookId,
      allowNullBookId: bookId == null,
      chapterIdx: 0,
      sentenceIdx: 0,
    );
  }

  void setPlaying(bool p) => state = state.copyWith(isPlaying: p);

  void setSpeed(double s) =>
      state = state.copyWith(speed: s.clamp(0.5, 3.0).toDouble());

  void setVoice(String v) => state = state.copyWith(voiceId: v);
}
