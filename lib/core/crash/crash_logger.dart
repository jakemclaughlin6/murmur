import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

/// D-07..D-11: Local-only JSONL crash logger.
///
/// Writes to `${appDocumentsDir}/crashes/crashes.log` with a strict 7-field
/// schema. Rotates at 1 MB via atomic rename to `crashes.1.log` (replacing any
/// previous backup). Per-write flush — a crash is a "fsync or lose it" moment.
class CrashLogger {
  CrashLogger._(this._file, this._deviceString, this._osString, this._appVersion);

  /// D-08: 1 MB cap.
  static const int maxBytes = 1 * 1024 * 1024;

  /// D-07: the 7 field names used in every JSONL entry.
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

  String get filePath => _file.path;
  Future<int> currentSize() async => _file.existsSync() ? _file.length() : 0;

  /// Production initializer. Called from Plan 08's main.dart before runApp().
  static Future<CrashLogger> initialize() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/crashes');
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }
    final file = File('${dir.path}/crashes.log');
    if (!file.existsSync()) {
      await file.create();
    }

    String appVersion;
    try {
      final info = await PackageInfo.fromPlatform();
      appVersion = '${info.version}+${info.buildNumber}';
    } catch (_) {
      appVersion = 'unknown+0';
    }

    _instance = CrashLogger._(
      file,
      _describeDevice(),
      _describeOs(),
      appVersion,
    );
    return _instance!;
  }

  /// Test-only initializer. Use from flutter_test to avoid platform channels.
  @visibleForTesting
  static Future<CrashLogger> initializeForTest({
    required Directory docs,
    String appVersion = 'test+0',
    String device = 'test-device',
    String os = 'test-os',
  }) async {
    final dir = Directory('${docs.path}/crashes');
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }
    final file = File('${dir.path}/crashes.log');
    if (!file.existsSync()) {
      await file.create();
    }
    _instance = CrashLogger._(file, device, os, appVersion);
    return _instance!;
  }

  /// Wrapper for FlutterError.onError. Logs at level 'flutter'.
  Future<void> logFlutterError(FlutterErrorDetails details) async {
    await logError(
      details.exception,
      details.stack ?? StackTrace.empty,
      level: 'flutter',
    );
  }

  /// Main entry. Writes one JSONL line with the 7 D-07 fields.
  Future<void> logError(
    Object error,
    StackTrace stack, {
    String level = 'error',
  }) async {
    final entry = <String, dynamic>{
      'ts': DateTime.now().toUtc().toIso8601String(),
      'level': level,
      'error': error.toString(),
      'stack': stack.toString(),
      'device': _deviceString,
      'os': _osString,
      'appVersion': _appVersion,
    };
    final line = jsonEncode(entry);

    await _rotateIfNeeded();
    // Per-write flush (D discretion) — durability over latency for error path.
    await _file.writeAsString('$line\n', mode: FileMode.append, flush: true);
  }

  Future<void> _rotateIfNeeded() async {
    if (!_file.existsSync()) {
      await _file.create();
      return;
    }
    final size = await _file.length();
    if (size < maxBytes) return;

    // D-08: rename to crashes.1.log, OVERWRITING any previous .1.log.
    // Max on-disk = 2 MB (current + one backup).
    final rotated = File('${_file.parent.path}/crashes.1.log');
    if (rotated.existsSync()) {
      await rotated.delete();
    }
    await _file.rename(rotated.path);
    // Start a fresh crashes.log at the same path.
    await File(_file.path).create();
  }

  static String _describeDevice() {
    if (Platform.isAndroid) return 'android-device';
    if (Platform.isIOS) return 'ios-device';
    return Platform.operatingSystem;
  }

  static String _describeOs() =>
      '${Platform.operatingSystem} ${Platform.operatingSystemVersion}';

  /// Test helper — clears the singleton so initialize/initializeForTest can be
  /// called again in a new test.
  @visibleForTesting
  static void resetForTest() {
    _instance = null;
  }
}
