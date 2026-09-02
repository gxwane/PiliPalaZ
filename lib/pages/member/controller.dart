import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:pilipalaz/http/member.dart';
import 'package:pilipalaz/http/api_result.dart';
import 'package:pilipalaz/http/video.dart';
import 'package:pilipalaz/models/member/archive.dart';
import 'package:pilipalaz/models/member/coin.dart';
import 'package:pilipalaz/models/member/info.dart';
import 'package:pilipalaz/utils/storage.dart';
import 'package:share_plus/share_plus.dart';

import 'package:pilipalaz/pages/video/introduction/widgets/group_panel.dart';

import '../../common/widgets/my_dialog.dart';

class MemberController extends GetxController with GetTickerProviderStateMixin {
  int? mid;
  MemberController({this.mid});
  Rx<MemberInfoModel> memberInfo = MemberInfoModel().obs;
  late Map userStat;
  RxString face = ''.obs;
  String? heroTag;
  Box userInfoCache = GStorage.userInfo;
  late int ownerMid;
  bool specialFollowed = false;
  // 投稿列表
  RxList<VListItemModel>? archiveList = <VListItemModel>[].obs;
  dynamic userInfo;
  RxInt attribute = (-1).obs;
  RxString attributeText = '关注'.obs;
  RxList<MemberCoinsDataModel> recentCoinsList = <MemberCoinsDataModel>[].obs;
  // String? wwebid;
  late TabController tabController;

  @override
  void onInit() async {
    super.onInit();
    mid = mid ?? int.parse(Get.parameters['mid']!);
    userInfo = userInfoCache.get('userInfoCache');
    ownerMid = userInfo?.mid ?? -1;
    face.value = Get.arguments?['face'] ?? '';
    heroTag = Get.arguments?['heroTag'] ?? '';
    tabController = TabController(length: 3, vsync: this);
  }

  // 获取用户信息
  Future<ApiResult<MemberInfoModel>> getInfo() async {
    // await getMemberStat();
    // await getMemberView();
    // await getWwebid();
    var res = await MemberHttp.memberInfo(mid: mid);
    if (res case ApiSuccess<MemberInfoModel>(:final data)) {
      memberInfo.value = data;
      relationSearch();
      face.value = data.card?.face ?? '';
    } else {
      SmartDialog.showToast((res as ApiFailure<MemberInfoModel>).message);
    }
    return res;
  }

  // Future getWwebid() async {
  //   try {
  //     dynamic response =
  //     dom.Document document = html_parser.parse(response.data);
  //     dom.Element? scriptElement =
  //         document.querySelector('script#__RENDER_DATA__');
  //     wwebid = jsonDecode(
  //         Uri.decodeComponent(scriptElement?.text ?? ''))['access_id'];
  //   } catch (e) {
  //     print('failed to get wwebid: $e');
  //   }
  // }

  // 获取用户状态
  // Future<Map<String, dynamic>> getMemberStat() async {
  //   var res = await MemberHttp.memberStat(mid: mid);
  //   if (res['status']) {
  //     userStat = res['data'];
  //   }
  //   return res;
  // }

  // 获取用户播放数 获赞数
  // Future<Map<String, dynamic>> getMemberView() async {
  //   var res = await MemberHttp.memberView(mid: mid!);
  //   if (res['status']) {
  //     userStat.addAll(res['data']);
  //   }
  //   return res;
  // }

  Future delayedUpdateRelation() async {
    await Future.delayed(const Duration(milliseconds: 1000), () async {
      SmartDialog.showToast('更新状态');
      // await relationSearch();
      await getInfo();
      // memberInfo.update((val) {});
    });
  }

