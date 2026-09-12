import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final infoPlist = File('ios/Runner/Info.plist').readAsStringSync();
  final podfile = File('ios/Podfile').readAsStringSync();

  test('iOS plist exposes only the approved privacy declarations', () {
    final photoDescription = _stringValueForKey(
      infoPlist,
      'NSPhotoLibraryAddUsageDescription',
    );
    expect(photoDescription.trim(), isNotEmpty);

    for (final key in <String>{
      'NSCameraUsageDescription',
      'NSAppleMusicUsageDescription',
      'NSAppTransportSecurity',
      'NSBonjourServices',
      'LSApplicationQueriesSchemes',
    }) {
      expect(infoPlist, isNot(contains('<key>$key</key>')));
    }
  });

  test('iOS retains only audio background execution', () {
    expect(_arrayValuesForKey(infoPlist, 'UIBackgroundModes'), <String>[
      'audio',
    ]);
  });

  test('iOS keeps the custom URL scheme and application identity', () {
    final urlSchemes =
        RegExp(
          r'<key>CFBundleURLSchemes</key>\s*<array>([\s\S]*?)</array>',
        ).allMatches(infoPlist).expand((match) {
          return RegExp(
            r'<string>([^<]*)</string>',
          ).allMatches(match.group(1)!).map((value) => value.group(1)!);
        });
    final project = File(
      'ios/Runner.xcodeproj/project.pbxproj',
    ).readAsStringSync();
    final bundleIds = RegExp(
      r'PRODUCT_BUNDLE_IDENTIFIER\s*=\s*([^;]+);',
    ).allMatches(project).map((match) => match.group(1)!.trim()).toSet();

    expect(urlSchemes, contains('bilibili'));
    expect(bundleIds, {'io.github.gxwane.pilipalaz'});
  });

  test('permission_handler compiles only add-only Photos access', () {
    const permissionMacros = <String, String>{
      'PERMISSION_PHOTOS': '0',
      'PERMISSION_PHOTOS_ADD_ONLY': '1',
      'PERMISSION_CAMERA': '0',
      'PERMISSION_MEDIA_LIBRARY': '0',
      'PERMISSION_NOTIFICATIONS': '0',
    };

    for (final entry in permissionMacros.entries) {
      final definitions = RegExp(
        '${entry.key}=([01])',
      ).allMatches(podfile).map((match) => match.group(1)).toList();
      expect(definitions, <String?>[entry.value], reason: entry.key);
    }
  });
}

String _stringValueForKey(String plist, String key) {
  final match = RegExp(
    '<key>$key</key>\\s*<string>([^<]*)</string>',
  ).firstMatch(plist);
  expect(match, isNotNull, reason: 'Missing $key');
  return match!.group(1)!;
}

List<String> _arrayValuesForKey(String plist, String key) {
  final match = RegExp(
    '<key>$key</key>\\s*<array>([\\s\\S]*?)</array>',
  ).firstMatch(plist);
  expect(match, isNotNull, reason: 'Missing $key');
  return RegExp(
    r'<string>([^<]*)</string>',
  ).allMatches(match!.group(1)!).map((value) => value.group(1)!).toList();
}
