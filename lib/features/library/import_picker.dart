/// LIB-01 file picker entry point — kept in its own file so
/// `import_service_test.dart` does not have to transitively compile
/// `package:file_picker/file_picker.dart`.
///
/// file_picker's main library exports its Windows implementation
/// unconditionally on the VM, and the Windows impl is incompatible with
/// our `win32: ^6.0.0` override (see pubspec.yaml and 02-01
/// spike-notes.md). Keeping the file_picker import isolated here means
/// the ImportNotifier itself stays pure enough to run under
/// `flutter test` against real fixture EPUBs without pulling in the
/// broken Windows path.
///
/// The UI layer (Plan 06's library screen) imports this file; tests do
/// not. Per D-14 this is still the same pipeline as
/// [ImportNotifier.importFromPaths] — it just does the `file_picker`
/// call first and delegates the resolved paths straight through.
library;

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'import_service.dart';

/// Opens the system file picker, filters to `.epub`, and delegates the
/// selected file paths to [ImportNotifier.importFromPaths].
///
/// No-op if the user cancels the picker or selects nothing.
Future<void> pickAndImportEpubs(WidgetRef ref) async {
  final result = await FilePicker.pickFiles(
    allowMultiple: true,
    type: FileType.custom,
    allowedExtensions: const ['epub'],
  );
  if (result == null || result.files.isEmpty) return;

  final paths = result.files
      .map((f) => f.path)
      .whereType<String>()
      .where((path) => path.isNotEmpty)
      .toList();
  if (paths.isEmpty) return;

  await ref.read(importProvider.notifier).importFromPaths(paths);
}
