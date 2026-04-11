import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'crash_logger.dart';

part 'crash_logger_provider.g.dart';

/// Exposes the initialized CrashLogger singleton as a Riverpod provider.
///
/// The logger is initialized in `main.dart` (Plan 08) BEFORE `runApp`, so by
/// the time any widget reads this provider, `CrashLogger.instance` is safe
/// to call. Plan 08's Settings placeholder uses this to show:
/// - `logger.filePath` (plain text)
/// - `await logger.currentSize()` (byte count)
@Riverpod(keepAlive: true)
CrashLogger crashLogger(Ref ref) => CrashLogger.instance;
