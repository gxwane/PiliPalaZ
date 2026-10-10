import 'dart:math';

import 'package:flutter/material.dart';
import 'package:pilipalaz/common/constants.dart';
import 'package:pilipalaz/common/widgets/badge.dart';
import 'package:pilipalaz/common/widgets/network_img_layer.dart';
import 'package:pilipalaz/models/dynamics/result.dart';
import 'package:pilipalaz/pages/preview/view.dart';

/// 统一的相册媒体元数据抽象
class GalleryMediaItem {
  final String url;
  final double? width;
  final double? height;

  const GalleryMediaItem({
    required this.url,
    this.width,
    this.height,
  });

  /// 从多源数据结构防御性解析
  factory GalleryMediaItem.from(dynamic raw) {
    if (raw is GalleryMediaItem) {
      return raw;
    }
    if (raw is String) {
      return GalleryMediaItem(url: raw);
    }
    if (raw is OpusPicsModel) {
      final String resolvedUrl =
          (raw.url != null && raw.url!.isNotEmpty) ? raw.url! : (raw.src ?? '');
      return GalleryMediaItem(
        url: resolvedUrl,
        width: raw.width?.toDouble(),
        height: raw.height?.toDouble(),
      );
    }
    if (raw is DynamicDrawItemModel) {
      return GalleryMediaItem(
        url: raw.src ?? '',
        width: raw.width?.toDouble(),
        height: raw.height?.toDouble(),
      );
    }
    try {
      final String resolvedUrl =
          (raw.url ?? raw.src ?? raw.toString()).toString();
      final double? parsedWidth =
          raw.width != null ? (raw.width as num).toDouble() : null;
      final double? parsedHeight =
          raw.height != null ? (raw.height as num).toDouble() : null;
      return GalleryMediaItem(
        url: resolvedUrl,
        width: parsedWidth,
        height: parsedHeight,
      );
    } on Exception catch (_) {
      return GalleryMediaItem(url: raw.toString());
    }
  }

  /// 宽高比 (width / height)
  double? get aspectRatio {
    if (width != null && height != null && width! > 0 && height! > 0) {
      return width! / height!;
    }
    return null;
  }

  /// 是否为长图（高宽比大于 2.0，即宽高比小于 0.5）
  bool get isLongImage {
    final double? ratio = aspectRatio;
    return ratio != null && ratio < 0.5;
  }
}

/// 九宫格几何计算输出结果
class NineGridLayoutResult {
  final int crossAxisCount;
  final double width;
  final double height;
  final double itemWidth;
  final double itemHeight;
  final double childAspectRatio;
  final bool isSingleLongImage;
  final bool isSingleWideImage;

  const NineGridLayoutResult({
    required this.crossAxisCount,
    required this.width,
    required this.height,
    required this.itemWidth,
    required this.itemHeight,
    required this.childAspectRatio,
    this.isSingleLongImage = false,
    this.isSingleWideImage = false,
  });
}

/// 九宫格纯数学几何排版计算引擎
class NineGridGalleryLayout {
  static const double defaultSpacing = 4.0;
  static const double longImageRatioThreshold = 0.5; // height >= 2 * width
  static const double wideImageRatioThreshold = 2.0; // width >= 2 * height

