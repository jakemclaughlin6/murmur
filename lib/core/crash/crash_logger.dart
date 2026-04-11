// STUB: Minimal stub for TDD RED phase. Full implementation follows in GREEN.
import 'dart:io';

import 'package:flutter/foundation.dart';

/// D-07..D-11: Local-only JSONL crash logger. (STUB)
class CrashLogger {
  CrashLogger._(this._file, this._deviceString, this._osString, this._appVersion);

  static const int maxBytes = 1 * 1024 * 1024;

  static const Set<String> jsonlFields = {
    'ts',
    'level',
    'error',
    'stack',
    'device',
    'os',
    'appVersion',
  };

  static CrashLogger? _instance;
  static CrashLogger get instance {
    final i = _instance;
    if (i == null) {
      throw StateError('CrashLogger.initialize() must be called before .instance');
    }
    return i;
  }

  final File _file;
  final String _deviceString;
  final String _osString;
  final String _appVersion;

  String get filePath => throw UnimplementedError();
  Future<int> currentSize() async => throw UnimplementedError();

  static Future<CrashLogger> initialize() async => throw UnimplementedError();

  @visibleForTesting
  static Future<CrashLogger> initializeForTest({
    required Directory docs,
    String appVersion = 'test+0',
    String device = 'test-device',
    String os = 'test-os',
  }) async => throw UnimplementedError();

  Future<void> logFlutterError(FlutterErrorDetails details) async => throw UnimplementedError();

  Future<void> logError(
    Object error,
    StackTrace stack, {
    String level = 'error',
  }) async => throw UnimplementedError();

  @visibleForTesting
  static void resetForTest() {
    _instance = null;
  }
}
