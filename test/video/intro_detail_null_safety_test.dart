import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pilipalaz/http/api_result.dart';
import 'package:pilipalaz/models/video/ai.dart';
import 'package:pilipalaz/models/video_detail_res.dart';
import 'package:pilipalaz/pages/video/introduction/widgets/intro_detail.dart';

void main() {
  testWidgets('IntroDetail 在 descV2 为 null 时安全降级到 desc 文本渲染，不抛异常', (
    WidgetTester tester,
  ) async {
    final videoDetail = VideoDetailData(
      bvid: 'BVtest123',
      desc: '普通描述文本',
      descV2: null,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: IntroDetail(
            videoDetail: videoDetail,
            enableAi: false,
            aiConclusion: () async => ApiSuccess(
              AiConclusionModel(modelResult: ModelResult(summary: '')),
            ),
          ),
        ),
      ),
    );

    expect(find.textContaining('普通描述文本'), findsOneWidget);
  });
}
