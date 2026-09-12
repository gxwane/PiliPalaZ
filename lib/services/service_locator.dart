import 'package:pilipalaz/services/auth/auth_session_manager.dart';
import 'package:pilipalaz/services/auth/credential_store.dart';
import 'package:pilipalaz/services/auth/flutter_secure_credential_store.dart';
import 'package:pilipalaz/services/auth/legacy_credential_source.dart';
import 'package:pilipalaz/services/auth/secure_cookie_jar.dart';
import 'package:pilipalaz/services/auth/webview_session_bridge.dart';
import 'package:pilipalaz/utils/storage.dart';

import 'package:pilipalaz/plugin/pl_player/playback_commands.dart';
import 'audio_handler.dart';
import 'audio_session.dart';
import 'package:flutter_floating/floating/floating.dart';

late VideoPlayerServiceHandler videoPlayerServiceHandler;
late PlaybackAudioSession audioSessionHandler;
late CredentialStore credentialStore;
late LegacyCredentialSource legacyCredentialSource;
late AuthSessionManager authSessionManager;
late SecureCookieJar secureCookieJar;
late WebViewSessionBridge webviewSessionBridge;
Floating? floatingWindow;
const globalId = 'global_floating_window';
String popRouteStackContinuously = "";

Future<void> setupServiceLocator() async {
  credentialStore = FlutterSecureCredentialStore();
  legacyCredentialSource = HiveLegacyCredentialSource(
    localCache: GStorage.localCache,
  );
  authSessionManager = AuthSessionManager(
    credentialStore: credentialStore,
    legacySource: legacyCredentialSource,
    localState: HiveAuthLocalState(
      localCache: GStorage.localCache,
      userInfo: GStorage.userInfo,
    ),
  );
  secureCookieJar = SecureCookieJar(
    onChanged: authSessionManager.persistCookieSnapshot,
  );
  authSessionManager.registerRuntimeCredentialClear(secureCookieJar.deleteAll);
  webviewSessionBridge = WebViewSessionBridge(cookieJar: secureCookieJar);
  await webviewSessionBridge.clear();

  final audio = await initAudioService();
  videoPlayerServiceHandler = audio;
  audioSessionHandler = AudioSessionHandler();
}
