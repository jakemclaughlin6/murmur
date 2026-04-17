import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:murmur/features/tts/audio/wav_wrap.dart';

void main() {
  group('wavWrap', () {
    test('header is 44 bytes and contains RIFF/WAVE/fmt /data magic', () {
      final out = wavWrap(Float32List(10));
      expect(out.length, 44 + 20);
      expect(String.fromCharCodes(out.sublist(0, 4)), 'RIFF');
      expect(String.fromCharCodes(out.sublist(8, 12)), 'WAVE');
      expect(String.fromCharCodes(out.sublist(12, 16)), 'fmt ');
      expect(String.fromCharCodes(out.sublist(36, 40)), 'data');
    });

    test('header fields for 10 samples @ 24kHz mono PCM16', () {
      final out = wavWrap(Float32List(10));
      final bd = ByteData.sublistView(out);
      expect(bd.getUint32(4, Endian.little), 20 + 36); // riff size
      expect(bd.getUint16(20, Endian.little), 1); // PCM format
      expect(bd.getUint16(22, Endian.little), 1); // channels
      expect(bd.getUint32(24, Endian.little), 24000); // sample rate
      expect(bd.getUint32(28, Endian.little), 24000 * 2); // byte rate
      expect(bd.getUint16(32, Endian.little), 2); // block align
      expect(bd.getUint16(34, Endian.little), 16); // bits per sample
      expect(bd.getUint32(40, Endian.little), 20); // data size
    });

    test('clamps out-of-range samples to plus/minus 32767', () {
      final out = wavWrap(Float32List.fromList([1.5, -2.0, 0.999999, 0.0]));
      final bd = ByteData.sublistView(out, 44);
      expect(bd.getInt16(0, Endian.little), 32767);
      expect(bd.getInt16(2, Endian.little), -32767);
      expect(bd.getInt16(4, Endian.little), 32766); // (0.999999*32767).toInt()
      expect(bd.getInt16(6, Endian.little), 0);
    });

    test('replaces NaN with 0 and clamps Infinity', () {
      final out = wavWrap(Float32List.fromList([
        double.nan,
        double.infinity,
        double.negativeInfinity,
      ]));
      final bd = ByteData.sublistView(out, 44);
      expect(bd.getInt16(0, Endian.little), 0);
      expect(bd.getInt16(2, Endian.little), 32767);
      expect(bd.getInt16(4, Endian.little), -32767);
    });

    test('honours non-default sampleRate', () {
      for (final sr in [8000, 22050, 48000]) {
        final out = wavWrap(Float32List(2), sampleRate: sr);
        final bd = ByteData.sublistView(out);
        expect(bd.getUint32(24, Endian.little), sr);
        expect(bd.getUint32(28, Endian.little), sr * 2);
      }
    });

    test('rejects empty PCM and non-positive sampleRate', () {
      expect(() => wavWrap(Float32List(0)), throwsA(isA<ArgumentError>()));
      expect(() => wavWrap(Float32List(1), sampleRate: 0),
          throwsA(isA<ArgumentError>()));
      expect(() => wavWrap(Float32List(1), sampleRate: -1),
          throwsA(isA<ArgumentError>()));
    });

    test('byte-exact golden for 5 handcrafted samples', () {
      // 0.0 -> 0; 0.5 -> 16383 (0x3FFF); -0.5 -> -16383 (0xC001);
      // 1.0 -> 32767 (0x7FFF); -1.0 -> -32767 (0x8001).
      final out = wavWrap(Float32List.fromList([0.0, 0.5, -0.5, 1.0, -1.0]));
      expect(out.length, 54);
      final bd = ByteData.sublistView(out, 44);
      expect(bd.getInt16(0, Endian.little), 0);
      expect(bd.getInt16(2, Endian.little), 16383);
      expect(bd.getInt16(4, Endian.little), -16383);
      expect(bd.getInt16(6, Endian.little), 32767);
      expect(bd.getInt16(8, Endian.little), -32767);
    });
  });
}
