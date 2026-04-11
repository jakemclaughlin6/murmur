/// Plan 02-07: overridable entry point for the file-picker import flow.
///
/// [LibraryScreen] cannot import `import_picker.dart` directly because
/// that file transitively imports `package:file_picker/file_picker.dart`,
/// which exports the Windows impl — and the Windows impl is
/// incompatible with our `win32: ^6.0.0` override (see 02-05
/// D-02-05-A). Importing file_picker from library_screen.dart would
/// break `flutter test` compilation for every test that loads the
/// library screen.
///
/// Solution: declare the callback provider in a file that does NOT
/// import file_picker. Production overrides this provider at
/// `runApp` time in `lib/main.dart` (or equivalent boot point) with
/// the real `pickAndImportEpubs` function from `import_picker.dart`.
/// Tests override it with a spy and assert it was invoked.
///
/// This keeps LibraryScreen's test-time import graph clear of the
/// broken file_picker Windows impl while still letting the real
/// import-picker fire in production.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Signature of the import-picker callback. Takes a [WidgetRef] because
/// the real implementation calls into `importProvider.notifier`.
typedef ImportPickerCallback = Future<void> Function(WidgetRef ref);

/// Default no-op import picker. Production overrides with the real
/// `pickAndImportEpubs`; tests override with a spy.
///
/// We use `Provider<ImportPickerCallback>` instead of `@Riverpod` codegen
/// because the generator struggles with a function typedef return type,
/// and this file is tiny enough that codegen is overkill.
final importPickerCallbackProvider = Provider<ImportPickerCallback>(
  (ref) => (WidgetRef ref) async {
    // Unwired in tests; production overrides this at runApp time.
  },
);
