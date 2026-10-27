import 'package:flutter_test/flutter_test.dart';
import 'package:pilipalaz/models/member/info.dart';

void main() {
  group('MemberInfoModel Card.level deserialization tests', () {
    test('parses modern /x/v2/space payload with current_level correctly', () {
      final json = {
        'card': {
          'mid': '1001',
          'name': 'B站大佬',
          'level_info': {
            'current_level': 6,
            'current_min': 28800,
            'current_exp': 45000,
            'next_exp': 0,
          },
        },
      };

      final info = MemberInfoModel.fromJson(json);
      expect(info.card?.level, 6);
    });

    test('parses level 0 account correctly as 0', () {
      final json = {
        'card': {
          'mid': '1002',
          'name': '新手号',
          'level_info': {
            'current_level': 0,
            'current_min': 0,
            'current_exp': 0,
            'next_exp': 100,
          },
        },
      };

      final info = MemberInfoModel.fromJson(json);
      expect(info.card?.level, 0);
    });

    test('falls back to level_info.level when current_level is missing', () {
      final json = {
        'card': {
          'mid': '1003',
          'name': '兼容号1',
          'level_info': {'level': 5},
        },
      };

      final info = MemberInfoModel.fromJson(json);
      expect(info.card?.level, 5);
    });

    test('falls back to top-level level when level_info is missing', () {
      final json = {
        'card': {'mid': '1004', 'name': '兼容号2', 'level': 4},
      };

      final info = MemberInfoModel.fromJson(json);
      expect(info.card?.level, 4);
    });

    test('parses string representations and floating numbers safely', () {
      final jsonString = {
        'card': {
          'mid': '1005',
          'level_info': {'current_level': '3'},
        },
      };
      expect(MemberInfoModel.fromJson(jsonString).card?.level, 3);

      final jsonDouble = {
        'card': {
          'mid': '1006',
          'level_info': {'current_level': 2.0},
        },
      };
      expect(MemberInfoModel.fromJson(jsonDouble).card?.level, 2);
    });

    test(
      'handles scalar or malformed level_info without NoSuchMethodError',
      () {
        final jsonScalar = {
          'card': {'mid': '1007', 'level_info': 5},
        };
        expect(MemberInfoModel.fromJson(jsonScalar).card?.level, 5);

        final jsonBool = {
          'card': {'mid': '1008', 'level_info': true},
        };
        expect(MemberInfoModel.fromJson(jsonBool).card?.level, isNull);

        final jsonInvalidString = {
          'card': {
            'mid': '1009',
            'level_info': {'current_level': 'invalid'},
          },
        };
        expect(MemberInfoModel.fromJson(jsonInvalidString).card?.level, isNull);
      },
    );

    test('normalizes negative level to null and preserves domain truth', () {
      final jsonNegative = {
        'card': {
          'mid': '1010',
          'level_info': {'current_level': -1},
        },
      };
      expect(MemberInfoModel.fromJson(jsonNegative).card?.level, isNull);

      final jsonHighLevel = {
        'card': {
          'mid': '1011',
          'level_info': {'current_level': 7},
        },
      };
      // Domain model records factual 7; view layer handles asset display bounds
      expect(MemberInfoModel.fromJson(jsonHighLevel).card?.level, 7);
    });

    test('returns null when level_info is completely absent', () {
      final jsonAbsent = {
        'card': {'mid': '1012', 'name': '无等级用户'},
      };
      expect(MemberInfoModel.fromJson(jsonAbsent).card?.level, isNull);
    });
  });
}
