import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pilipalaz/services/live/live_danmaku_client.dart';
import 'package:pilipalaz/services/live/live_message.dart';

class LiveChatController extends GetxController {
  final LiveDanmakuClient? danmakuClient;
  final int maxMessages;

  final RxList<LiveMessage> chatMessages = <LiveMessage>[].obs;
  final RxList<LiveSuperChatMessage> activeSuperChats =
      <LiveSuperChatMessage>[].obs;
  final RxBool isScrolledUp = false.obs;
  final RxInt unreadCount = 0.obs;

  final ScrollController scrollController = ScrollController();
  final List<LiveMessage> _pendingMessages = <LiveMessage>[];
  StreamSubscription<LiveMessage>? _messageSubscription;
  Timer? _flushTimer;
  bool _isDisposed = false;

  LiveChatController({this.danmakuClient, this.maxMessages = 200}) {
    _initScrollListener();
    _startBatchFlushTimer();
    _bindMessageStream();
  }

  void _initScrollListener() {
    scrollController.addListener(() {
      if (!scrollController.hasClients) return;
      final offset = scrollController.offset;
      if (offset > 30) {
        if (!isScrolledUp.value) isScrolledUp.value = true;
      } else if (offset <= 10) {
        if (isScrolledUp.value) isScrolledUp.value = false;
        if (unreadCount.value > 0) unreadCount.value = 0;
      }
    });
  }

  void _startBatchFlushTimer() {
    _flushTimer = Timer.periodic(const Duration(milliseconds: 120), (_) {
      flushPendingMessages();
    });
  }

  void _bindMessageStream() {
    if (danmakuClient != null) {
      bindDanmakuClient(danmakuClient!);
    }
  }

  void bindDanmakuClient(LiveDanmakuClient client) {
    if (_isDisposed) return;
    _messageSubscription?.cancel();
    _messageSubscription = client.onMessage.listen(enqueueMessage);
  }

  void enqueueMessage(LiveMessage message) {
    if (_isDisposed) return;
    _pendingMessages.add(message);
    if (message is LiveSuperChatMessage) {
      activeSuperChats.insert(0, message);
      if (activeSuperChats.length > 20) {
        activeSuperChats.removeLast();
      }
    }
  }

  void flushPendingMessages() {
    if (_isDisposed || _pendingMessages.isEmpty) return;
    final List<LiveMessage> toInsert = List<LiveMessage>.from(
      _pendingMessages.reversed,
    );
    _pendingMessages.clear();

    chatMessages.insertAll(0, toInsert);
    if (chatMessages.length > maxMessages) {
      chatMessages.removeRange(maxMessages, chatMessages.length);
    }

    if (isScrolledUp.value) {
      unreadCount.value += toInsert.length;
    }
  }

  void scrollToBottom() {
    if (scrollController.hasClients) {
      scrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
    isScrolledUp.value = false;
    unreadCount.value = 0;
  }

  @override
  void onClose() {
    if (_isDisposed) return;
    _isDisposed = true;
    _flushTimer?.cancel();
    _flushTimer = null;
    _messageSubscription?.cancel();
    _messageSubscription = null;
    scrollController.dispose();
    chatMessages.clear();
    activeSuperChats.clear();
    _pendingMessages.clear();
    super.onClose();
  }
}
