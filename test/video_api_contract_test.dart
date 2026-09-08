import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:pilipalaz/http/api.dart';
import 'package:pilipalaz/http/api_result.dart';
import 'package:pilipalaz/http/video_api.dart';
import 'package:pilipalaz/models/video/play/url.dart';
import 'package:pilipalaz/utils/storage.dart';

import 'support/http_test_harness.dart';

void main() {
  late Directory hiveDirectory;

  setUpAll(() async {
    hiveDirectory = await Directory.systemTemp.createTemp(
      'pilipalaz_video_api_test_',
    );
    Hive.init(hiveDirectory.path);
    GStorage.userInfo = await Hive.openBox<dynamic>('userInfo');
    GStorage.setting = await Hive.openBox<dynamic>('setting');
  });

  tearDownAll(() async {
    await Hive.close();
    if (await hiveDirectory.exists()) {
      await hiveDirectory.delete(recursive: true);
    }
  });

  setUp(() async {
    await GStorage.userInfo.clear();
    await GStorage.setting.clear();
  });

  test('uses typed WBI signature output for play-url requests', () async {
    late Map<String, dynamic> unsignedParameters;
    final harness = HttpTestHarness(
      (_) => jsonResponse(<String, Object?>{
        'code': 0,
        'data': <String, Object?>{
          'quality': 80,
          'accept_quality': <Object?>[],
          'support_formats': <Object?>[],
        },
      }),
    );
    final api = VideoApi(
      client: harness.runtime.client,
      signer: (parameters) async {
        unsignedParameters = parameters;
        return ApiSuccess<Map<String, dynamic>>(<String, dynamic>{
          ...parameters,
          'w_rid': 'signed-request',
          'wts': '1',
        });
      },
    );

    final result = await api.playUrl(bvid: 'BV1test', cid: 7, qn: 80);

    expect(result, isA<ApiSuccess<PlayUrlModel>>());
    expect((result as ApiSuccess<PlayUrlModel>).data.quality, 80);
    expect(unsignedParameters['bvid'], 'BV1test');
    expect(unsignedParameters['cid'], 7);
    expect(unsignedParameters['qn'], 80);
    expect(unsignedParameters['fourk'], 1);
    expect(unsignedParameters['voice_balance'], 1);
    expect(unsignedParameters['try_look'], 1);
    final request = harness.requests.single;
    expect(request.path, Api.videoUrl);
    expect(request.queryParameters['w_rid'], 'signed-request');
    expect(request.queryParameters['wts'], '1');
  });

  test(
    'propagates WBI signing failures without making an HTTP request',
    () async {
      final harness = HttpTestHarness(
        (_) =>
            throw StateError('HTTP must not be called after signing failure'),
      );
      final api = VideoApi(
        client: harness.runtime.client,
        signer: (_) async => const ApiFailure<Map<String, dynamic>>(
          kind: ApiFailureKind.decoding,
          message: '请求签名生成失败',
          endpoint: 'wbi.sign',
        ),
      );

      final result = await api.playUrl(avid: 1, cid: 2);

      expect(result, isA<ApiFailure<PlayUrlModel>>());
      final failure = result as ApiFailure<PlayUrlModel>;
      expect(failure.kind, ApiFailureKind.decoding);
      expect(failure.endpoint, 'wbi.sign');
      expect(harness.requests, isEmpty);
    },
  );
}
