import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/crash/crash_logger.dart';
import 'features/library/import_picker.dart' as import_picker;
import 'features/library/import_picker_provider.dart';

Future<void> main() async {
  // D-10: runZonedGuarded wraps everything so async errors outside the widget
  // tree still reach the CrashLogger.
  await runZonedGuarded<Future<void>>(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Initialize CrashLogger BEFORE any runApp or provider access — so the
    // next line's setup code is itself covered by the crash handlers.
    await CrashLogger.initialize();

    // Sync errors from Flutter framework (build, paint, layout, etc).
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details); // keep the debug console red in debug
      unawaited(CrashLogger.instance.logFlutterError(details));
    };

    // Async / platform errors that escape the widget framework (isolates,
    // timers without .catchError, native channel errors).
    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      unawaited(
        CrashLogger.instance.logError(error, stack, level: 'platform'),
      );
      return true; // marked as handled; prevents hard crash in release builds
    };

    runApp(
      ProviderScope(
        overrides: [
          // Wire the real file-picker entry point. This override lives
          // in main.dart (not library_screen.dart) so that test code
          // loading LibraryScreen never pulls file_picker's Windows
          // impl into the analysis graph — see import_picker_provider.dart.
          importPickerCallbackProvider.overrideWithValue(
            (ref) => import_picker.pickAndImportEpubs(ref),
          ),
        ],
        child: const MurmurApp(),
      ),
    );
  }, (Object error, StackTrace stack) {
    // Zone-level catch for anything that still slips through both handlers above.
    // CrashLogger may not be initialized if the failure happened during
    // initialize() itself — guard accordingly.
    try {
      unawaited(CrashLogger.instance.logError(error, stack, level: 'zone'));
    } on StateError {
      // CrashLogger not initialized yet — fall back to stderr.
      debugPrint('CRASH (pre-init): $error\n$stack');
    }
  });
}
