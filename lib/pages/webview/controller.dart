import 'dart:async';

import 'package:get/get.dart';
import 'package:pilipalaz/http/http_runtime.dart';
import 'package:pilipalaz/services/service_locator.dart';
import 'package:pilipalaz/utils/event_bus.dart';
import 'package:pilipalaz/utils/id_utils.dart';
import 'package:webview_flutter/webview_flutter.dart';

class WebviewController extends GetxController {
  String url = '';
  RxString type = ''.obs;
  String pageTitle = '';
  String uaType = '';
  final WebViewController controller = WebViewController();
  RxInt loadProgress = 0.obs;
  RxBool loadShow = true.obs;
  EventBus eventBus = EventBus();

  @override
  void onInit() {
    super.onInit();
    url = Get.parameters['url']!;
    type.value = Get.parameters['type']!;
    pageTitle = Get.parameters['pageTitle']!;
    uaType = Get.parameters['uaType'] ?? 'mob';

    unawaited(webviewInit(uaType: uaType));
  }

  Future<void> webviewInit({String uaType = 'mob'}) async {
    controller
      ..setUserAgent(HttpRuntime.instance.headerUa(type: uaType))
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..enableZoom(true)
      ..setNavigationDelegate(
        NavigationDelegate(
          // 页面加载
          onProgress: (int progress) {
            // Update loading bar.
            loadProgress.value = progress;
          },
          onPageStarted: (String url) {
            final parseUrl = Uri.parse(url);
            if (parseUrl.pathSegments.isEmpty) return;
            final String str = parseUrl.pathSegments[0];
            final Map matchRes = IdUtils.matchAvorBv(input: str);
            final List matchKeys = matchRes.keys.toList();
            if (matchKeys.isNotEmpty) {
              if (matchKeys.first == 'BV') {
                Get.offAndToNamed(
                  '/searchResult',
                  parameters: {'keyword': matchRes['BV']},
                );
              }
            }
          },
          onPageFinished: (String url) {
            if (type.value == 'liveRoom') {
              //注入js
              unawaited(
                controller.runJavaScriptReturningResult('''
                document.styleSheets[0].insertRule('div.open-app-btn.bili-btn-warp {display:none;}', 0);
                document.styleSheets[0].insertRule('#app__display-area > div.control-panel {display:none;}', 0);
                '''),
              );
            } else if (type.value == 'whisper') {
              unawaited(
                controller.runJavaScriptReturningResult('''
                document.querySelector('#internationalHeader').remove();
                document.querySelector('#message-navbar').remove();
              '''),
              );
            }
          },
          // 加载完成
          onUrlChange: (UrlChange urlChange) async {
            loadShow.value = false;
            // String url = urlChange.url ?? '';
          },
          onWebResourceError: (WebResourceError error) {},
          onNavigationRequest: (NavigationRequest request) {
            if (request.url.startsWith('bilibili://')) {
              if (request.url.startsWith('bilibili://video/')) {
                String str = Uri.parse(request.url).pathSegments[0];
                Get.offAndToNamed(
                  '/searchResult',
                  parameters: {'keyword': str},
                );
              }
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      );
    final uri = Uri.parse(url);
    await webviewSessionBridge.prepare(uri);
    await controller.loadRequest(uri);
  }

  @override
  void onClose() {
    unawaited(webviewSessionBridge.clear());
    super.onClose();
  }
}
