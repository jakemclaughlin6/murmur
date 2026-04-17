import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/model_status_provider.dart';

class ModelDownloadModal extends ConsumerStatefulWidget {
  const ModelDownloadModal({super.key});
  @override
  ConsumerState<ModelDownloadModal> createState() => _ModelDownloadModalState();
}

class _ModelDownloadModalState extends ConsumerState<ModelDownloadModal> {
  static const _preferWifiKey = 'tts.prefer_wifi';
  bool _preferWifi = true;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) {
      if (!mounted) return;
      setState(() => _preferWifi = p.getBool(_preferWifiKey) ?? true);
    });
  }

  Future<void> _setPreferWifi(bool v) async {
    setState(() => _preferWifi = v);
    final p = await SharedPreferences.getInstance();
    await p.setBool(_preferWifiKey, v);
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(modelStatusProvider);
    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(title: const Text('Download voice model')),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => _errorBody(e),
            data: _dataBody,
          ),
        ),
      ),
    );
  }

  Widget _dataBody(ModelStatus s) {
    if (s.error != null) return _errorBody(s.error!);
    if (s.installed) return const Center(child: Text('Voice model ready.'));
    final progress =
        s.totalBytes == 0 ? 0.0 : s.currentBytes / s.totalBytes;
    final mb = (s.currentBytes / (1024 * 1024)).toStringAsFixed(1);
    final total = (s.totalBytes / (1024 * 1024)).toStringAsFixed(1);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${(progress * 100).toStringAsFixed(0)}%',
          style: Theme.of(context).textTheme.displaySmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text('$mb MB / $total MB', textAlign: TextAlign.center),
        const SizedBox(height: 16),
        LinearProgressIndicator(value: s.downloading ? progress : null),
        const SizedBox(height: 16),
        const Text(
          'You can leave this screen — the download continues in the background.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        SwitchListTile(
          title: const Text('Prefer Wi-Fi'),
          subtitle: const Text(
              'Honor-system — the app does not block cellular.'),
          value: _preferWifi,
          onChanged: _setPreferWifi,
        ),
        const SizedBox(height: 16),
        if (!s.downloading && !s.canceled)
          FilledButton(
            onPressed: () => ref
                .read(modelStatusProvider.notifier)
                .startDownload(),
            child: const Text('Download'),
          ),
        if (s.downloading)
          OutlinedButton(
            onPressed: () =>
                ref.read(modelStatusProvider.notifier).cancel(),
            child: const Text('Cancel'),
          ),
        if (s.canceled)
          FilledButton(
            onPressed: () =>
                ref.read(modelStatusProvider.notifier).retry(),
            child: const Text('Retry'),
          ),
      ],
    );
  }

  Widget _errorBody(Object e) => Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('Download failed: $e', textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () =>
                ref.read(modelStatusProvider.notifier).retry(),
            child: const Text('Retry'),
          ),
        ],
      );
}
