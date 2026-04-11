/// LIB-02 Share/Open-in listener — routes incoming share intents through
/// the same [ImportNotifier] pipeline as the file picker per D-14.
///
/// Architecture:
///
///   [ShareIntentSource] (abstract)
///       ├── [ReceiveSharingIntentSource] — real package impl, production
///       └── [FakeShareIntentSource] — in-memory, tests
///
///   [shareIntentSourceProvider] (Riverpod) returns the platform source
///   [shareIntentListenerProvider] (Riverpod) observes the source and
///       dispatches EPUB paths to [ImportNotifier.importFromPaths]
///
/// The source abstraction is the testability seam. Tests override
/// [shareIntentSourceProvider] with a fake; production code never
/// notices the seam.
///
/// Threat mitigations:
/// - T-02-05-01 (spoofed intent): the listener filters by
///   `.epub` suffix before calling into the importer. The OS intent
///   filter (AndroidManifest.xml) already restricts to
///   `application/epub+zip`, but nothing prevents a buggy sender app
///   from advertising the wrong MIME — defense in depth.
library;

import 'dart:async';

import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'import_service.dart';

part 'share_intent_listener.g.dart';

// ---------------------------------------------------------------------------
// ShareIntentSource — abstract seam over the platform plugin.
// ---------------------------------------------------------------------------

/// Platform-agnostic share-intent source.
///
/// Abstracts the two surfaces that `receive_sharing_intent` exposes:
///   - `getInitialMedia()` — returns media supplied by a cold-start
///     Share / Open-in intent (the app was launched FROM the share).
///   - `getMediaStream()` — hot stream of share events delivered while
///     the app is already running.
///
/// The concrete types in the plugin carry `SharedMediaFile` records with
/// a `path` field and a media-type discriminator; we narrow to just
/// `List<String>` of file paths here because that is all the listener
/// needs. The listener then applies its own extension filter on top.
abstract class ShareIntentSource {
  /// Returns the list of file paths delivered by the initial launch
  /// intent, or an empty list when the app was not launched from a
  /// share.
  Future<List<String>> getInitialPaths();

  /// Hot stream of file path batches from runtime share events.
  Stream<List<String>> getPathStream();

  /// Tells the OS-side plugin the initial media has been consumed so
  /// it is not delivered again on the next cold start.
  Future<void> reset();
}

/// Production implementation backed by `receive_sharing_intent`.
///
/// The plugin's `SharedMediaFile` carries extra fields (thumbnail,
/// duration, mimeType) that we do not need — projecting down to a
/// `List<String>` here keeps the listener's surface small.
class ReceiveSharingIntentSource implements ShareIntentSource {
  const ReceiveSharingIntentSource();

  @override
  Future<List<String>> getInitialPaths() async {
    final initial = await ReceiveSharingIntent.instance.getInitialMedia();
    return initial.map((m) => m.path).toList(growable: false);
  }

  @override
  Stream<List<String>> getPathStream() {
    return ReceiveSharingIntent.instance
        .getMediaStream()
        .map((files) => files.map((m) => m.path).toList(growable: false));
  }

  @override
  Future<void> reset() async {
    await ReceiveSharingIntent.instance.reset();
  }
}

// ---------------------------------------------------------------------------
// Providers.
// ---------------------------------------------------------------------------

/// The platform share-intent source.
///
/// In production this returns [ReceiveSharingIntentSource]. Tests
/// override with a fake via `ProviderContainer(overrides: [...])`.
@Riverpod(keepAlive: true)
ShareIntentSource shareIntentSource(Ref ref) {
  return const ReceiveSharingIntentSource();
}

/// The share-intent listener. Its `build()` drains initial media
/// (cold-start intent) and then subscribes to the runtime stream.
///
/// `keepAlive: true` because the listener must outlive every screen
/// rebuild — dropping the subscription would mean a share event
/// received while the library screen is being rebuilt disappears.
///
/// Root widget must `ref.watch(shareIntentListenerProvider)` once so
/// the provider's `build()` actually runs.
@Riverpod(keepAlive: true)
class ShareIntentListener extends _$ShareIntentListener {
  StreamSubscription<List<String>>? _subscription;

  @override
  Future<void> build() async {
    final source = ref.read(shareIntentSourceProvider);

    // 1. Handle the cold-start intent (app was launched from Share /
    //    Open-in). Route it through the same pipeline as runtime
    //    events per D-14, then tell the plugin we consumed it.
    final initial = await source.getInitialPaths();
    if (initial.isNotEmpty) {
      _routeToImporter(initial);
      await source.reset();
    }

    // 2. Subscribe to runtime events. The subscription is torn down
    //    via `ref.onDispose` so tests and hot-reload cleanly release.
    _subscription = source.getPathStream().listen(_routeToImporter);
    ref.onDispose(() {
      _subscription?.cancel();
      _subscription = null;
    });
  }

  /// Filter [paths] down to EPUBs (case-insensitive `.epub` suffix) and
  /// hand them to [ImportNotifier.importFromPaths]. Empty after filter
  /// is a no-op so junk intents never wake the importer.
  void _routeToImporter(List<String> paths) {
    final epubPaths = paths
        .where((path) => path.toLowerCase().endsWith('.epub'))
        .toList(growable: false);
    if (epubPaths.isEmpty) return;
    // Unawaited on purpose — the listener fires and forgets. The
    // importer publishes per-file progress via its own state, which
    // the library screen observes independently.
    unawaited(
      ref.read(importProvider.notifier).importFromPaths(epubPaths),
    );
  }
}
