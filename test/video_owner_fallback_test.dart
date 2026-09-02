import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('video introduction never force-unwraps owner identity fields', () {
    final controller = File(
      'lib/pages/video/introduction/detail/controller.dart',
    ).readAsStringSync();
    final view = File(
      'lib/pages/video/introduction/detail/view.dart',
    ).readAsStringSync();

    expect(controller, isNot(contains('owner!.mid!')));
    expect(controller, isNot(contains('owner!.name!')));
    expect(view, isNot(contains('owner!.mid')));
    expect(view, isNot(contains('owner!.name')));
  });
}
