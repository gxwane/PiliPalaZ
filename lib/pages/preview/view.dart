// ignore_for_file: library_private_types_in_public_api

import 'dart:io';

import 'package:dismissible_page/dismissible_page.dart';
import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:pilipalaz/utils/download.dart';

import 'controller.dart';

typedef DoubleClickAnimationListener = void Function();

/// 沉浸式大图/相册预览组件，支持透明路由、Hero 共享元素动画与下拉拖拽退出手势
class ImagePreview extends StatefulWidget {
  final int? initialPage;
  final List<String>? imgList;
  final List<String>? heroTags;

  const ImagePreview({
    super.key,
    this.initialPage,
    this.imgList,
    this.heroTags,
  });

  /// 唤起透明路由大图预览的便捷静态入口
  static Future<void> show({
    required BuildContext context,
    required int initialPage,
    required List<String> imgList,
    List<String>? heroTags,
  }) {
    return context.pushTransparentRoute<void>(
      ImagePreview(
        initialPage: initialPage,
        imgList: imgList,
        heroTags: heroTags,
      ),
    );
  }

  @override
  _ImagePreviewState createState() => _ImagePreviewState();
}

class _ImagePreviewState extends State<ImagePreview>
    with TickerProviderStateMixin {
  late final PreviewController _previewController;
  late AnimationController _doubleClickAnimationController;
  Animation<double>? _doubleClickAnimation;
  late DoubleClickAnimationListener _doubleClickAnimationListener;
  final List<double> doubleTapScales = <double>[1.0, 2.5];

  /// 是否处于放大浏览状态（缩放比例 > 1.0）
  bool _isZoomed = false;

  @override
  void initState() {
    super.initState();
    _previewController = Get.put(PreviewController());

    final int initial = widget.initialPage ?? 0;
    final List<String> list = widget.imgList ?? <String>[];
    _previewController.initialPage.value = initial;
    _previewController.currentPage.value = initial + 1;
    _previewController.imgList.value = list;
    if (list.isNotEmpty && initial < list.length) {
      _previewController.currentImgUrl = list[initial];
    }

    setStatusBar();
    _doubleClickAnimationController = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );
  }

  void onOpenMenu() {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          clipBehavior: Clip.hardEdge,
          contentPadding: const EdgeInsets.fromLTRB(0, 12, 0, 12),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                onTap: () {
                  _previewController.onShareImg();
                  Get.back();
                },
                dense: true,
                title: const Text('分享', style: TextStyle(fontSize: 14)),
              ),
              ListTile(
                onTap: () {
                  Clipboard.setData(
                        ClipboardData(text: _previewController.currentImgUrl),
                      )
                      .then((_) {
                        Get.back();
                        SmartDialog.showToast('已复制到粘贴板');
                      })
                      .catchError((dynamic err) {
                        SmartDialog.showNotify(
                          msg: err.toString(),
                          notifyType: NotifyType.error,
                        );
                      });
                },
                dense: true,
                title: const Text('复制链接', style: TextStyle(fontSize: 14)),
              ),
              ListTile(
                onTap: () {
                  Get.back();
                  DownloadUtils.downloadImg(
                    context,
                    _previewController.currentImgUrl,
                  );
                },
                dense: true,
                title: const Text('保存到手机', style: TextStyle(fontSize: 14)),
              ),
            ],
          ),
        );
      },
    );
  }

  // 隐藏状态栏，避免遮挡图片内容
  Future<void> setStatusBar() async {
    if (Platform.isIOS || Platform.isAndroid) {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    }
  }

  @override
  void dispose() {
    try {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    } on Exception catch (_) {}
    _doubleClickAnimationController.dispose();
    clearGestureDetailsCache();
    if (Get.isRegistered<PreviewController>()) {
      Get.delete<PreviewController>();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<String> list = widget.imgList ?? <String>[];
    if (list.isEmpty) {
      return const Scaffold(backgroundColor: Colors.transparent);
    }

    return DismissiblePage(
      onDismissed: () => Navigator.of(context).pop(),
      disabled: _isZoomed,
      direction: DismissiblePageDismissDirection.down,
      backgroundColor: Colors.black,
      startingOpacity: 1.0,
      minScale: 0.8,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        primary: false,
        extendBody: true,
        appBar: AppBar(
          primary: false,
          toolbarHeight: 0,
          backgroundColor: Colors.transparent,
          systemOverlayStyle: SystemUiOverlayStyle.light,
        ),
        body: Stack(
          children: [
            Semantics(
              label: '长按保存，下滑退出',
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                onLongPress: onOpenMenu,
                child: ExtendedImageGesturePageView.builder(
                  controller: ExtendedPageController(
                    initialPage: _previewController.initialPage.value,
                    pageSpacing: 0,
                  ),
                  onPageChanged: (int index) {
                    _previewController.onChange(index);
                    if (_isZoomed) {
                      setState(() {
                        _isZoomed = false;
                      });
                    }
                  },
                  canScrollPage: (GestureDetails? gestureDetails) {
                    final double scale = gestureDetails?.totalScale ?? 1.0;
                    final bool zoomed = scale > 1.001;
                    if (_isZoomed != zoomed) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted && _isZoomed != zoomed) {
                          setState(() {
                            _isZoomed = zoomed;
                          });
                        }
                      });
                    }
                    return !zoomed;
                  },
                  itemCount: list.length,
                  itemBuilder: (BuildContext ctx, int index) {
                    final String? heroTag = widget.heroTags != null &&
                            index < widget.heroTags!.length
                        ? widget.heroTags![index]
                        : null;

                    Widget image = ExtendedImage.network(
                      list[index],
                      fit: BoxFit.contain,
                      mode: ExtendedImageMode.gesture,
                      onDoubleTap: (ExtendedImageGestureState state) {
                        final Offset? pointerDownPosition =
                            state.pointerDownPosition;
                        final double? begin = state.gestureDetails!.totalScale;
                        double end;

                        _doubleClickAnimation?.removeListener(
                          _doubleClickAnimationListener,
                        );
                        _doubleClickAnimationController.stop();
                        _doubleClickAnimationController.reset();

                        end = begin == doubleTapScales[0]
                            ? doubleTapScales[1]
                            : doubleTapScales[0];

                        _doubleClickAnimationListener = () {
                          state.handleDoubleTap(
                            scale: _doubleClickAnimation!.value,
                            doubleTapPosition: pointerDownPosition,
                          );
                        };
                        _doubleClickAnimation =
                            _doubleClickAnimationController.drive(
                          Tween<double>(begin: begin, end: end),
                        );
                        _doubleClickAnimation!.addListener(
                          _doubleClickAnimationListener,
                        );
                        _doubleClickAnimationController.forward();
                      },
                      loadStateChanged: (ExtendedImageState state) {
                        if (state.extendedImageLoadState == LoadState.loading) {
                          final ImageChunkEvent? loadingProgress =
                              state.loadingProgress;
                          final double? progress =
                              loadingProgress?.expectedTotalBytes != null
                                  ? loadingProgress!.cumulativeBytesLoaded /
                                      loadingProgress.expectedTotalBytes!
                                  : null;
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: <Widget>[
                                SizedBox(
                                  width: 150.0,
                                  child: LinearProgressIndicator(
                                    value: progress,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }
                        if (state.extendedImageLoadState == LoadState.failed) {
                          return const Center(
                            child: Icon(
                              Icons.broken_image_outlined,
                              color: Colors.white70,
                              size: 48,
                            ),
                          );
                        }
                        return null;
                      },
                      initGestureConfigHandler: (ExtendedImageState state) {
                        return GestureConfig(
                          inPageView: true,
                          initialScale: 1.0,
                          maxScale: 15.0,
                          animationMaxScale: 16.0,
                          initialAlignment: InitialAlignment.center,
                        );
                      },
                    );

                    if (heroTag != null && heroTag.isNotEmpty) {
                      image = Hero(
                        tag: heroTag,
                        child: image,
                      );
                    }
                    return image;
                  },
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  bottom: MediaQuery.of(context).padding.bottom + 20,
                  top: 16,
                ),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[Colors.transparent, Colors.black87],
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    list.length > 1
                        ? Obx(
                            () => Text.rich(
                              textAlign: TextAlign.center,
                              TextSpan(
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                                children: [
                                  TextSpan(
                                    text: _previewController.currentPage
                                        .toString(),
                                  ),
                                  const TextSpan(text: ' / '),
                                  TextSpan(
                                    text: list.length.toString(),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : const SizedBox(),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close, color: Colors.white),
                      tooltip: '关闭',
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
