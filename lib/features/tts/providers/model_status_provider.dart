import 'dart:async';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../model/download_events.dart';
import '../model/model_assets.dart';
import '../model/model_downloader.dart';
import '../model/model_installer.dart';
import '../model/model_manifest.dart';

part 'model_status_provider.g.dart';

class ModelStatus {
  final bool installed;
  final bool downloading;
  final int currentBytes;
  final int totalBytes;
  final Object? error;
  final bool canceled;
  const ModelStatus({
    required this.installed,
    this.downloading = false,
    this.currentBytes = 0,
    this.totalBytes = 0,
    this.error,
    this.canceled = false,
  });

  ModelStatus copyWith({
    bool? installed,
    bool? downloading,
    int? currentBytes,
    int? totalBytes,
    Object? error,
    bool clearError = false,
    bool? canceled,
  }) =>
      ModelStatus(
        installed: installed ?? this.installed,
        downloading: downloading ?? this.downloading,
        currentBytes: currentBytes ?? this.currentBytes,
        totalBytes: totalBytes ?? this.totalBytes,
        error: clearError ? null : (error ?? this.error),
        canceled: canceled ?? this.canceled,
      );
}

@Riverpod(keepAlive: true)
class ModelStatusNotifier extends _$ModelStatusNotifier {
  Completer<bool>? _cancelGate;

  @override
  Future<ModelStatus> build() async {
    final prefs = await SharedPreferences.getInstance();
    final installed = prefs.getBool(ModelInstaller.installedFlagKey) ?? false;
    return ModelStatus(installed: installed);
  }

  Future<void> startDownload() async {
    final current = state.value;
    if (current == null || current.installed || current.downloading) return;
    state = AsyncData(current.copyWith(
        downloading: true, clearError: true, canceled: false));

    _cancelGate = Completer<bool>();
    final support = await getApplicationSupportDirectory();
    final paths = await copyBundledKokoroAssets(support);
    final partial = File(
        '${paths.rootDir}${Platform.pathSeparator}kokoro.tar.bz2.partial');

    final dl = ModelDownloader();
    try {
      await for (final evt in dl.download(
        url: ModelManifest.downloadUrl,
        expectedSha256: ModelManifest.archiveSha256,
        expectedBytes: ModelManifest.archiveBytes,
        partialFile: partial,
        maxBytes: ModelManifest.downloadMaxBytes,
        shouldCancel: () async => _cancelGate?.isCompleted ?? false,
      )) {
        switch (evt) {
          case DownloadProgress():
            state = AsyncData(state.requireValue.copyWith(
              currentBytes: evt.bytesWritten,
              totalBytes: evt.totalBytes,
            ));
          case DownloadVerifying():
            break;
          case DownloadCanceled():
            state = AsyncData(state.requireValue
                .copyWith(downloading: false, canceled: true));
            return;
          case DownloadError(:final cause):
            state = AsyncData(state.requireValue
                .copyWith(downloading: false, error: cause));
            return;
          case DownloadDone(:final partialPath):
            final prefs = await SharedPreferences.getInstance();
            final finalDir = Directory(paths.rootDir);
            final stagingDir = Directory('${finalDir.path}.installing');
            await ModelInstaller().installFromArchive(
              archive: File(partialPath),
              finalDir: finalDir,
              stagingDir: stagingDir,
              prefs: prefs,
            );
            if (File(partialPath).existsSync()) {
              await File(partialPath).delete();
            }
            state = AsyncData(state.requireValue
                .copyWith(downloading: false, installed: true));
            ref.invalidateSelf();
            return;
        }
      }
    } catch (e) {
      state = AsyncData(
          state.requireValue.copyWith(downloading: false, error: e));
    } finally {
      dl.dispose();
    }
  }

  Future<void> cancel() async {
    final gate = _cancelGate;
    if (gate != null && !gate.isCompleted) gate.complete(true);
  }

  Future<void> retry() async => startDownload();
}
