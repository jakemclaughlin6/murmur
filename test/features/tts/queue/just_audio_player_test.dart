import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_audio_player.dart';

void main() {
  test('records setFile path and play call', () async {
    final fake = FakeAudioPlayerHandle();
    await fake.setFile('/tmp/a.wav');
    await fake.play();
    expect(fake.calls, ['setFile', 'play']);
    expect(fake.setFilePaths, ['/tmp/a.wav']);
  });

  test('simulateCompleted drives completedStream', () async {
    final fake = FakeAudioPlayerHandle();
    final events = <void>[];
    final sub = fake.completedStream.listen(events.add);
    fake.simulateCompleted();
    fake.simulateCompleted();
    await Future<void>.delayed(Duration.zero);
    expect(events.length, 2);
    await sub.cancel();
  });

  test('setSpeed records value; dispose sets disposed', () async {
    final fake = FakeAudioPlayerHandle();
    await fake.setSpeed(1.75);
    await fake.dispose();
    expect(fake.setSpeedValues, [1.75]);
    expect(fake.disposed, isTrue);
  });
}
