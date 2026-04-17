import 'dart:async';
import 'dart:io';

import 'package:convert/convert.dart' show AccumulatorSink;
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import 'download_events.dart';

/// The one-and-only network call in the app.
///
///  - Hashes incrementally — never re-reads the file after write.
///  - On hash mismatch: delete `.partial`, emit retryable [DownloadError].
///  - On size overflow: delete `.partial`, emit non-retryable error.
///  - On user cancel: delete `.partial`, emit [DownloadCanceled].
///  - On network failure mid-stream: keep `.partial` so a later call can
///    resume with `Range: bytes=<len>-`.
///  - On server ignoring Range (200 when 206 expected): truncate the
///    partial and restart from zero.
class ModelDownloader {
  final http.Client _client;
  final bool _ownsClient;

  ModelDownloader({http.Client? client})
      : _client = client ?? http.Client(),
        _ownsClient = client == null;

  void dispose() {
    if (_ownsClient) _client.close();
  }

  Stream<DownloadEvent> download({
    required String url,
    required String expectedSha256,
    required int expectedBytes,
    required File partialFile,
    required int maxBytes,
    required Future<bool> Function() shouldCancel,
  }) async* {
    await partialFile.parent.create(recursive: true);

    var offset = partialFile.existsSync() ? partialFile.lengthSync() : 0;
    if (offset >= expectedBytes) {
      // Stale — bigger than expected. Start fresh.
      await _safeDelete(partialFile);
      offset = 0;
    }

    final acc = AccumulatorSink<Digest>();
    final hashInput = sha256.startChunkedConversion(acc);

    if (offset > 0) {
      final existing = await partialFile.readAsBytes();
      hashInput.add(existing);
    }

    http.StreamedResponse response;
    try {
      final req = http.Request('GET', Uri.parse(url));
      if (offset > 0) req.headers['Range'] = 'bytes=$offset-';
      response = await _client.send(req);
    } catch (e) {
      hashInput.close();
      yield DownloadError(NetworkException(e), retryable: true);
      return;
    }

    if (offset > 0 && response.statusCode == 200) {
      // Server ignored Range — drain, truncate, recurse fresh.
      await response.stream.drain<void>().catchError((_) {});
      hashInput.close();
      await partialFile.writeAsBytes(const <int>[], flush: true);
      yield* download(
        url: url,
        expectedSha256: expectedSha256,
        expectedBytes: expectedBytes,
        partialFile: partialFile,
        maxBytes: maxBytes,
        shouldCancel: shouldCancel,
      );
      return;
    }

    if (response.statusCode != 200 && response.statusCode != 206) {
      hashInput.close();
      await _safeDelete(partialFile);
      yield DownloadError(PartialResumeRejected(response.statusCode),
          retryable: true);
      return;
    }

    final sink = partialFile.openWrite(
      mode: offset > 0 ? FileMode.writeOnlyAppend : FileMode.writeOnly,
    );
    var written = offset;

    try {
      await for (final chunk in response.stream) {
        if (await shouldCancel()) {
          await sink.flush();
          await sink.close();
          hashInput.close();
          await _safeDelete(partialFile);
          yield const DownloadCanceled();
          return;
        }
        if (written + chunk.length > maxBytes) {
          await sink.flush();
          await sink.close();
          hashInput.close();
          await _safeDelete(partialFile);
          yield DownloadError(
              SizeOverflow(maxBytes, written + chunk.length),
              retryable: false);
          return;
        }
        sink.add(chunk);
        hashInput.add(chunk);
        written += chunk.length;
        yield DownloadProgress(written, expectedBytes);
      }
      await sink.flush();
      await sink.close();
    } catch (e) {
      await sink.close().catchError((_) {});
      hashInput.close();
      // Retain .partial so caller can resume.
      yield DownloadError(NetworkException(e), retryable: true);
      return;
    }

    yield const DownloadVerifying();
    hashInput.close();
    final actual = acc.events.single.toString();
    if (actual.toLowerCase() != expectedSha256.toLowerCase()) {
      await _safeDelete(partialFile);
      yield DownloadError(HashMismatch(expectedSha256, actual),
          retryable: true);
      return;
    }
    yield DownloadDone(partialFile.path);
  }

  static Future<void> _safeDelete(File f) async {
    try {
      if (await f.exists()) await f.delete();
    } catch (_) {
      // best effort
    }
  }
}
