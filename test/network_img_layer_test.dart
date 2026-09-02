import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pilipalaz/common/widgets/network_img_layer.dart';

void main() {
  test('normalizes protocol-relative and insecure image URLs', () {
    expect(
      NetworkImgLayer.normalizeUrl('//i0.hdslb.com/a.jpg'),
      'https://i0.hdslb.com/a.jpg',
    );
    expect(
      NetworkImgLayer.normalizeUrl('http://i0.hdslb.com/a.jpg'),
      'https://i0.hdslb.com/a.jpg',
    );
  });

  testWidgets('uses a local placeholder for missing and failed images', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: NetworkImgLayer(src: '', width: 80, height: 45)),
    );
    expect(find.byType(CachedNetworkImage), findsNothing);
    expect(find.byType(Image), findsOneWidget);

    await tester.pumpWidget(
      const MaterialApp(
        home: NetworkImgLayer(
          src: 'https://i0.hdslb.com/a.jpg',
          width: 80,
          height: 45,
        ),
      ),
    );
    final networkImage = tester.widget<CachedNetworkImage>(
      find.byType(CachedNetworkImage),
    );
    expect(networkImage.errorWidget, isNotNull);
    expect(
      networkImage.errorWidget!(
        tester.element(find.byType(CachedNetworkImage)),
        networkImage.imageUrl,
        Exception('offline'),
      ),
      isA<Container>(),
    );
  });
}
