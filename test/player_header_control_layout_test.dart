import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pilipalaz/pages/video/widgets/player_header_action_row.dart';

Widget _button(String key) {
  return SizedBox(key: ValueKey(key), width: 42, height: 38);
}

void main() {
  testWidgets('player header fits the 340dp portrait title area', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 340,
              child: PlayerHeaderActionRow(
                backButton: _button('back'),
                homeButton: _button('home'),
                isEquivalentFullScreen: false,
                compactActions: [
                  _button('danmaku-input'),
                  _button('danmaku-switch'),
                  _button('pip'),
                ],
                moreButton: _button('more'),
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('more')), findsOneWidget);
    expect(find.byKey(const ValueKey('pip')), findsOneWidget);
  });
}
