/// A curated Kokoro v0_19 English voice. `voiceId` is the stable string
/// persisted in Drift (`books.voice_id`) and shared_preferences. `sid`
/// is the sherpa-onnx positional speaker id — NEVER persist `sid`
/// directly (upstream could reorder in a future model release).
class VoiceEntry {
  final int sid;
  final String voiceId;
  final String label;
  const VoiceEntry(this.sid, this.voiceId, this.label);
}

class ModelManifest {
  static const String downloadUrl =
      'https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/kokoro-int8-en-v0_19.tar.bz2';

  /// SHA-256 of the tar.bz2 archive. Task 8 replaces this placeholder
  /// with the captured lowercase-hex digest.
  static const String archiveSha256 = 'PENDING_04_02';

  /// Verified via HEAD request to the GitHub release asset.
  static const int archiveBytes = 103248205;

  /// Hard cap during download — defense-in-depth DoS guard.
  static const int downloadMaxBytes = 150 * 1024 * 1024;

  /// 11 English voices shipped in kokoro-int8-en-v0_19 (D-06).
  static const List<VoiceEntry> voiceCatalog = [
    VoiceEntry(0, 'af', 'Default (American, female)'),
    VoiceEntry(1, 'af_bella', 'Bella (American, female)'),
    VoiceEntry(2, 'af_nicole', 'Nicole (American, female)'),
    VoiceEntry(3, 'af_sarah', 'Sarah (American, female)'),
    VoiceEntry(4, 'af_sky', 'Sky (American, female)'),
    VoiceEntry(5, 'am_adam', 'Adam (American, male)'),
    VoiceEntry(6, 'am_michael', 'Michael (American, male)'),
    VoiceEntry(7, 'bf_emma', 'Emma (British, female)'),
    VoiceEntry(8, 'bf_isabella', 'Isabella (British, female)'),
    VoiceEntry(9, 'bm_george', 'George (British, male)'),
    VoiceEntry(10, 'bm_lewis', 'Lewis (British, male)'),
  ];

  /// D-06 discretion: af_bella matches the voice used in the Wave 0 spike
  /// verification ("Welcome to murmur..." at sid=1).
  static const String defaultVoiceId = 'af_bella';

  /// D-08: one branded sentence, reused for every voice preview.
  static const String previewSentence =
      'Welcome to murmur. This is how I sound reading your books.';

  static VoiceEntry? byVoiceId(String id) {
    for (final v in voiceCatalog) {
      if (v.voiceId == id) return v;
    }
    return null;
  }
}