  // 关注/取关up
  Future actionRelationMod(BuildContext context) async {
    if (userInfo == null) {
      SmartDialog.showToast('账号未登录');
      return;
    }
    // if (memberInfo.value == null) {
    //   SmartDialog.showToast('尚未获取到用户信息');
    //   return;
    // }
    if (attribute.value == 128) {
      blockUser(context);
      return;
    }
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('操作'),
          actions: [
            if (memberInfo.value.card!.isFollow!) ...[
              TextButton(
                onPressed: () async {
                  final res = await MemberHttp.addUsers(
                    mid,
                    specialFollowed ? '0' : '-10',
                  );
                  SmartDialog.showToast(
                    res is ApiSuccess<void>
                        ? '操作成功'
                        : (res as ApiFailure<void>).message,
                  );
                  if (res is ApiSuccess<void>) {
                    specialFollowed = !specialFollowed;
                  }
                  Get.back();
                  await delayedUpdateRelation();
                },
                child: Text(specialFollowed ? '移除特别关注' : '加入特别关注'),
              ),
              TextButton(
                onPressed: () async {
                  Get.back();
                  await MyDialog.show(context, GroupPanel(mid: mid));
                  await delayedUpdateRelation();
                },
                child: const Text('设置分组'),
              ),
            ],
            TextButton(
              onPressed: () async {
                var res = await VideoHttp.relationMod(
                  mid: mid!,
                  act: memberInfo.value.card!.isFollow! ? 2 : 1,
                  reSrc: 11,
                );
                SmartDialog.showToast(
                  res is ApiSuccess<void>
                      ? '操作成功'
                      : (res as ApiFailure<void>).message,
                );
                if (res is ApiSuccess<void>) {
                  memberInfo.value.card!.isFollow =
                      !memberInfo.value.card!.isFollow!;
                }
                Get.back();
                await delayedUpdateRelation();
              },
              child: Text(memberInfo.value.card!.isFollow! ? '取消关注' : '关注'),
            ),
            TextButton(
              onPressed: () => Get.back(),
              child: Text(
                '取消',
                style: TextStyle(color: Theme.of(context).colorScheme.outline),
              ),
            ),
          ],
        );
      },
    );
  }

  // 关系查询
  Future relationSearch() async {
    attribute.value = memberInfo.value.card!.relationStatus!;
    switch (attribute.value) {
      case 2:
        attributeText.value = '已关注';
        break;
      case 3:
        attributeText.value = '被关注';
        break;
      case 4:
        attributeText.value = '已互粉';
        break;
      case 5:
        attributeText.value = '已特关';
        break;
      case 128:
        attributeText.value = '已拉黑';
        break;
      case -999:
      default:
        attributeText.value = '关注';
    }
  }

  // 拉黑用户
  Future blockUser(BuildContext context) async {
    if (userInfo == null) {
      SmartDialog.showToast('账号未登录');
      return;
    }
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('提示'),
          content: Text(attribute.value != 128 ? '确定拉黑UP主?' : '从黑名单移除UP主'),
          actions: [
            TextButton(
              onPressed: () => Get.back(),
              child: Text(
                '点错了',
                style: TextStyle(color: Theme.of(context).colorScheme.outline),
              ),
            ),
            TextButton(
              onPressed: () async {
                Get.back();
                var res = await VideoHttp.relationMod(
                  mid: mid!,
                  act: attribute.value != 128 ? 5 : 6,
                  reSrc: 11,
                );
                if (res is ApiSuccess<void>) {
                  attribute.value = attribute.value != 128 ? 128 : 0;
                  attributeText.value = attribute.value == 128 ? '已拉黑' : '关注';
                  memberInfo.value.card!.isFollow = false;
                  relationSearch();
                  memberInfo.update((val) {});
                }
              },
              child: const Text('确认'),
            ),
          ],
        );
      },
    );
  }

  Future<void> shareUser() async {
    await SharePlus.instance.share(
      ShareParams(
        text:
            '${memberInfo.value.card!.name} - https://space.bilibili.com/$mid',
      ),
    );
  }

  // 请求投币视频
  Future<ApiResult<List<MemberCoinsDataModel>>?> getRecentCoinVideo() async {
    if (userInfo == null) return null;
    var res = await MemberHttp.getRecentCoinVideo(mid: mid!);
    if (res case ApiSuccess<List<MemberCoinsDataModel>>(:final data)) {
      recentCoinsList.value = data;
    } else {
      SmartDialog.showToast(
        (res as ApiFailure<List<MemberCoinsDataModel>>).message,
      );
    }
    return res;
  }

  // // 跳转查看动态
  // void pushDynamicsPage() => Get.toNamed('/memberDynamics?mid=$mid');
  //
  // // 跳转查看投稿
  // void pushArchivesPage() => Get.toNamed('/memberArchive?mid=$mid');
  //
  // // 跳转查看专栏
  // void pushSeasonsPage() {}
  // // 跳转查看最近投币
  // void pushRecentCoinsPage() async {
  //   if (recentCoinsList.isNotEmpty) {}
  // }
}
