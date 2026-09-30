import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:pilipalaz/http/api_result.dart';
import 'package:pilipalaz/http/live.dart';
import 'package:pilipalaz/utils/storage.dart';

class LiveInputBar extends StatefulWidget {
  final int roomId;

  const LiveInputBar({super.key, required this.roomId});

  @override
  State<LiveInputBar> createState() => _LiveInputBarState();
}

class _LiveInputBarState extends State<LiveInputBar> {
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  int _cooldownSeconds = 0;
  Timer? _cooldownTimer;
  bool _isSending = false;

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _startCooldown() {
    setState(() => _cooldownSeconds = 3);
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_cooldownSeconds <= 1) {
        timer.cancel();
        setState(() => _cooldownSeconds = 0);
      } else {
        setState(() => _cooldownSeconds--);
      }
    });
  }

  Future<void> _handleSend() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _isSending) return;

    if (GStorage.userInfo.get('userInfoCache') == null) {
      SmartDialog.showToast('请先登录');
      return;
    }

    if (_cooldownSeconds > 0) {
      SmartDialog.showToast('发言过快，请 $_cooldownSeconds 秒后再试');
      return;
    }

    setState(() => _isSending = true);
    try {
      final res = await LiveHttp.sendDanmaku(roomId: widget.roomId, msg: text);
      if (!mounted) return;
      if (res is ApiSuccess) {
        _textController.clear();
        _focusNode.unfocus();
        _startCooldown();
      } else if (res is ApiFailure) {
        SmartDialog.showToast(
          res.message.isNotEmpty ? res.message : '发送失败，请重试',
        );
      } else {
        SmartDialog.showToast('发送失败，请重试');
      }
    } catch (_) {
      SmartDialog.showToast('发送失败');
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        top: 8,
        bottom: 8 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.08))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(20),
              ),
              child: TextField(
                controller: _textController,
                focusNode: _focusNode,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  hintText: _cooldownSeconds > 0
                      ? '冷却中 ($_cooldownSeconds s)...'
                      : '发送弹幕与大家互动...',
                  hintStyle: const TextStyle(
                    color: Colors.white38,
                    fontSize: 13,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 11),
                ),
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _handleSend(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: (_cooldownSeconds > 0 || _isSending)
                ? null
                : _handleSend,
            icon: _isSending
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white70,
                    ),
                  )
                : Icon(
                    Icons.send_rounded,
                    color: _cooldownSeconds > 0
                        ? Colors.white24
                        : const Color(0xFF64B5F6),
                    size: 22,
                  ),
          ),
        ],
      ),
    );
  }
}
