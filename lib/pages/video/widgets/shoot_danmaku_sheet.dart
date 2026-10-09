import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:canvas_danmaku/canvas_danmaku.dart';
import 'package:pilipalaz/http/api_result.dart';
import 'package:pilipalaz/http/danmaku.dart';
import 'package:pilipalaz/plugin/pl_player/controller.dart';
import 'package:pilipalaz/utils/danmaku.dart';
import 'package:pilipalaz/utils/feed_back.dart';
import 'package:pilipalaz/utils/storage.dart';

/// 独立的发射弹幕面板组件，支持弹幕类型（滚动/顶部/底部）与 12 种标准色彩选择
class ShootDanmakuSheet extends StatefulWidget {
  final int cid;
  final String bvid;
  final PlPlayerController playerController;

  const ShootDanmakuSheet({
    super.key,
    required this.cid,
    required this.bvid,
    required this.playerController,
  });

  /// 唤起发射弹幕面板的快捷静态方法
  static Future<void> show({
    required BuildContext context,
    required int cid,
    required String bvid,
    required PlPlayerController playerController,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) => ShootDanmakuSheet(
        cid: cid,
        bvid: bvid,
        playerController: playerController,
      ),
    );
  }

  @override
  State<ShootDanmakuSheet> createState() => _ShootDanmakuSheetState();
}

