/// Wave 0 stub — persistence across restart.
///
/// Covers LIB-11 per 02-VALIDATION.md. D-04/D-05: Drift v1→v2 migration
/// introduces `books` + `chapters`. After an app restart the imported
/// library re-hydrates from the Drift DB unchanged. Real tests land in
/// Plan 02-08.
library;

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Library persistence', () {
    test(
      'TODO: imported books re-hydrate from Drift after app restart with identical metadata',
      () {},
      skip: 'Wave 0 stub — implemented by Plan 08',
    );
  });
}
