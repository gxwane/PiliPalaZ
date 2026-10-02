import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pilipalaz/common/widgets/network_img_layer.dart';
import 'package:pilipalaz/plugin/pl_player/index.dart';
import '../controller.dart';

class LiveAudioOnlyCard extends StatefulWidget {
  final LiveRoomController controller;
  final PlPlayerController playerController;

  const LiveAudioOnlyCard({
    super.key,
    required this.controller,
    required this.playerController,
  });

  @override
  State<LiveAudioOnlyCard> createState() => _LiveAudioOnlyCardState();
}

class _LiveAudioOnlyCardState extends State<LiveAudioOnlyCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _scaleAnimation = Tween<double>(begin: 0.98, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final h5 = widget.controller.roomInfoH5.value;
      final coverUrl = h5.roomInfo?.cover ?? widget.controller.cover;
      final avatarUrl = h5.anchorInfo?.baseInfo?.face ?? '';
      final anchorName =
          h5.anchorInfo?.baseInfo?.uname ??
          widget.controller.liveItem?.uname ??
          '主播';
      final isFullScreen = widget.playerController.isFullScreen.value;

      return Container(
        color: Colors.black,
        child: Stack(
          alignment: Alignment.center,
          fit: StackFit.expand,
          children: [
            _buildBackdrop(coverUrl),
            _buildContent(avatarUrl, anchorName),
            if (isFullScreen) _buildFullScreenBackBtn(),
          ],
        ),
      );
    });
  }

  Widget _buildBackdrop(String coverUrl) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (coverUrl.isNotEmpty)
          NetworkImgLayer(
            src: coverUrl,
            width: double.infinity,
            height: double.infinity,
            type: 'bg',
          ),
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
          child: Container(color: Colors.black.withValues(alpha: 0.6)),
        ),
      ],
    );
  }

  Widget _buildContent(String avatarUrl, String anchorName) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildAvatarWithPulsingRing(avatarUrl, primary),
            const SizedBox(height: 14),
            Text(
              anchorName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            _buildAudioStatusBadge(primary),
            const SizedBox(height: 14),
            _buildRestoreButton(primary),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatarWithPulsingRing(String avatarUrl, Color primary) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: primary.withValues(alpha: 0.8), width: 2),
          boxShadow: [
            BoxShadow(
              color: primary.withValues(alpha: 0.35),
              blurRadius: 16,
              spreadRadius: 2,
            ),
          ],
        ),
        child: ClipOval(
          child: SizedBox(
            width: 64,
            height: 64,
            child: avatarUrl.isNotEmpty
                ? NetworkImgLayer(
                    src: avatarUrl,
                    width: 64,
                    height: 64,
                    type: 'avatar',
                  )
                : const Icon(
                    Icons.account_circle,
                    size: 64,
                    color: Colors.white70,
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildAudioStatusBadge(Color primary) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.graphic_eq_rounded, size: 14, color: primary),
          const SizedBox(width: 4),
          const Text(
            '听直播模式 · 低功耗运行',
            style: TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildRestoreButton(Color primary) {
    return TextButton.icon(
      key: const ValueKey('restore_video_button'),
      style: TextButton.styleFrom(
        backgroundColor: primary.withValues(alpha: 0.22),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: primary.withValues(alpha: 0.6)),
        ),
      ),
      onPressed: widget.controller.toggleAudioOnly,
      icon: const Icon(Icons.videocam_rounded, size: 16),
      label: const Text(
        '恢复画面',
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildFullScreenBackBtn() {
    return Positioned(
      top: 12,
      left: 12,
      child: SafeArea(
        child: IconButton(
          key: const ValueKey('audio_mode_exit_fullscreen'),
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            widget.playerController.triggerFullScreen(status: false);
          },
        ),
      ),
    );
  }
}
