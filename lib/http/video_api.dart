import '../models/video/play/url.dart';
import '../models/video_detail_res.dart';
import '../pages/mine/controller.dart';
import '../utils/storage.dart';
import '../utils/wbi_sign.dart';
import 'api.dart';
import 'api_client.dart';
import 'api_decoder.dart';
import 'api_result.dart';
import 'http_runtime.dart';

typedef WbiSigner =
    Future<ApiResult<Map<String, dynamic>>> Function(
      Map<String, dynamic> parameters,
    );

final class VideoApi {
  VideoApi({ApiClient? client, WbiSigner? signer})
    : _client = client ?? HttpRuntime.instance.client,
      _signer = signer ?? WbiSign().sign;

  static VideoApi? _instance;

  static VideoApi get instance => _instance ??= VideoApi();

  final ApiClient _client;
  final WbiSigner _signer;

  Future<ApiResult<PlayUrlModel>> playUrl({
    int? avid,
    String? bvid,
    required int cid,
    int? qn,
  }) async {
    final data = <String, dynamic>{
      'cid': cid,
      'qn': qn ?? 80,
      'fnval': 4048,
      if (avid != null) 'avid': avid,
      if (bvid != null) 'bvid': bvid,
    };
    if ((GStorage.userInfo.get('userInfoCache') == null ||
            MineController.anonymity) &&
        GStorage.setting.get(SettingBoxKey.p1080, defaultValue: true)) {
      data['try_look'] = 1;
    }

    final signed = await _signer(<String, dynamic>{
      ...data,
      'fourk': 1,
      'voice_balance': 1,
      'gaia_source': 'pre-load',
      'web_location': 1550101,
    });
    if (signed case ApiFailure<Map<String, dynamic>> failure) {
      return failure.cast<PlayUrlModel>();
    }
    final parameters = (signed as ApiSuccess<Map<String, dynamic>>).data;

    return _client.getJson<PlayUrlModel>(
      Api.videoUrl,
      endpoint: 'video.playUrl',
      queryParameters: parameters,
      decode: (json) => BiliApiDecoder.data<PlayUrlModel>(
        json,
        decode: (value) =>
            PlayUrlModel.fromJson(BiliApiDecoder.object(value, field: 'data')),
      ),
    );
  }

  Future<ApiResult<VideoDetailData>> detail({required String bvid}) {
    return _client.getJson<VideoDetailData>(
      Api.videoIntro,
      endpoint: 'video.detail',
      queryParameters: <String, dynamic>{'bvid': bvid},
      decode: (json) => BiliApiDecoder.data<VideoDetailData>(
        json,
        decode: (value) => VideoDetailData.fromJson(
          BiliApiDecoder.object(value, field: 'data'),
        ),
      ),
    );
  }
}