  /// 根据图片数量与容器最大宽度计算网格参数
  static NineGridLayoutResult compute({
    required int itemCount,
    required double containerWidth,
    double spacing = defaultSpacing,
    double? singleImageAspectRatio,
  }) {
    if (itemCount <= 0 || containerWidth <= 0) {
      return const NineGridLayoutResult(
        crossAxisCount: 1,
        width: 0,
        height: 0,
        itemWidth: 0,
        itemHeight: 0,
        childAspectRatio: 1.0,
      );
    }

    if (itemCount == 1) {
      final double? ratio = singleImageAspectRatio;
      if (ratio != null) {
        if (ratio < longImageRatioThreshold) {
          // 长图：宽度钳制在容器 65%（上限 240），高度钳制在 180~360
          final double targetWidth =
              min(containerWidth * 0.65, 240.0).clamp(140.0, containerWidth);
          final double targetHeight =
              (targetWidth / ratio).clamp(180.0, 360.0);
          return NineGridLayoutResult(
            crossAxisCount: 1,
            width: targetWidth,
            height: targetHeight,
            itemWidth: targetWidth,
            itemHeight: targetHeight,
            childAspectRatio: targetWidth / targetHeight,
            isSingleLongImage: true,
          );
        } else if (ratio > wideImageRatioThreshold) {
          // 超宽横图：宽度拉满至容器宽度（上限 360），高度钳制在 100~200
          final double targetWidth = min(containerWidth, 360.0);
          final double targetHeight =
              (targetWidth / ratio).clamp(100.0, 200.0);
          return NineGridLayoutResult(
            crossAxisCount: 1,
            width: targetWidth,
            height: targetHeight,
            itemWidth: targetWidth,
            itemHeight: targetHeight,
            childAspectRatio: targetWidth / targetHeight,
            isSingleWideImage: true,
          );
        } else {
          // 常规比例单图
          if (ratio < 1.0) {
            final double targetWidth =
                min(containerWidth * 0.7, 260.0).clamp(140.0, containerWidth);
            final double targetHeight =
                (targetWidth / ratio).clamp(140.0, 320.0);
            return NineGridLayoutResult(
              crossAxisCount: 1,
              width: targetWidth,
              height: targetHeight,
              itemWidth: targetWidth,
              itemHeight: targetHeight,
              childAspectRatio: targetWidth / targetHeight,
            );
          } else {
            final double targetWidth =
                min(containerWidth * 0.85, 340.0).clamp(160.0, containerWidth);
            final double targetHeight =
                (targetWidth / ratio).clamp(120.0, 280.0);
            return NineGridLayoutResult(
              crossAxisCount: 1,
              width: targetWidth,
              height: targetHeight,
              itemWidth: targetWidth,
              itemHeight: targetHeight,
              childAspectRatio: targetWidth / targetHeight,
            );
          }
        }
      }

      // 未知比例兜底为 4:3 优雅卡片
      final double targetWidth =
          min(containerWidth * 0.7, 240.0).clamp(140.0, containerWidth);
      final double targetHeight = targetWidth * 0.75;
      return NineGridLayoutResult(
        crossAxisCount: 1,
        width: targetWidth,
        height: targetHeight,
        itemWidth: targetWidth,
        itemHeight: targetHeight,
        childAspectRatio: targetWidth / targetHeight,
      );
    }

    if (itemCount == 2) {
      final double itemWidth = (containerWidth - spacing) / 2;
      return NineGridLayoutResult(
        crossAxisCount: 2,
        width: containerWidth,
        height: itemWidth,
        itemWidth: itemWidth,
        itemHeight: itemWidth,
        childAspectRatio: 1.0,
      );
    }

    if (itemCount == 3) {
      final double itemWidth = (containerWidth - 2 * spacing) / 3;
      return NineGridLayoutResult(
        crossAxisCount: 3,
        width: containerWidth,
        height: itemWidth,
        itemWidth: itemWidth,
        itemHeight: itemWidth,
        childAspectRatio: 1.0,
      );
    }

    if (itemCount == 4) {
      // 4 图严格使用 2x2 对称宫格
      if (containerWidth >= 280.0) {
        // 与 3 宫格列宽严格对齐，形成居左对称小方块群，视觉极佳
        final double colWidth = (containerWidth - 2 * spacing) / 3;
        final double totalWidth = colWidth * 2 + spacing;
        final double totalHeight = colWidth * 2 + spacing;
        return NineGridLayoutResult(
          crossAxisCount: 2,
          width: totalWidth,
          height: totalHeight,
          itemWidth: colWidth,
          itemHeight: colWidth,
          childAspectRatio: 1.0,
        );
      } else {
        // 窄屏下等分铺满
        final double itemWidth = (containerWidth - spacing) / 2;
        final double totalHeight = itemWidth * 2 + spacing;
        return NineGridLayoutResult(
          crossAxisCount: 2,
          width: containerWidth,
          height: totalHeight,
          itemWidth: itemWidth,
          itemHeight: itemWidth,
          childAspectRatio: 1.0,
        );
      }
    }

    // 5~9 张图：标准 3 列宫格
    final int rows = (itemCount + 2) ~/ 3;
    final double itemWidth = (containerWidth - 2 * spacing) / 3;
    final double totalHeight = itemWidth * rows + (rows - 1) * spacing;
    return NineGridLayoutResult(
      crossAxisCount: 3,
      width: containerWidth,
      height: totalHeight,
      itemWidth: itemWidth,
      itemHeight: itemWidth,
      childAspectRatio: 1.0,
    );
  }
}

