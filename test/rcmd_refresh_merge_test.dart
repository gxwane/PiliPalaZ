import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:pilipalaz/models/home/rcmd/result.dart';
import 'package:pilipalaz/models/model_rec_video_item.dart';
import 'package:pilipalaz/models/rcmd_video_item.dart';
import 'package:pilipalaz/pages/rcmd/refresh_merge.dart';

void main() {
  group('mergeRcmdRefresh', () {
    test('preserves old videos and marks the latest refresh boundary', () {
      final result = mergeRcmdRefresh<int>(
        currentVideos: <int>[1, 2],
        refreshedVideos: <int>[3, 4],
        preserveCurrent: true,
      );

      expect(result.videos, <int>[3, 4, 1, 2]);
      expect(result.lastSeenIndex, 2);
    });

    test('repeated refresh replaces the previous boundary', () {
      final firstRefresh = mergeRcmdRefresh<int>(
        currentVideos: <int>[1, 2],
        refreshedVideos: <int>[3, 4],
        preserveCurrent: true,
      );
      final secondRefresh = mergeRcmdRefresh<int>(
        currentVideos: firstRefresh.videos,
        refreshedVideos: <int>[5],
        preserveCurrent: true,
      );

      expect(secondRefresh.videos, <int>[5, 3, 4, 1, 2]);
      expect(secondRefresh.lastSeenIndex, 1);
    });

    test('empty refresh keeps old videos and hides the boundary', () {
      final result = mergeRcmdRefresh<int>(
        currentVideos: <int>[1, 2],
        refreshedVideos: const <int>[],
        preserveCurrent: true,
      );

      expect(result.videos, <int>[1, 2]);
      expect(result.lastSeenIndex, isNull);
    });

    test('first refresh has no boundary when there are no old videos', () {
      final result = mergeRcmdRefresh<int>(
        currentVideos: const <int>[],
        refreshedVideos: <int>[1, 2],
        preserveCurrent: true,
      );

      expect(result.videos, <int>[1, 2]);
      expect(result.lastSeenIndex, isNull);
    });

    test(
      'disabled preservation replaces old videos and clears the boundary',
      () {
        final result = mergeRcmdRefresh<int>(
          currentVideos: <int>[1, 2],
          refreshedVideos: <int>[3, 4],
          preserveCurrent: false,
        );

        expect(result.videos, <int>[3, 4]);
        expect(result.lastSeenIndex, isNull);
      },
    );
  });

  group('shared recommendation video type', () {
    test('web refresh results remain assignable to the shared RxList', () {
      final oldVideo = RecVideoItemModel(id: 1);
      final newVideo = RecVideoItemModel(id: 2);
      final videoList = <RcmdVideoItem>[oldVideo].obs;
      final refreshedVideos = List<RcmdVideoItem>.from(<RecVideoItemModel>[
        newVideo,
      ]);
      final result = mergeRcmdRefresh<RcmdVideoItem>(
        currentVideos: videoList,
        refreshedVideos: refreshedVideos,
        preserveCurrent: true,
      );

      expect(() => videoList.assignAll(result.videos), returnsNormally);
      expect(videoList, <RcmdVideoItem>[newVideo, oldVideo]);
    });

    test(
      'app refresh and load results remain assignable to the shared RxList',
      () {
        final oldVideo = RecVideoItemAppModel(id: 1);
        final newVideo = RecVideoItemAppModel(id: 2);
        final loadedVideo = RecVideoItemAppModel(id: 3);
        final videoList = <RcmdVideoItem>[oldVideo].obs;
        final refreshedVideos = List<RcmdVideoItem>.from(<RecVideoItemAppModel>[
          newVideo,
        ]);
        final result = mergeRcmdRefresh<RcmdVideoItem>(
          currentVideos: videoList,
          refreshedVideos: refreshedVideos,
          preserveCurrent: true,
        );

        expect(() => videoList.assignAll(result.videos), returnsNormally);
        expect(
          () => videoList.addAll(<RcmdVideoItem>[loadedVideo]),
          returnsNormally,
        );
        expect(videoList, <RcmdVideoItem>[newVideo, oldVideo, loadedVideo]);
      },
    );
  });
}
