import 'dart:io';

import 'package:fl_pip/fl_pip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:pilipalaz/models/video/play/url.dart';
import 'package:pilipalaz/pages/live_room/index.dart';
import 'package:pilipalaz/plugin/pl_player/index.dart';
import 'package:pilipalaz/utils/storage.dart';
import 'package:pilipalaz/utils/video_utils.dart';
import 'live_quality_sheet.dart';

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
          const Spacer(),
          if (widget.controller != null) ...[
            Obx(() {
              final bool isOpen = widget.controller!.isOpenDanmu.value;
              return SizedBox(
                width: 34,
                height: 34,
                child: IconButton(
                  tooltip: '${isOpen ? "关闭" : "开启"}弹幕',
                  style: ButtonStyle(
                    padding: WidgetStateProperty.all(EdgeInsets.zero),
                  ),
                  onPressed: () {
                    final newValue = !isOpen;
                    widget.controller!.isOpenDanmu.value = newValue;
                    GStorage.setting.put(
                      SettingBoxKey.enableShowDanmaku,
                      newValue,
                    );
                    SmartDialog.showToast(
                      '已${newValue ? "开启" : "关闭"}弹幕',
                      displayTime: const Duration(seconds: 1),
                    );
                  },
                  icon: Icon(
                    isOpen
                        ? Icons.subtitles_outlined
                        : Icons.subtitles_off_outlined,
                    size: 18,
                    color: Colors.white,
                  ),
                ),
              );
            }),
            const SizedBox(width: 4),
          ],
          if (widget.liveRoomCtr != null) ...[
            Obx(() {
              final String qnDesc =
                  widget.liveRoomCtr!.currentQnDesc.value.isNotEmpty
                  ? widget.liveRoomCtr!.currentQnDesc.value
                  : '画质';
              final bool isSwitching =
                  widget.liveRoomCtr!.isSwitchingStream.value;
              return Container(
                height: 30,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                child: TextButton(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    backgroundColor: Colors.white.withValues(alpha: 0.18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    minimumSize: Size.zero,
                  ),
                  onPressed: isSwitching
                      ? null
                      : () {
                          LiveQualitySheet.show(context, widget.liveRoomCtr!);
                        },
                  child: isSwitching
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          qnDesc,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                ),
              );
            }),
            const SizedBox(width: 4),
          ],
          if (widget.liveRoomCtr != null) ...[
            Obx(() {
              final isAudio = widget.liveRoomCtr!.isAudioOnly.value;
              return SizedBox(
                width: 34,
                height: 34,
                child: IconButton(
                  key: const ValueKey('bottom_control_audio_mode_btn'),
                  tooltip: isAudio ? '恢复画面' : '听直播',
                  style: ButtonStyle(
                    padding: WidgetStateProperty.all(EdgeInsets.zero),
                  ),
                  onPressed: () {
                    widget.liveRoomCtr!.toggleAudioOnly();
                  },
                  icon: Icon(
                    isAudio
                        ? Icons.headphones_rounded
                        : Icons.headphones_outlined,
                    size: 18,
                    color: isAudio
                        ? Theme.of(context).colorScheme.primary
                        : Colors.white,
                  ),
                ),
              );
            }),
            const SizedBox(width: 4),
          ],
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
                  final controller = widget.controller;
                  if (controller != null) {
                    controller.controls = false;
                  }
                  final dim = controller?.currentDimension;
                  final vpc = controller?.videoPlayerController;
                  final int? width = (dim != null && dim.hasSize)
                      ? dim.width
                      : (vpc != null && controller!.canControlPlayback)
                      ? vpc.state.width
                      : null;
                  final int? height = (dim != null && dim.hasSize)
                      ? dim.height
                      : (vpc != null && controller!.canControlPlayback)
                      ? vpc.state.height
                      : null;
                  final rational = VideoUtils.clampPiPRational(
                    width: width,
                    height: height,
                    fallbackDirection:
                        controller?.direction.value ?? 'horizontal',
                  );
                  try {
                    await FlPiP().enable(
                      ios: FlPiPiOSConfig(
                        videoPath: controller?.dataSource.videoSource ?? '',
                        audioPath: controller?.dataSource.audioSource ?? '',
                        packageName: null,
                      ),
                      android: FlPiPAndroidConfig(aspectRatio: rational),
                    );
                  } catch (_) {
                    SmartDialog.showToast('开启画中画失败');
                  }
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
          if (widget.controller != null)
            Obx(
              () => ComBtn(
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
