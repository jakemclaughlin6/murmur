import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:murmur/core/playback_state.dart';

void main() {
  group('PlaybackState', () {
    test('idle defaults', () {
      const s = PlaybackState.idle();
      expect(s.bookId, isNull);
      expect(s.chapterIdx, 0);
      expect(s.sentenceIdx, 0);
      expect(s.isPlaying, false);
      expect(s.speed, 1.0);
      expect(s.voiceId, 'af_bella');
    });

    test('equality + hashCode cover all fields', () {
      const a = PlaybackState(
        bookId: '1',
        chapterIdx: 2,
        sentenceIdx: 3,
        isPlaying: true,
        speed: 1.25,
        voiceId: 'am_adam',
      );
      const b = PlaybackState(
        bookId: '1',
        chapterIdx: 2,
        sentenceIdx: 3,
        isPlaying: true,
        speed: 1.25,
        voiceId: 'am_adam',
      );
      const c = PlaybackState(
        bookId: '1',
        chapterIdx: 2,
        sentenceIdx: 4,
        isPlaying: true,
        speed: 1.25,
        voiceId: 'am_adam',
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a, isNot(equals(c)));
    });

    test('copyWith preserves unset fields', () {
      const base = PlaybackState.idle();
      final next = base.copyWith(sentenceIdx: 7);
      expect(next.sentenceIdx, 7);
      expect(next.bookId, base.bookId);
      expect(next.voiceId, base.voiceId);
    });

    test('copyWith clears bookId only when allowNullBookId: true', () {
      const base = PlaybackState(
        bookId: 'x',
        chapterIdx: 3,
        sentenceIdx: 4,
        isPlaying: true,
        speed: 1.0,
        voiceId: 'af',
      );
      final cleared = base.copyWith(bookId: null, allowNullBookId: true);
      expect(cleared.bookId, isNull);

      final preserved = base.copyWith();
      expect(preserved.bookId, 'x');
    });
  });

  group('PlaybackStateNotifier', () {
    ProviderContainer makeContainer() {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      return c;
    }

    test('build returns idle', () {
      final c = makeContainer();
      expect(c.read(playbackStateProvider), const PlaybackState.idle());
    });

    test('setSentence updates only sentenceIdx', () {
      final c = makeContainer();
      c.read(playbackStateProvider.notifier).setSentence(9);
      expect(c.read(playbackStateProvider).sentenceIdx, 9);
      expect(c.read(playbackStateProvider).chapterIdx, 0);
    });

    test('setBook resets chapter/sentence; re-setBook resets again', () {
      final c = makeContainer();
      final n = c.read(playbackStateProvider.notifier);
      n.setSentence(5);
      n.setChapter(3);
      n.setBook('b1');
      expect(c.read(playbackStateProvider).bookId, 'b1');
      expect(c.read(playbackStateProvider).chapterIdx, 0);
      expect(c.read(playbackStateProvider).sentenceIdx, 0);

      n.setSentence(8);
      n.setBook('b2');
      expect(c.read(playbackStateProvider).bookId, 'b2');
      expect(c.read(playbackStateProvider).sentenceIdx, 0);
    });

    test('setSpeed clamps to [0.5, 3.0]', () {
      final c = makeContainer();
      final n = c.read(playbackStateProvider.notifier);
      n.setSpeed(2.5);
      expect(c.read(playbackStateProvider).speed, 2.5);
      n.setSpeed(5.0);
      expect(c.read(playbackStateProvider).speed, 3.0);
      n.setSpeed(0.1);
      expect(c.read(playbackStateProvider).speed, 0.5);
    });

    test('setVoice + setPlaying', () {
      final c = makeContainer();
      final n = c.read(playbackStateProvider.notifier);
      n.setVoice('bm_lewis');
      n.setPlaying(true);
      final s = c.read(playbackStateProvider);
      expect(s.voiceId, 'bm_lewis');
      expect(s.isPlaying, true);
    });

    test('two rapid mutations emit two distinct states', () {
      final c = makeContainer();
      final states = <PlaybackState>[];
      c.listen<PlaybackState>(
        playbackStateProvider,
        (_, next) => states.add(next),
        fireImmediately: true,
      );
      final n = c.read(playbackStateProvider.notifier);
      n.setSentence(1);
      n.setSentence(2);
      expect(states.map((s) => s.sentenceIdx).toList(), [0, 1, 2]);
    });
  });
}
