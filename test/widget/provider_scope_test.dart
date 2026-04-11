import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:murmur/core/theme/murmur_theme_mode.dart';
import 'package:murmur/core/theme/theme_mode_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('ProviderScope — FND-03 Riverpod survives rebuild', () {
    testWidgets('themeModeControllerProvider persists across pump cycles',
        (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({'settings.themeMode': 'sepia'});

      MurmurThemeMode? readValue;

      Widget buildApp() => ProviderScope(
            child: MaterialApp(
              home: Consumer(
                builder: (context, ref, _) {
                  final async = ref.watch(themeModeControllerProvider);
                  readValue = async.value;
                  return const SizedBox();
                },
              ),
            ),
          );

      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();
      expect(readValue, MurmurThemeMode.sepia);

      // Force a full widget subtree rebuild. keepAlive: true means the
      // controller is NOT recreated even though the widget tree is.
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();
      expect(readValue, MurmurThemeMode.sepia,
          reason: 'Provider state must persist across pump/rebuild');
    });
  });
}
