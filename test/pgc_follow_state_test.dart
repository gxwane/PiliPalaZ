import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pilipalaz/models/bangumi/info.dart';
import 'package:pilipalaz/pages/video/introduction/bangumi/view.dart';

void main() {
  test('followedState preserves explicit known states', () {
    expect(BangumiInfoModel().followedState, isNull);
    expect(
      BangumiInfoModel(userStatus: UserStatus(follow: 1)).followedState,
      isTrue,
    );
    expect(
      BangumiInfoModel(userStatus: UserStatus(follow: 0)).followedState,
      isFalse,
    );
    expect(
      BangumiInfoModel(userStatus: UserStatus(follow: 2)).followedState,
      isNull,
    );
  });

  test('season detail follow fields stay unknown until authoritative sync', () {
    final BangumiInfoModel detail = BangumiInfoModel.fromJson(<String, dynamic>{
      'episodes': <dynamic>[],
      'user_status': <String, dynamic>{
        'follow': 0,
        'follow_status': 0,
        'progress': <String, dynamic>{'last_ep_id': 123},
      },
    });

    expect(detail.followedState, isNull);

    detail.applyFollowStatus(
      UserStatus.fromJson(<String, dynamic>{
        'follow': 1,
        'follow_status': 2,
        'login': 1,
      }),
    );
    expect(detail.followedState, isTrue);
    expect(detail.userStatus?.followStatus, 2);
    expect(detail.userStatus?.progress?.lastEpId, 123);

    detail.applyFollowStatus(UserStatus(follow: 0, followStatus: 0));
    expect(detail.followedState, isFalse);
  });

  test('setFollowed creates and updates the detail user status', () {
    final BangumiInfoModel detail = BangumiInfoModel();

    detail.setFollowed(true);
    expect(detail.userStatus?.follow, 1);
    expect(detail.followedState, isTrue);

    detail.setFollowed(false);
    expect(detail.userStatus?.follow, 0);
    expect(detail.followedState, isFalse);
  });

  testWidgets('unknown follow state shows a disabled progress indicator', (
    tester,
  ) async {
    int taps = 0;
    await tester.pumpWidget(
      _testApp(
        PgcFollowButton(
          followed: null,
          updating: false,
          actionLabel: '追剧',
          onPressed: () => taps += 1,
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.tap(find.byType(IconButton));
    expect(taps, 0);
  });

  testWidgets('known follow state exposes the matching action', (tester) async {
    int taps = 0;
    await tester.pumpWidget(
      _testApp(
        PgcFollowButton(
          followed: true,
          updating: false,
          actionLabel: '追剧',
          onPressed: () => taps += 1,
        ),
      ),
    );

    expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
    expect(find.byTooltip('取消追剧'), findsOneWidget);
    await tester.tap(find.byType(IconButton));
    expect(taps, 1);
  });
}

Widget _testApp(Widget child) => MaterialApp(
  theme: ThemeData(colorSchemeSeed: Colors.green, useMaterial3: true),
  home: Scaffold(body: Center(child: child)),
);
