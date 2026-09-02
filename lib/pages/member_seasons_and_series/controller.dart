import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:pilipalaz/http/member.dart';
import 'package:pilipalaz/http/api_result.dart';
import 'package:pilipalaz/models/member/seasons.dart';

class MemberSeasonsAndSeriesController extends GetxController {
  MemberSeasonsAndSeriesController({required this.mid});
  final int mid;
  int pn = 1;
  int ps = 20;
  int total = 0;
  int currentTotal = 0;
  RxList<MemberSeasonsList> seasonsList = <MemberSeasonsList>[].obs;
  RxList<MemberSeriesList> seriesList = <MemberSeriesList>[].obs;
  late Map page;

  // @override
  // void onInit() {
  //   super.onInit();
  // }

  // 请求专栏
  Future<ApiResult<MemberSeasonsAndSeriesDataModel>> getMemberSeasonsAndSeries(
    String type,
  ) async {
    var res = await MemberHttp.getMemberSeasonsAndSeries(mid, pn, ps);
    if (res case ApiFailure<MemberSeasonsAndSeriesDataModel> failure) {
      SmartDialog.showToast("用户专栏请求异常：${failure.message}");
    } else if (res case ApiSuccess<MemberSeasonsAndSeriesDataModel>(
      :final data,
    )) {
      if (data.seasonsList?.isNotEmpty == true) {
        seasonsList.addAll(data.seasonsList!);
      }
      if (data.seriesList?.isNotEmpty == true) {
        seriesList.addAll(data.seriesList!);
      }
      if ((data.page?.total ?? 0) > 0) {
        total = data.page!.total!;
      }
      currentTotal = seasonsList.length + seriesList.length;
    }
    return res;
  }

  // 上拉加载
  Future onLoad() async {
    if (currentTotal >= total) return;
    pn += 1;
    return await getMemberSeasonsAndSeries('onLoad');
  }

  Future<ApiResult<MemberSeasonsAndSeriesDataModel>> onRefresh() async {
    pn = 1;
    seasonsList.clear();
    seriesList.clear();
    currentTotal = 0;
    return await getMemberSeasonsAndSeries('onRefresh');
  }
}
