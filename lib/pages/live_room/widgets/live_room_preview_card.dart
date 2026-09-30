import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:pilipalaz/common/constants.dart';
import 'package:pilipalaz/common/widgets/network_img_layer.dart';
import 'package:pilipalaz/models/live/item.dart';

/// 直播间切房过渡预览卡片（单活动槽位架构下的非激活页轻量展示）
///
/// 绝对不挂载原生播放器 Texture，通过高清封面与高斯模糊背景提供 0 白屏的即时视觉承接。
class LiveRoomPreviewCard extends StatelessWidget {
  final LiveItemModel item;

  const LiveRoomPreviewCard({super.key, required this.item});

  String get _effectiveCover {
    if (item.cover != null && item.cover!.isNotEmpty) return item.cover!;
    if (item.userCover != null && item.userCover!.isNotEmpty) {
      return item.userCover!;
    }
    return item.systemCover ?? '';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      primary: true,
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          _buildBlurredBackdrop(context),
          Column(
            children: [
              _buildAppBar(context),
              _buildCoverPlayerPlaceholder(),
              _buildAnchorStripPreview(context),
              const Expanded(child: _ChatSkeletonPlaceholder()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBlurredBackdrop(BuildContext context) {
    final cover = _effectiveCover;
    final size = MediaQuery.sizeOf(context);
    return Stack(
      fit: StackFit.expand,
      children: [
        if (cover.isNotEmpty)
          NetworkImgLayer(
            width: size.width > 0 ? size.width : 400,
            height: size.height > 0 ? size.height : 800,
            type: 'bg',
            src: cover,
          ),
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(color: Colors.black.withValues(alpha: 0.65)),
        ),
      ],
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.transparent,
      foregroundColor: Colors.white,
      elevation: 0,
      titleSpacing: 0,
      title: Text(
        item.uname?.isNotEmpty == true ? item.uname! : '直播间',
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildCoverPlayerPlaceholder() {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth > 0 ? constraints.maxWidth : 360.0;
          final h = constraints.maxHeight > 0 ? constraints.maxHeight : 202.5;
          return Stack(
            fit: StackFit.expand,
            children: [
              if (_effectiveCover.isNotEmpty)
                NetworkImgLayer(src: _effectiveCover, width: w, height: h)
              else
                Container(color: Colors.black54),
              Container(color: Colors.black26),
              const Center(
                child: Icon(
                  Icons.play_circle_outline,
                  size: 48,
                  color: Colors.white70,
                ),
              ),
              Positioned(top: 8, left: 8, child: _buildLiveBadge()),
            ],
          );
        },
      ),
    );
  }

  Widget _buildLiveBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFFF6699),
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Text(
        'LIVE',
        style: TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildAnchorStripPreview(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.4),
        border: Border(
          bottom: BorderSide(
            color: theme.dividerColor.withValues(alpha: 0.1),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          ClipOval(
            child: NetworkImgLayer(
              width: 36,
              height: 36,
              type: 'avatar',
              src: item.face ?? '',
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.uname ?? '主播',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  item.areaName ?? '直播中',
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatSkeletonPlaceholder extends StatelessWidget {
  const _ChatSkeletonPlaceholder();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: 5,
      itemBuilder: (context, i) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Container(
          height: 16,
          width: 120.0 + (i * 28 % 100),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: const BorderRadius.all(StyleString.imgRadius),
          ),
        ),
      ),
    );
  }
}
