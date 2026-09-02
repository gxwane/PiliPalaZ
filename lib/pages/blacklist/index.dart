import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:pilipalaz/common/widgets/http_error.dart';
import 'package:pilipalaz/common/widgets/network_img_layer.dart';
import 'package:pilipalaz/http/black.dart';
import 'package:pilipalaz/http/api_result.dart';
import 'package:pilipalaz/models/user/black.dart';
import 'package:pilipalaz/utils/storage.dart';
import 'package:pilipalaz/utils/utils.dart';

class BlackListPage extends StatefulWidget {
  const BlackListPage({super.key});

  @override
  State<BlackListPage> createState() => _BlackListPageState();
}

class _BlackListPageState extends State<BlackListPage> {
  final BlackListController _blackListController =
      Get.put(BlackListController());
  final ScrollController scrollController = ScrollController();
  Future<ApiResult<BlackListDataModel>>? _futureBuilderFuture;
  bool _isLoadingMore = false;
  Box onlineCache = GStorage.onlineCache;

  @override
  void initState() {
    super.initState();
    _futureBuilderFuture = _blackListController.queryBlacklist();
    scrollController.addListener(
      () async {
        if (scrollController.position.pixels >=
            scrollController.position.maxScrollExtent - 200) {
          if (!_isLoadingMore) {
            _isLoadingMore = true;
            await _blackListController.queryBlacklist(type: 'onLoad');
            _isLoadingMore = false;
          }
        }
      },
    );
  }

  @override
  void dispose() {
    List<int> blackMidsList =
        _blackListController.blackList.map<int>((e) => e.mid!).toList();
    onlineCache.put(OnlineCacheKey.blackMidsList, blackMidsList);
    scrollController.removeListener(() {});
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 0,
        centerTitle: false,
        title: Obx(
          () => Text(
            '黑名单管理 - ${_blackListController.total.value}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
      ),
      body: RefreshIndicator(
        displacement: 10.0,
        edgeOffset: 10.0,
        onRefresh: () async => await _blackListController.queryBlacklist(),
      child: FutureBuilder<ApiResult<BlackListDataModel>>(
          future: _futureBuilderFuture,
          builder: (BuildContext context, AsyncSnapshot snapshot) {
            if (snapshot.connectionState == ConnectionState.done) {
              final result = snapshot.data;
              if (result is ApiSuccess<BlackListDataModel>) {
                List<BlackListItem> list = _blackListController.blackList;
                return Obx(
                  () => list.length == 1
                      ? const SizedBox()
                      : ListView.builder(
                          controller: scrollController,
                          itemCount: list.length,
                          itemBuilder: (BuildContext context, int index) {
                            return ListTile(
                              onTap: () {},
                              leading: NetworkImgLayer(
                                width: 45,
                                height: 45,
                                type: 'avatar',
                                src: list[index].face,
                              ),
                              title: Text(
                                list[index].uname!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 14),
                              ),
                              subtitle: Text(
                                Utils.dateFormat(list[index].mtime),
                                maxLines: 1,
                                style: TextStyle(
                                    color:
                                        Theme.of(context).colorScheme.outline),
                                overflow: TextOverflow.ellipsis,
                              ),
                              dense: true,
                              trailing: TextButton(
                                onPressed: () => _blackListController
                                    .removeBlack(list[index].mid),
                                child: const Text('移除'),
                              ),
                            );
                          },
                        ),
                );
              } else {
                return CustomScrollView(
                  slivers: [
                    HttpError(
                    errMsg:
                        (result as ApiFailure<BlackListDataModel>?)?.message ??
                        '黑名单加载失败',
                      fn: () => _blackListController.queryBlacklist(),
                    )
                  ],
                );
              }
            } else {
              // 骨架屏
              return const SizedBox();
            }
          },
        ),
      ),
    );
  }
}

class BlackListController extends GetxController {
  int currentPage = 1;
  int pageSize = 50;
  RxInt total = 0.obs;
  RxList<BlackListItem> blackList = <BlackListItem>[].obs;

  Future<ApiResult<BlackListDataModel>> queryBlacklist({type = 'init'}) async {
    if (type == 'init') {
      currentPage = 1;
    }
    var result = await BlackHttp.blackList(pn: currentPage, ps: pageSize);
    if (result case ApiSuccess<BlackListDataModel>(:final data)) {
      final list = data.list ?? <BlackListItem>[];
      if (type == 'init') {
        blackList.value = list;
        total.value = data.total ?? 0;
      } else {
        blackList.addAll(list);
      }

      currentPage += 1;
    }
    return result;
  }

  Future<ApiResult<void>> removeBlack(mid) async {
    var result = await BlackHttp.removeBlack(fid: mid);
    if (result is ApiSuccess<void>) {
      blackList.removeWhere((e) => e.mid == mid);
      total.value = total.value - 1;
      SmartDialog.showToast('操作成功');
    } else {
      SmartDialog.showToast((result as ApiFailure<void>).message);
    }
    return result;
  }
}
