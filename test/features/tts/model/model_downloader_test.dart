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

  File makePartial() {
    final d = Directory.systemTemp.createTempSync('murmur_dl_');
    addTearDown(() {
      if (d.existsSync()) d.deleteSync(recursive: true);
    });
    return File('${d.path}/kokoro.tar.bz2.partial');
  }

  Future<List<DownloadEvent>> collect(Stream<DownloadEvent> s) async =>
      [await for (final e in s) e];

  test('happy path: 200 full, hash matches -> Progress* + Verifying + Done',
      () async {
    final bytes = Uint8List.fromList(List.generate(4096, (i) => i % 251));
    final digest = sha256.convert(bytes).toString();
    final partial = makePartial();

    final client = MockClient.streaming((req, _) async {
      expect(req.headers.containsKey('Range'), isFalse);
      return http.StreamedResponse(
        Stream.fromIterable([bytes.sublist(0, 1024), bytes.sublist(1024)]),
        200,
        contentLength: bytes.length,
      );
    });

    final dl = ModelDownloader(client: client);
    final events = await collect(dl.download(
      url: url,
      expectedSha256: digest,
      expectedBytes: bytes.length,
      partialFile: partial,
      maxBytes: 1 << 20,
      shouldCancel: () async => false,
    ));

    expect(events.whereType<DownloadProgress>().isNotEmpty, isTrue);
    expect(events.whereType<DownloadVerifying>().length, 1);
    expect(events.last, isA<DownloadDone>());
    expect(partial.existsSync(), isTrue);
    expect(partial.lengthSync(), bytes.length);
  });

  test('hash mismatch: .partial deleted, retryable error', () async {
    final bytes = Uint8List.fromList(List.filled(512, 7));
    final partial = makePartial();
    final client = MockClient.streaming((req, _) async =>
        http.StreamedResponse(Stream.value(bytes), 200,
            contentLength: bytes.length));

    final dl = ModelDownloader(client: client);
    final events = await collect(dl.download(
      url: url,
      expectedSha256:
          '0000000000000000000000000000000000000000000000000000000000000000',
      expectedBytes: bytes.length,
      partialFile: partial,
      maxBytes: 1 << 20,
      shouldCancel: () async => false,
    ));

    final err = events.last as DownloadError;
    expect(err.cause, isA<HashMismatch>());
    expect(err.retryable, isTrue);
    expect(partial.existsSync(), isFalse);
  });

  test('size overflow: aborts, deletes .partial, non-retryable', () async {
    final partial = makePartial();
    final client = MockClient.streaming((req, _) async =>
        http.StreamedResponse(Stream.value(Uint8List(200)), 200,
            contentLength: 200));
    final dl = ModelDownloader(client: client);
    final events = await collect(dl.download(
      url: url,
      expectedSha256: 'x' * 64,
      expectedBytes: 200,
      partialFile: partial,
      maxBytes: 100,
      shouldCancel: () async => false,
    ));
    final err = events.last as DownloadError;
    expect(err.cause, isA<SizeOverflow>());
    expect(err.retryable, isFalse);
    expect(partial.existsSync(), isFalse);
  });

  test('cancel between chunks: Canceled + .partial deleted', () async {
    final partial = makePartial();
    var seen = 0;
    final client = MockClient.streaming((req, _) async =>
        http.StreamedResponse(
          Stream.fromIterable(List.generate(8, (_) => Uint8List(128))),
          200,
          contentLength: 1024,
        ));
    final dl = ModelDownloader(client: client);

    Future<bool> cancelAfter2() async => ++seen >= 2;

    final events = await collect(dl.download(
      url: url,
      expectedSha256: 'x' * 64,
      expectedBytes: 1024,
      partialFile: partial,
      maxBytes: 1 << 20,
      shouldCancel: cancelAfter2,
    ));
    expect(events.last, isA<DownloadCanceled>());
    expect(partial.existsSync(), isFalse);
  });
}