class _ShootDanmakuSheetState extends State<ShootDanmakuSheet> {
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  int _selectedMode = 1;
  int _selectedColor = 0xFFFFFF;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _selectedMode = GStorage.setting.get(
      SettingBoxKey.danmakuLastMode,
      defaultValue: 1,
    );
    _selectedColor = GStorage.setting.get(
      SettingBoxKey.danmakuLastColor,
      defaultValue: 0xFFFFFF,
    );
    _textController.addListener(_onTextChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  void _onTextChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _textController.removeListener(_onTextChanged);
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _handleSend() async {
    final String msg = _textController.text.trim();
    if (msg.isEmpty) {
      SmartDialog.showToast('弹幕内容不能为空');
      return;
    }
    if (msg.length > 100) {
      SmartDialog.showToast('弹幕内容不能超过 100 个字符');
      return;
    }

    final dynamic userInfo = GStorage.userInfo.get('userInfoCache');
    if (userInfo == null) {
      SmartDialog.showToast('请先登录账号');
      return;
    }

    setState(() {
      _isSending = true;
    });

    final int currentPosition =
        widget.playerController.position.value.inMilliseconds;

    try {
      final result = await DanmakuApi.instance.shootDanmaku(
        oid: widget.cid,
        message: msg,
        bvid: widget.bvid,
        progress: currentPosition,
        mode: _selectedMode,
        color: _selectedColor,
        type: 1,
      );

      if (!mounted) return;

      if (result is ApiSuccess<DanmakuSendReceipt>) {
        // 保存用户最后选择的弹幕模式与颜色偏好
        GStorage.setting.put(SettingBoxKey.danmakuLastMode, _selectedMode);
        GStorage.setting.put(SettingBoxKey.danmakuLastColor, _selectedColor);

        FeedBackUtils.selectionClick();
        Navigator.of(context).pop();
        SmartDialog.showToast('发送成功');

        final bool isPlaying = widget.playerController.playerStatus.playing;
        final Color danmakuColor = DmUtils.decimalToColor(_selectedColor);
        final DanmakuItemType itemType = DmUtils.getPosition(_selectedMode);

        // 1. 注入本地分片数据中，确保重播、Seek 时可回溯呈现
        widget.playerController.plDanmakuController?.addLocalDanmaku(
          message: msg,
          color: _selectedColor,
          mode: _selectedMode,
          progress: currentPosition,
          markAsRendered: isPlaying,
        );

        // 2. 若当前正处于播放中，即刻投递到渲染画布以提供实时发射动效；
        // 若处于暂停状态，坚决不直接投递 addDanmaku，避免底层动画在定格画面上跑飞，
        // 待用户点击恢复起播时由帧监听准时喷出。
        if (isPlaying) {
          widget.playerController.danmakuController?.addDanmaku(
            DanmakuContentItem(
              msg,
              color: danmakuColor,
              type: itemType,
              selfSend: true,
            ),
          );
        }
      } else {
        final failure = result as ApiFailure<DanmakuSendReceipt>;
        SmartDialog.showToast('发送失败：${failure.message}');
      }
    } on Exception catch (e) {
      SmartDialog.showToast('发送异常：$e');
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    final keyboardHeight = MediaQuery.viewInsetsOf(context).bottom;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: keyboardHeight > 0 ? keyboardHeight + 8 : 16,
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildDragHandle(theme),
              const SizedBox(height: 8),
              _buildHeader(theme),
              const SizedBox(height: 12),
              _buildInputArea(theme),
              const SizedBox(height: 12),
              if (!isLandscape) ...[
                _buildModeSelector(theme),
                const SizedBox(height: 12),
                _buildColorPalette(theme),
              ] else ...[
                _buildLandscapeToolbar(theme),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDragHandle(ThemeData theme) {
    return Center(
      child: Container(
        width: 36,
        height: 4,
        decoration: BoxDecoration(
          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          '发送弹幕',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.close, size: 20),
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  Widget _buildInputArea(ThemeData theme) {
    final int textLength = _textController.text.length;
    final bool canSend = textLength > 0 && textLength <= 100 && !_isSending;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: TextField(
            controller: _textController,
            focusNode: _focusNode,
            maxLength: 100,
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => _handleSend(),
            decoration: InputDecoration(
              hintText: '发个弹幕见证当下...',
              hintStyle: TextStyle(
                color: theme.colorScheme.onSurfaceVariant.withValues(
                  alpha: 0.6,
                ),
                fontSize: 14,
              ),
              counterText: '$textLength/100',
              counterStyle: TextStyle(
                color: textLength > 100
                    ? theme.colorScheme.error
                    : theme.colorScheme.outline,
                fontSize: 11,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 10,
              ),
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: BorderSide(color: theme.colorScheme.outlineVariant),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: BorderSide(
                  color: theme.colorScheme.outlineVariant.withValues(
                    alpha: 0.6,
                  ),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: BorderSide(
                  color: theme.colorScheme.primary,
                  width: 1.5,
                ),
              ),
              suffixIcon: _textController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () => _textController.clear(),
                    )
                  : null,
            ),
          ),
        ),
        const SizedBox(width: 10),
        FilledButton(
          onPressed: canSend ? _handleSend : null,
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          child: _isSending
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('发送'),
        ),
      ],
    );
  }

  Widget _buildModeSelector(ThemeData theme) {
    return SegmentedButton<int>(
      showSelectedIcon: false,
      segments: const [
        ButtonSegment<int>(
          value: 1,
          label: Text('滚动'),
          icon: Icon(Icons.wrap_text, size: 18),
        ),
        ButtonSegment<int>(
          value: 5,
          label: Text('顶部'),
          icon: Icon(Icons.vertical_align_top, size: 18),
        ),
        ButtonSegment<int>(
          value: 4,
          label: Text('底部'),
          icon: Icon(Icons.vertical_align_bottom, size: 18),
        ),
      ],
      selected: {_selectedMode},
      onSelectionChanged: (Set<int> newSelection) {
        if (newSelection.isNotEmpty) {
          FeedBackUtils.selectionClick();
          setState(() {
            _selectedMode = newSelection.first;
          });
        }
      },
      style: const ButtonStyle(
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }

  Widget _buildColorPalette(ThemeData theme) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: DmUtils.standardColors.map((color) {
          final int decimalValue = DmUtils.colorToDecimal(color);
          final bool isSelected = _selectedColor == decimalValue;
          final bool isLightColor = color.computeLuminance() > 0.5;
          final Color checkColor = isLightColor ? Colors.black87 : Colors.white;

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.5),
            child: GestureDetector(
              onTap: () {
                FeedBackUtils.selectionClick();
                setState(() {
                  _selectedColor = decimalValue;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected
                        ? theme.colorScheme.primary
                        : (isLightColor
                              ? Colors.black.withValues(alpha: 0.2)
                              : Colors.transparent),
                    width: isSelected ? 2.5 : 1.0,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: theme.colorScheme.primary.withValues(
                              alpha: 0.35,
                            ),
                            blurRadius: 6,
                            spreadRadius: 1,
                          ),
                        ]
                      : null,
                ),
                child: isSelected
                    ? Icon(Icons.check, size: 18, color: checkColor)
                    : null,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildLandscapeToolbar(ThemeData theme) {
    return Row(
      children: [
        Expanded(flex: 4, child: _buildModeSelector(theme)),
        const SizedBox(width: 12),
        Expanded(flex: 6, child: _buildColorPalette(theme)),
      ],
    );
  }
}