/// 沉浸式九宫格相册组件，承载 Hero 共享元素动画与 4 图 2x2 经典宫格排版
class NineGridGallery extends StatelessWidget {
  final List<dynamic> items;
  final String sourceScope;
  final String? dynamicId;
  final double spacing;
  final BorderRadius? borderRadius;

  const NineGridGallery({
    super.key,
    required this.items,
    this.sourceScope = 'feed',
    this.dynamicId,
    this.spacing = NineGridGalleryLayout.defaultSpacing,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    final List<GalleryMediaItem> mediaItems =
        items.map(GalleryMediaItem.from).toList();
    final int len = mediaItems.length;
    final BorderRadius effectiveBorderRadius =
        borderRadius ?? BorderRadius.circular(StyleString.imgRadius.x);

    final String safeDynamicId =
        (dynamicId != null && dynamicId!.isNotEmpty)
            ? dynamicId!
            : '${items.hashCode}';

    final List<String> heroTags = List.generate(
      len,
      (int index) => 'hero_gallery_${sourceScope}_${safeDynamicId}_$index',
    );

    return LayoutBuilder(
      builder: (BuildContext ctx, BoxConstraints constraints) {
        final double containerWidth = constraints.maxWidth;
        final double? singleImageAspectRatio =
            len == 1 ? mediaItems.first.aspectRatio : null;

        final NineGridLayoutResult layout = NineGridGalleryLayout.compute(
          itemCount: len,
          containerWidth: containerWidth,
          spacing: spacing,
          singleImageAspectRatio: singleImageAspectRatio,
        );

        if (layout.height <= 0) {
          return const SizedBox.shrink();
        }

        if (len == 1) {
          final GalleryMediaItem singleItem = mediaItems.first;
          final String heroTag = heroTags.first;

          return Container(
            width: layout.width,
            height: layout.height,
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              borderRadius: effectiveBorderRadius,
            ),
            clipBehavior: Clip.hardEdge,
            child: Stack(
              fit: StackFit.expand,
              children: [
                GestureDetector(
                  onTap: () {
                    ImagePreview.show(
                      context: context,
                      initialPage: 0,
                      imgList: [singleItem.url],
                      heroTags: [heroTag],
                    );
                  },
                  child: Hero(
                    tag: heroTag,
                    child: NetworkImgLayer(
                      src: singleItem.url,
                      width: layout.width,
                      height: layout.height,
                      origAspectRatio: singleItem.aspectRatio,
                    ),
                  ),
                ),
                if (layout.isSingleLongImage)
                  const PBadge(
                    text: '长图',
                    top: null,
                    right: null,
                    bottom: 6.0,
                    left: 6.0,
                    type: 'gray',
                  ),
              ],
            ),
          );
        }

        // 2~9 张多图
        final List<Widget> children = <Widget>[];
        for (int i = 0; i < len; i++) {
          final GalleryMediaItem item = mediaItems[i];
          final String heroTag = heroTags[i];

          children.add(
            Semantics(
              label: '图片${i + 1}, 共$len张',
              child: GestureDetector(
                onTap: () {
                  ImagePreview.show(
                    context: context,
                    initialPage: i,
                    imgList: mediaItems.map((e) => e.url).toList(),
                    heroTags: heroTags,
                  );
                },
                child: ClipRRect(
                  borderRadius: effectiveBorderRadius,
                  child: Hero(
                    tag: heroTag,
                    child: NetworkImgLayer(
                      src: item.url,
                      width: layout.itemWidth,
                      height: layout.itemHeight,
                      origAspectRatio: item.aspectRatio,
                    ),
                  ),
                ),
              ),
            ),
          );
        }

        return Container(
          width: layout.width,
          height: layout.height,
          margin: const EdgeInsets.only(top: 4),
          clipBehavior: Clip.hardEdge,
          decoration: BoxDecoration(
            borderRadius: effectiveBorderRadius,
          ),
          child: GridView.count(
            padding: EdgeInsets.zero,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: layout.crossAxisCount,
            mainAxisSpacing: spacing,
            crossAxisSpacing: spacing,
            childAspectRatio: layout.childAspectRatio,
            children: children,
          ),
        );
      },
    );
  }
}
