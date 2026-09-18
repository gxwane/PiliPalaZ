import 'dart:io';

import 'package:fl_pip/fl_pip.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:pilipalaz/models/video/play/url.dart';
import 'package:pilipalaz/pages/live_room/index.dart';
import 'package:pilipalaz/plugin/pl_player/index.dart';
import 'package:pilipalaz/utils/storage.dart';

class BottomControl extends StatefulWidget implements PreferredSizeWidget {
  final PlPlayerController? controller;
  final LiveRoomController? liveRoomCtr;
  const BottomControl({this.controller, this.liveRoomCtr, super.key});

  @override
  State<BottomControl> createState() => _BottomControlState();

  @override
  Size get preferredSize => const Size(double.infinity, kToolbarHeight);
}

class _BottomControlState extends State<BottomControl> {
  late PlayUrlModel videoInfo;
  List<PlaySpeed> playSpeed = PlaySpeed.values;
  TextStyle subTitleStyle = const TextStyle(fontSize: 12);
  TextStyle titleStyle = const TextStyle(fontSize: 14);
  Size get preferredSize => const Size(double.infinity, kToolbarHeight);
  Box localCache = GStorage.localCache;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.transparent,
      foregroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      primary: false,
      centerTitle: false,
      automaticallyImplyLeading: false,
      titleSpacing: 14,
      title: Row(
        children: [
          // ComBtn(
          //   icon: const Icon(
          //     Icons.subtitles_outlined,
          //     size: 18,
          //     color: Colors.white,
          //   ),
          //   fuc: () => Get.back(),
          // ),
          const Spacer(),
          // ComBtn(
          //   icon: const Icon(
          //     Icons.hd_outlined,
          //     size: 18,
          //     color: Colors.white,
          //   ),
          //   fuc: () => {},
          // ),
          // const SizedBox(width: 4),
          // Obx(
          //   () => ComBtn(
          //     icon: Icon(
          //       widget.liveRoomCtr!.volumeOff.value
          //           ? Icons.volume_off_outlined
          //           : Icons.volume_up_outlined,
          //       size: 18,
          //       color: Colors.white,
          //     ),
          //     fuc: () => {},
          //   ),
          // ),
          // const SizedBox(width: 4),
          if (Platform.isAndroid) ...[
            SizedBox(
              width: 34,
              height: 34,
              child: IconButton(
                tooltip: '画中画',
                style: ButtonStyle(
                  padding: WidgetStateProperty.all(EdgeInsets.zero),
                ),
                onPressed: () async {
                  // bool canUsePiP = false;
                  // widget.controller!.hiddenControls(false);
                  // try {
                  //   canUsePiP = await widget.floating!.isPipAvailable;
                  // } on PlatformException catch (_) {
                  //   canUsePiP = false;
                  // }
                  // if (canUsePiP) {
                  //   await widget.floating!.enable(const ImmediatePiP());
                  // } else {}
                  final controller = widget.controller;
                  int rationalWidth = 16;
                  int rationalHeight = 9;
                  if (controller != null) {
                    controller.controls = false;
                    final dim = controller.currentDimension;
                    if (dim.hasSize) {
                      rationalWidth = dim.width;
                      rationalHeight = dim.height;
                    } else {
                      final vpc = controller.videoPlayerController;
                      if (controller.canControlPlayback && vpc != null) {
                        final state = vpc.state;
                        final width = state.width ?? 0;
                        final height = state.height ?? 0;
                        if (width > 0 && height > 0) {
                          rationalWidth = width;
                          rationalHeight = height;
                        }
                      }
                    }
                  }
                  FlPiP().enable(
                    ios: FlPiPiOSConfig(
                      videoPath:
                          widget.controller?.dataSource.videoSource ?? "",
                      audioPath:
                          widget.controller?.dataSource.audioSource ?? "",
                      packageName: null,
                    ),
                    android: FlPiPAndroidConfig(
                      aspectRatio: Rational(rationalWidth, rationalHeight),
                    ),
                  );
                },
                icon: const Icon(
                  Icons.picture_in_picture_alt,
                  size: 18,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 4),
          ],
          ComBtn(
            icon: Icon(
              widget.controller!.isFullScreen.value
                  ? Icons.fullscreen_exit
                  : Icons.fullscreen,
              semanticLabel: widget.controller!.isFullScreen.value
                  ? '退出全屏'
                  : '全屏',
              size: 20,
              color: Colors.white,
            ),
            fuc: () => widget.controller!.triggerFullScreen(
              status: !widget.controller!.isFullScreen.value,
            ),
          ),
        ],
      ),
    );
  }
}

class MSliderTrackShape extends RoundedRectSliderTrackShape {
  @override
  Rect getPreferredRect({
    required RenderBox parentBox,
    Offset offset = Offset.zero,
    SliderThemeData? sliderTheme,
    bool isEnabled = false,
    bool isDiscrete = false,
  }) {
    const double trackHeight = 3;
    final double trackLeft = offset.dx;
    final double trackTop =
        offset.dy + (parentBox.size.height - trackHeight) / 2 + 4;
    final double trackWidth = parentBox.size.width;
    return Rect.fromLTWH(trackLeft, trackTop, trackWidth, trackHeight);
  }
}
