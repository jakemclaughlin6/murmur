import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/crash/crash_logger_provider.dart';

class CrashLogStatusTile extends ConsumerWidget {
  const CrashLogStatusTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logger = ref.watch(crashLoggerProvider);
    return FutureBuilder<int>(
      future: logger.currentSize(),
      builder: (context, snapshot) {
        final sizeText = snapshot.hasData
            ? '${snapshot.data} bytes'
            : '—';
        return ListTile(
          key: const Key('crash-log-status-tile'),
          leading: const Icon(Icons.bug_report_outlined),
          title: const Text('Crash log'),
          subtitle: Text('${logger.filePath}\nSize: $sizeText'),
          isThreeLine: true,
        );
      },
    );
  }
}
