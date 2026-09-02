import 'package:flutter_test/flutter_test.dart';
import 'package:pilipalaz/http/api_client.dart';
import 'package:pilipalaz/http/api_decoder.dart';

void main() {
  group('BiliApiDecoder', () {
    test('decodes a required data object', () {
      final value = BiliApiDecoder.data<String>(
        <String, dynamic>{
          'code': 0,
          'data': <String, dynamic>{'title': 'PiliPalaZ'},
        },
        decode: (value) =>
            BiliApiDecoder.object(value, field: 'data')['title'] as String,
      );

      expect(value, 'PiliPalaZ');
    });

    test('turns a non-zero API code into a typed rejection', () {
      expect(
        () => BiliApiDecoder.data<Object?>(<String, dynamic>{
          'code': -404,
          'message': '不存在',
        }, decode: (value) => value),
        throwsA(
          isA<ApiRejectedException>()
              .having((error) => error.code, 'code', -404)
              .having((error) => error.message, 'message', '不存在'),
        ),
      );
    });

    test('rejects a missing or malformed envelope field', () {
      expect(
        () => BiliApiDecoder.data<Object?>(<String, dynamic>{
          'code': 0,
        }, decode: (value) => value),
        throwsA(isA<MalformedApiResponseException>()),
      );
      expect(
        () => BiliApiDecoder.object(<Object?>[], field: 'data'),
        throwsA(isA<MalformedApiResponseException>()),
      );
    });
  });
}
