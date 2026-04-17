import 'dart:typed_data';

/// Wraps a Float32 mono PCM buffer in a 44-byte PCM16 WAV container.
///
/// Kokoro occasionally overshoots ±1.0 on fricatives — the clamp is
/// mandatory. NaN is rewritten to 0; ±Infinity clamps to ±1.0, so
/// the int16 cast cannot wrap around into an audible click.
Uint8List wavWrap(Float32List pcm, {int sampleRate = 24000}) {
  if (pcm.isEmpty) {
    throw ArgumentError.value(pcm.length, 'pcm.length', 'must be non-empty');
  }
  if (sampleRate <= 0) {
    throw ArgumentError.value(sampleRate, 'sampleRate', 'must be positive');
  }

  const headerSize = 44;
  const channels = 1;
  const bitsPerSample = 16;
  final dataSize = pcm.length * 2;
  final riffSize = dataSize + 36;
  final byteRate = sampleRate * channels * (bitsPerSample ~/ 8);
  const blockAlign = channels * (bitsPerSample ~/ 8);

  final bytes = Uint8List(headerSize + dataSize);
  final bd = ByteData.sublistView(bytes);

  bytes[0] = 0x52; bytes[1] = 0x49; bytes[2] = 0x46; bytes[3] = 0x46; // RIFF
  bd.setUint32(4, riffSize, Endian.little);
  bytes[8] = 0x57; bytes[9] = 0x41; bytes[10] = 0x56; bytes[11] = 0x45; // WAVE

  bytes[12] = 0x66; bytes[13] = 0x6d; bytes[14] = 0x74; bytes[15] = 0x20; // 'fmt '
  bd.setUint32(16, 16, Endian.little);
  bd.setUint16(20, 1, Endian.little); // PCM
  bd.setUint16(22, channels, Endian.little);
  bd.setUint32(24, sampleRate, Endian.little);
  bd.setUint32(28, byteRate, Endian.little);
  bd.setUint16(32, blockAlign, Endian.little);
  bd.setUint16(34, bitsPerSample, Endian.little);

  bytes[36] = 0x64; bytes[37] = 0x61; bytes[38] = 0x74; bytes[39] = 0x61; // 'data'
  bd.setUint32(40, dataSize, Endian.little);

  for (var i = 0; i < pcm.length; i++) {
    final s = pcm[i];
    final f = s.isNaN ? 0.0 : s.clamp(-1.0, 1.0).toDouble();
    bd.setInt16(headerSize + i * 2, (f * 32767).toInt(), Endian.little);
  }
  return bytes;
}
