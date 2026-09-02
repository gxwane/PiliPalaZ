import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pilipalaz/common/widgets/http_error.dart';
import 'package:pilipalaz/http/api_result.dart';
import 'package:pilipalaz/models/user/fav_folder.dart';
import 'package:pilipalaz/utils/feed_back.dart';

class FavPanel extends StatefulWidget {
  const FavPanel({super.key, this.ctr});
  final dynamic ctr;

  @override
  State<FavPanel> createState() => _FavPanelState();
}

class _FavPanelState extends State<FavPanel> {
  late Future<ApiResult<FavFolderData>> _futureBuilderFuture;

  @override
  void initState() {
    super.initState();
    _futureBuilderFuture = widget.ctr!.queryVideoInFolder();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 500,
      color: Theme.of(context).colorScheme.background,
      child: Column(
        children: [
          AppBar(
            centerTitle: false,
            elevation: 0,
            leading: IconButton(
              tooltip: '关闭',
              onPressed: () => Get.back(),
              icon: const Icon(Icons.close_outlined),
            ),
            title: Text(
              '添加到收藏夹',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          Expanded(
            child: Material(
              child: FutureBuilder<ApiResult<FavFolderData>>(
                future: _futureBuilderFuture,
                builder:
                    (
                      BuildContext context,
                      AsyncSnapshot<ApiResult<FavFolderData>> snapshot,
                    ) {
                      if (snapshot.connectionState == ConnectionState.done) {
                        final result = snapshot.data;
                        if (result is ApiSuccess<FavFolderData>) {
                          return Obx(
                            () => ListView.builder(
                              itemCount:
                                  widget.ctr!.favFolderData.value.list!.length,
                              itemBuilder: (context, index) {
                                return ListTile(
                                  onTap: () => widget.ctr!.onChoose(
                                    widget
                                            .ctr!
                                            .favFolderData
                                            .value
                                            .list![index]
                                            .favState !=
                                        1,
                                    index,
                                  ),
                                  dense: true,
                                  leading: const Icon(Icons.folder_outlined),
                                  minLeadingWidth: 0,
                                  title: Text(
                                    widget
                                        .ctr!
                                        .favFolderData
                                        .value
                                        .list![index]
                                        .title!,
                                  ),
                                  subtitle: Text(
                                    '${widget.ctr!.favFolderData.value.list![index].mediaCount}个内容',
                                  ),
                                  trailing: Transform.scale(
                                    scale: 0.9,
                                    child: Checkbox(
                                      value:
                                          widget
                                              .ctr!
                                              .favFolderData
                                              .value
                                              .list![index]
                                              .favState ==
                                          1,
                                      onChanged: (bool? checkValue) => widget
                                          .ctr!
                                          .onChoose(checkValue!, index),
                                    ),
                                  ),
                                );
                              },
                            ),
                          );
                        } else if (result is ApiFailure<FavFolderData>) {
                          return HttpError(
                            errMsg: result.message,
                            fn: () {
                              setState(() {
                                _futureBuilderFuture = widget.ctr!
                                    .queryVideoInFolder();
                              });
                            },
                          );
                        }
                        return const Text('请求异常');
                      } else {
                        // 骨架屏
                        return const Text('请求中');
                      }
                    },
              ),
            ),
          ),
          Divider(
            height: 1,
            color: Theme.of(context).disabledColor.withOpacity(0.08),
          ),
          Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 12,
              bottom: MediaQuery.of(context).padding.bottom + 12,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                TextButton(
                  onPressed: () => Get.back(),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.only(left: 30, right: 30),
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.onInverseSurface, // 设置按钮背景色
                  ),
                  child: const Text('取消'),
                ),
                const SizedBox(width: 10),
                TextButton(
                  onPressed: () async {
                    feedBack();
                    await widget.ctr!.actionFavVideo();
                  },
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.only(left: 30, right: 30),
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.primary, // 设置按钮背景色
                  ),
                  child: const Text('完成'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
