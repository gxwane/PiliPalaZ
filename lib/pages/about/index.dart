import 'package:pilipalaz/common/constants.dart';
import 'package:pilipalaz/common/widgets/app_update_center.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:pilipalaz/pages/setting/controller.dart';
import 'package:pilipalaz/utils/storage.dart';
import 'package:url_launcher/url_launcher.dart';
import 'cache_usage_tile.dart';
import '../../utils/cache_manage.dart';

class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  final AboutController _aboutController = Get.put(AboutController());

  Future<bool> _clearCache() async {
    final confirmed = await _showClearCacheConfirmation();
    if (!confirmed || !mounted) {
      return false;
    }

    SmartDialog.showLoading(msg: '正在清除...');
    Object? clearError;
    try {
      await CacheManage.instance.clearApplicationCache();
    } catch (error, stackTrace) {
      clearError = error;
      debugPrint('Failed to clear application cache: $error');
      debugPrintStack(stackTrace: stackTrace);
    } finally {
      await SmartDialog.dismiss();
    }

    if (clearError == null) {
      SmartDialog.showToast('清除成功');
    } else {
      SmartDialog.showToast('清除失败：$clearError');
    }
    return true;
  }

  Future<bool> _showClearCacheConfirmation() async {
    final autoClearCache = RxBool(
      GStorage.setting.get(SettingBoxKey.autoClearCache, defaultValue: false),
    );
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('提示'),
            content: const Text('该操作将清除图片及网络请求缓存数据'),
            actions: [
              Obx(
                () => TextButton.icon(
                  onPressed: () {
                    autoClearCache.value = !autoClearCache.value;
                    GStorage.setting.put(
                      SettingBoxKey.autoClearCache,
                      autoClearCache.value,
                    );
                    SmartDialog.showToast(
                      autoClearCache.value ? '启动时自动清除缓存' : '已关闭',
                    );
                  },
                  icon: Icon(
                    autoClearCache.value
                        ? Icons.check_box
                        : Icons.check_box_outline_blank,
                  ),
                  label: const Text('自动'),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(
                  '取消',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
              ),
              TextButton(
                autofocus: true,
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('清除'),
              ),
            ],
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    final Color outline = Theme.of(context).colorScheme.outline;
    TextStyle subTitleStyle = TextStyle(
      fontSize: 13,
      color: Theme.of(context).colorScheme.outline,
    );
    return Scaffold(
      appBar: AppBar(
        title: Text('关于', style: Theme.of(context).textTheme.titleMedium),
      ),
      body: ListView(
        children: [
          Column(
            children: [
              Image.asset(
                excludeFromSemantics: true,
                height: 150,
                'assets/images/logo/logo_android_2.png',
              ),
              Text(
                'PiliPalaZ',
                textAlign: TextAlign.left,
                style: Theme.of(context).textTheme.titleMedium,
                semanticsLabel: 'PiliPalaZ 与你一起，发现不一样的世界',
              ),
              Text(
                '使用 Flutter 开发的哔哩哔哩非官方第三方客户端',
                textAlign: TextAlign.left,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.outline,
                  height: 3,
                ),
                semanticsLabel: '使用Flutter开发的B站第三方客户端（带无障碍适配）',
              ),
            ],
          ),
          Obx(
            () => ListTile(
              onTap: () => _aboutController.tapOnVersion(),
              title: const Text('当前版本'),
              leading: Icon(MdiIcons.sourceCommitLocal),
              trailing: Text(
                _aboutController.currentVersion.value,
                style: subTitleStyle,
              ),
            ),
          ),
          ListTile(
            onTap: () =>
                AppUpdateCoordinator.instance.showManualUpdateCenter(context),
            title: const Text('检查更新'),
            subtitle: const Text('自行选择正式版或测试版'),
            leading: Icon(MdiIcons.newBox),
            trailing: Icon(Icons.arrow_forward_ios, size: 16, color: outline),
          ),
          ListTile(
            onTap: () => _aboutController.releaseNotes(),
            leading: const Icon(Icons.history),
            title: const Text('版本记录'),
            trailing: Icon(Icons.arrow_forward_ios, size: 16, color: outline),
          ),
          Divider(
            thickness: 1,
            height: 30,
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          ListTile(
            onTap: () => _aboutController.githubUrl(),
            leading: Icon(MdiIcons.github),
            title: const Text('开源仓库'),
            trailing: Text('github.com/gxwane/PiliPalaZ', style: subTitleStyle),
          ),
          ListTile(
            onTap: () => _aboutController.feedback(context),
            leading: Icon(MdiIcons.chatAlert),
            title: const Text('问题反馈'),
            trailing: Icon(Icons.arrow_forward_ios, size: 16, color: outline),
          ),
          const ListTile(
            leading: Icon(Icons.handshake_outlined),
            title: Text('协作维护'),
            subtitle: Text(
              '本项目采用人机协作方式持续维护。部分代码、问题分析、测试和文档由 OpenAI Codex 协助完成，相关变更在发布前由人工测试。',
            ),
          ),
          ListTile(
            onTap: () => _aboutController.logs(),
            leading: const Icon(Icons.bug_report),
            title: const Text('错误日志'),
            trailing: Icon(Icons.arrow_forward_ios, size: 16, color: outline),
          ),
          CacheUsageTile(
            cacheService: CacheManage.instance,
            onClear: _clearCache,
          ),
          ListTile(
            title: const Text('导入/导出设置'),
            dense: false,
            leading: const Icon(Icons.import_export),
            onTap: () async {
              await showDialog(
                context: context,
                builder: (context) {
                  return SimpleDialog(
                    title: const Text('导入/导出设置'),
                    children: [
                      ListTile(
                        title: const Text('导出设置至剪贴板'),
                        onTap: () async {
                          Get.back();
                          String data = await GStorage.exportAllSettings();
                          Clipboard.setData(ClipboardData(text: data));
                          SmartDialog.showToast('已复制到剪贴板');
                        },
                      ),
                      ListTile(
                        title: const Text('从剪贴板导入设置'),
                        onTap: () async {
                          Get.back();
                          ClipboardData? data = await Clipboard.getData(
                            'text/plain',
                          );
                          if (data == null ||
                              data.text == null ||
                              data.text!.isEmpty) {
                            SmartDialog.showToast('剪贴板无数据');
                            return;
                          }
                          if (!context.mounted) return;
                          await showDialog(
                            context: context,
                            builder: (context) {
                              return AlertDialog(
                                title: const Text('是否导入如下设置？'),
                                content: Text(data.text!),
                                actions: [
                                  TextButton(
                                    onPressed: () {
                                      Get.back();
                                    },
                                    child: const Text('取消'),
                                  ),
                                  TextButton(
                                    onPressed: () async {
                                      Get.back();
                                      try {
                                        await GStorage.importAllSettings(
                                          data.text!,
                                        );
                                        SmartDialog.showToast('导入成功');
                                      } catch (e) {
                                        SmartDialog.showToast('导入失败：$e');
                                      }
                                    },
                                    child: const Text('确定'),
                                  ),
                                ],
                              );
                            },
                          );
                        },
                      ),
                    ],
                  );
                },
              );
            },
          ),
          ListTile(
            title: const Text('重置所有设置'),
            leading: const Icon(Icons.settings_backup_restore),
            onTap: () async {
              await showDialog(
                context: context,
                builder: (context) {
                  return AlertDialog(
                    title: const Text('重置所有设置'),
                    content: const Text('是否重置所有设置？'),
                    actions: [
                      TextButton(
                        onPressed: () {
                          Get.back();
                        },
                        child: const Text('取消'),
                      ),
                      TextButton(
                        onPressed: () {
                          Get.back();
                          GStorage.setting.clear();
                          GStorage.video.clear();
                          SmartDialog.showToast('重置成功');
                        },
                        child: const Text('重置可导出的设置'),
                      ),
                      TextButton(
                        onPressed: () {
                          Get.back();
                          GStorage.userInfo.clear();
                          GStorage.setting.clear();
                          GStorage.localCache.clear();
                          GStorage.video.clear();
                          GStorage.historyWord.clear();
                          GStorage.onlineCache.clear();
                          SmartDialog.showToast('重置成功');
                        },
                        child: const Text('重置所有数据（含登录信息）'),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

class AboutController extends GetxController {
  Box setting = GStorage.setting;
  final SettingController settingController = Get.put(SettingController());
  RxString currentVersion = ''.obs;
  RxInt count = 0.obs;

  @override
  void onInit() {
    super.onInit();
    initialize();
  }

  Future<void> initialize() async {
    await getCurrentApp();
  }

  // 获取当前版本
  Future<void> getCurrentApp() async {
    final currentInfo = await PackageInfo.fromPlatform();
    currentVersion.value = '${currentInfo.version}+${currentInfo.buildNumber}';
  }

  // 跳转github
  Future<bool> githubUrl() {
    return launchUrl(
      Uri.parse(ProjectLinks.repository),
      mode: LaunchMode.externalApplication,
    );
  }

  Future<bool> releaseNotes() {
    return launchUrl(
      Uri.parse(ProjectLinks.releases),
      mode: LaunchMode.externalApplication,
    );
  }

  // 问题反馈
  Future<void> feedback(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (context) {
        return SimpleDialog(
          title: const Text('问题反馈'),
          children: [
            ListTile(
              title: const Text('GitHub Issue'),
              onTap: () => launchUrl(
                Uri.parse(ProjectLinks.issues),
                // 系统自带浏览器打开
                mode: LaunchMode.externalApplication,
              ),
            ),
          ],
        );
      },
    );
  }

  // 日志
  void logs() {
    Get.toNamed('/logs');
  }

  void tapOnVersion() {
    if (settingController.hiddenSettingUnlocked.value) {
      SmartDialog.showToast('您已解锁开发人员选项, 无需再次操作');
      return;
    }
    count.value++;
    if (count.value == 5) {
      setting.put(SettingBoxKey.hiddenSettingUnlocked, true);
      SmartDialog.showToast('恭喜您发现了开发人员选项!');
    }
  }
}
