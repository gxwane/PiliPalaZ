import 'package:flutter/material.dart';

import 'nine_grid_gallery.dart';

/// 动态图片/画册渲染组件，统一接入 NineGridGallery 沉浸式九宫格
Widget picWidget(dynamic item, BuildContext context) {
  final dynamic major = item.modules?.moduleDynamic?.major;
  if (major == null) return const SizedBox.shrink();
  final String type = major.type ?? '';
  List<dynamic> pictures = [];
  if (type == 'MAJOR_TYPE_OPUS') {
    /// fix 图片跟rich_node_panel重复
    return const SizedBox.shrink();
  }
  if (type == 'MAJOR_TYPE_DRAW') {
    pictures = major.draw?.items ?? [];
  }
  if (type == 'MAJOR_TYPE_ARTICLE') {
    pictures = major.article?.covers ?? [];
  }
  if (pictures.isEmpty) return const SizedBox.shrink();

  final String dynamicId =
      (item.idStr ?? item.basic?.commentIdStr ?? '').toString();

  return NineGridGallery(
    items: pictures,
    sourceScope: 'pic_panel',
    dynamicId: dynamicId,
  );
}
