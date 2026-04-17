import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:murmur/features/tts/model/download_events.dart';
import 'package:murmur/features/tts/model/model_downloader.dart';

void main() {
  const url = 'https://example.invalid/kokoro.tar.bz2';

  File seedPartial(Uint8List prefix) {
    final d = Directory.systemTemp.createTempSync('murmur_dl_resume_');
    addTearDown(() {
      if (d.existsSync()) d.deleteSync(recursive: true);
    });
    final f = File('${d.path}/kokoro.tar.bz2.partial');
    f.writeAsBytesSync(prefix);
    return f;
  }

  test('sends Range header and completes with matching digest', () async {
    final full = Uint8List.fromList(List.generate(4096, (i) => i % 251));
    final digest = sha256.convert(full).toString();
    final partial = seedPartial(Uint8List.sublistView(full, 0, 1024));

    final client = MockClient.streaming((req, _) async {
      expect(req.headers['Range'], 'bytes=1024-');
      return http.StreamedResponse(
        Stream.value(Uint8List.sublistView(full, 1024)),
        206,
        contentLength: full.length - 1024,
      );
    });

    final dl = ModelDownloader(client: client);
    final events = <DownloadEvent>[];
    await for (final e in dl.download(
      url: url,
      expectedSha256: digest,
      expectedBytes: full.length,
      partialFile: partial,
      maxBytes: 1 << 20,
      shouldCancel: () async => false,
    )) {
      events.add(e);
    }

    expect(events.last, isA<DownloadDone>());
    expect(partial.lengthSync(), full.length);
  });

  test('server ignores Range (200 full): truncate + restart', () async {
    final full = Uint8List.fromList(List.generate(2048, (i) => i % 251));
    final digest = sha256.convert(full).toString();
    final partial = seedPartial(Uint8List.sublistView(full, 0, 1024));

    // Mock is called twice: once with Range (server ignores it and returns 200
    // full), then again after the downloader truncates and retries fresh
    // (offset=0, no Range header). Both calls must be served.
    var call = 0;
    final client = MockClient.streaming((req, _) async {
      call++;
      if (call == 1) {
        expect(req.headers['Range'], 'bytes=1024-');
      } else {
        expect(req.headers.containsKey('Range'), isFalse);
      }
      return http.StreamedResponse(
        Stream.value(full),
        200,
        contentLength: full.length,
      );
    });

    final dl = ModelDownloader(client: client);
    final events = <DownloadEvent>[];
    await for (final e in dl.download(
      url: url,
      expectedSha256: digest,
      expectedBytes: full.length,
      partialFile: partial,
      maxBytes: 1 << 20,
      shouldCancel: () async => false,
    )) {
      events.add(e);
    }

    expect(events.last, isA<DownloadDone>());
    expect(partial.lengthSync(), full.length);
  });
}
