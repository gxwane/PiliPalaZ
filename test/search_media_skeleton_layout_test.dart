import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pilipalaz/common/skeleton/media_bangumi.dart';
import 'package:pilipalaz/models/common/search_type.dart';
import 'package:pilipalaz/pages/search_panel/view.dart';

void main() {
  for (final SearchType searchType in <SearchType>[
    SearchType.media_bangumi,
    SearchType.media_ft,
  ]) {
    testWidgets(
      '${searchType.type} loading skeleton does not overflow at 360dp',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 360,
                child: CustomScrollView(
                  slivers: <Widget>[
                    SliverGrid(
                      gridDelegate: searchSkeletonGridDelegate(
                        searchType,
                        maxCrossAxisExtent: 480,
                      ),
                      delegate: SliverChildListDelegate(const <Widget>[
                        MediaBangumiSkeleton(),
                      ]),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 16));

        expect(tester.takeException(), isNull);
        expect(tester.getSize(find.byType(MediaBangumiSkeleton)).height, 160);
      },
    );
  }
}
