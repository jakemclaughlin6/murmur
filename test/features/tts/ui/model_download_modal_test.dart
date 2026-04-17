import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:murmur/features/tts/providers/model_status_provider.dart';
import 'package:murmur/features/tts/ui/model_download_modal.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeNotifier extends ModelStatusNotifier {
  _FakeNotifier(this._initial);
  final ModelStatus _initial;
  int cancels = 0;
  int retries = 0;
  int starts = 0;
  @override
  Future<ModelStatus> build() async => _initial;
  @override
  Future<void> startDownload() async {
    starts++;
  }
  @override
  Future<void> cancel() async {
    cancels++;
  }
  @override
  Future<void> retry() async {
    retries++;
  }
}

Future<void> pumpModal(WidgetTester t, ModelStatus state,
    // ignore: library_private_types_in_public_api
    {_FakeNotifier? notifier}) async {
  final n = notifier ?? _FakeNotifier(state);
  await t.pumpWidget(UncontrolledProviderScope(
    container: ProviderContainer(overrides: [
      modelStatusProvider.overrideWith(() => n),
    ]),
    child: const MaterialApp(home: ModelDownloadModal()),
  ));
  // Don't use pumpAndSettle — the idle-state UI has an indeterminate
  // LinearProgressIndicator (value: null) that animates forever.
  await t.pump();
  await t.pump(const Duration(milliseconds: 50));
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('idle: shows "Prefer Wi-Fi" label, does NOT mention "Wi-Fi only"',
      (t) async {
    await pumpModal(t, const ModelStatus(installed: false));
    expect(find.text('Prefer Wi-Fi'), findsOneWidget);
    expect(find.textContaining('Wi-Fi only'), findsNothing);
  });

  testWidgets('downloading: shows percent + progress bar', (t) async {
    await pumpModal(
      t,
      const ModelStatus(
        installed: false,
        downloading: true,
        currentBytes: 50 * 1024 * 1024,
        totalBytes: 100 * 1024 * 1024,
      ),
    );
    expect(find.textContaining('50'), findsWidgets);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
  });

  testWidgets('cancel tap invokes notifier.cancel()', (t) async {
    final n = _FakeNotifier(const ModelStatus(
        installed: false,
        downloading: true,
        currentBytes: 1,
        totalBytes: 2));
    await pumpModal(t, n._initial, notifier: n);
    await t.tap(find.text('Cancel'));
    await t.pump();
    expect(n.cancels, 1);
  });

  testWidgets('error state: shows Retry and invokes notifier.retry()',
      (t) async {
    final n = _FakeNotifier(const ModelStatus(
        installed: false, downloading: false, error: 'boom'));
    await pumpModal(t, n._initial, notifier: n);
    expect(find.text('Retry'), findsOneWidget);
    await t.tap(find.text('Retry'));
    await t.pump();
    expect(n.retries, 1);
  });
}
