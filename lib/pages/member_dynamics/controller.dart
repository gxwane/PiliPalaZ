import 'package:get/get.dart';
import 'package:pilipalaz/http/member.dart';
import 'package:pilipalaz/http/api_result.dart';
import 'package:pilipalaz/models/dynamics/result.dart';

class MemberDynamicsController extends GetxController {
  MemberDynamicsController({required this.mid});
  final int mid;
  String offset = '';
  int count = 0;
  bool hasMore = true;
  RxList<DynamicItemModel> dynamicsList = <DynamicItemModel>[].obs;

  Future<ApiResult<DynamicsDataModel>?> getMemberDynamic(type) async {
    if (type == 'onRefresh') {
      offset = '';
      dynamicsList.clear();
    }
    if (offset == '-1') {
      return null;
    }
    var res = await MemberHttp.memberDynamic(offset: offset, mid: mid);
    if (res case ApiSuccess<DynamicsDataModel>(:final data)) {
      dynamicsList.addAll(data.items ?? <DynamicItemModel>[]);
      offset = data.offset?.isNotEmpty == true ? data.offset! : '-1';
      hasMore = data.hasMore ?? false;
    }
    return res;
  }

  // 上拉加载
  Future onLoad() async {
    await getMemberDynamic('onLoad');
  }

  Future onRefresh() async {
    await getMemberDynamic('onRefresh');
  }
}
