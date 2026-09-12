import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const debugProfileEntitlements = 'ios/Runner/DebugProfile.entitlements';
  const releaseEntitlements = 'ios/Runner/Release.entitlements';

  test(
    'iOS entitlement files declare an empty Keychain access group array',
    () {
      for (final path in <String>[
        debugProfileEntitlements,
        releaseEntitlements,
      ]) {
        final file = File(path);
        expect(file.existsSync(), isTrue, reason: '$path must exist');

        final contents = file.readAsStringSync();
        expect(contents, startsWith('<?xml version="1.0" encoding="UTF-8"?>'));
        expect(
          RegExp(
            r'<key>keychain-access-groups</key>\s*<array\s*/>',
            multiLine: true,
          ).allMatches(contents),
          hasLength(1),
        );
      }
    },
  );

  test('Runner configurations use the matching entitlement file', () {
    final project = File(
      'ios/Runner.xcodeproj/project.pbxproj',
    ).readAsStringSync();
    final configurations = _runnerConfigurations(project);

    expect(
      configurations.keys,
      containsAll(<String>['Debug', 'Profile', 'Release']),
    );
    expect(
      configurations['Debug'],
      contains('CODE_SIGN_ENTITLEMENTS = Runner/DebugProfile.entitlements;'),
    );
    expect(
      configurations['Profile'],
      contains('CODE_SIGN_ENTITLEMENTS = Runner/DebugProfile.entitlements;'),
    );
    expect(
      configurations['Release'],
      contains('CODE_SIGN_ENTITLEMENTS = Runner/Release.entitlements;'),
    );
  });

  test(
    'secure-storage configuration preserves the public bundle identifier',
    () {
      final project = File(
        'ios/Runner.xcodeproj/project.pbxproj',
      ).readAsStringSync();
      final configurations = _runnerConfigurations(project);

      expect(configurations, hasLength(3));
      for (final entry in configurations.entries) {
        expect(
          entry.value,
          contains('PRODUCT_BUNDLE_IDENTIFIER = io.github.gxwane.pilipalaz;'),
          reason: '${entry.key} must preserve the public application identity',
        );
      }
    },
  );
}

Map<String, String> _runnerConfigurations(String project) {
  final result = <String, String>{};
  final pattern = RegExp(
    r'isa = XCBuildConfiguration;\s*'
    r'(?:baseConfigurationReference = [^;]+;\s*)?'
    r'buildSettings = \{([\s\S]*?)\n\s*\};\s*'
    r'name = (Debug|Profile|Release);',
  );

  for (final match in pattern.allMatches(project)) {
    final settings = match.group(1)!;
    if (settings.contains('PRODUCT_BUNDLE_IDENTIFIER')) {
      result[match.group(2)!] = settings;
    }
  }
  return result;
}
