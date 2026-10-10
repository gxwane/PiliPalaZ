# PiliPalaZ 项目开发规则

## 项目范围

PiliPalaZ 是使用 Flutter 开发的哔哩哔哩非官方第三方客户端。当前公开发行目标为 Android 与 iOS；除非任务明确要求，不要把仓库中的桌面平台目录视为正式发行目标。

- 保留用户已有和无关的工作区改动，不要清理、覆盖或提交它们。
- 保持 Android application ID 与 iOS bundle ID 为 `io.github.gxwane.pilipalaz`。
- 真实依赖地址（包括 `orz12/canvas_danmaku` 与 `orz12/flutter_floating`）不是项目身份文案，不要为了仓库迁移而替换。

## 构建基线

- Flutter 3.38.7
- Dart 3.10.7
- Java 17
- Android Gradle Plugin 8.11.1
- Kotlin Gradle Plugin 2.2.20
- Gradle 8.14
- Android compileSdk/targetSdk 36，minSdk 24

`android/build.gradle` 中使用 `new File()` 设置 `buildDir` 是为了解决 Windows 跨盘符构建问题，不要改回相对路径字符串。Windows 不要求 Pub Cache 与项目同盘；仅当 Kotlin 增量编译因 `different roots` 导致构建失败或频繁回退时，才将本地 `PUB_CACHE` 调整到项目所在盘符。具体绝对路径属于个人环境配置，不应写入仓库或 GitHub Actions。

## 依赖与文件边界

- 本项目是终端应用，必须提交 `pubspec.lock`。新增或升级依赖时，应同时提交有意产生的 lockfile 变化。
- 依赖解析优先使用锁文件：`flutter pub get --enforce-lockfile`。
- 不要提交 `docs/` 中的 brainstorming、spec、plan 等过程文档；README、CHANGELOG 和正式项目文档按任务需要正常维护。
- 不要提交签名文件、密钥、令牌、本地缓存或构建产物。

## 实施与验证

- 修改行为或修复缺陷时，应补充能够覆盖关键边界的测试。
- 只格式化本次修改涉及的 Dart 文件，避免产生无关格式化改动。
- 完成改动后至少运行：

```powershell
flutter test --no-pub
flutter analyze --no-pub --fatal-warnings --no-fatal-infos
flutter build apk --debug --no-pub
```

- 调试 APK 输出路径为 `build\app\outputs\flutter-apk\app-debug.apk`。
- 推送 `main` 后必须等待 GitHub Actions 的 Validation 工作流全部通过，才能宣称云端验证成功。

### 平板与大屏设备独立质检规范

当改动涉及响应式断点（sw600dp / 900dp）、双栏布局（`_buildDualColumnLayout`）、播放器视高钳制（62%）、软键盘单侧隔离避让、大屏手势防误触（80dp 下拉放大）或横竖屏状态机时，应指派独立 QA Agent 在平板视口下执行端到端黑盒实测：
- **设备资产与降级阶梯**：
  1. **物理平板设备**（`shortestSide >= 600dp`）；
  2. **本地配置的平板 AVD 模拟器**：`PiliPalaTabletDev`（Google Pixel Tablet，2560x1600 @ 320dpi）；
  3. **物理手机 ADB 动态拟真**：`adb shell wm size 2560x1600` 与 `adb shell wm density 280`。测试退出时（无论正常或异常）**必须执行强保障 Teardown 重置**：`adb shell wm size reset && adb shell wm density reset`。
- **核心业务验收指标**：
  - 大屏双栏排版对齐正常（左栏 ~62% : 右栏 ~38%），零 `RenderFlex overflow` 溢出；
  - 右栏唤起软键盘输入时，左栏播放器零抖动、零形变，右栏保留可用滚动区；
  - 极端画幅（2.40:1 宽银幕 / 4:3）播放器高度严格钳制在视高 62% 内，下方简介与选集完整可见；
  - 大屏下拉全屏手势严格遵循 80dp 门槛；全屏返回时保持大屏双栏，杜绝误转竖屏。
- 质检截图统一存放于临时目录（如 `qa_screenshots/`），严禁提交至版本库。

## 版本与发行

- 尚未发布的用户可见变更记录在根目录 `CHANGELOG.md` 的 `[Unreleased]` 下。
- 准备发行时，同时更新 `pubspec.yaml` 版本号，并将 `[Unreleased]` 内容固化为带日期的版本章节。
- Tag 必须为 `v<pubspec version>`；构建元数据不进入 Tag，例如 `1.2.3+123456` 对应 `v1.2.3`。
- Release 工作流从 `CHANGELOG.md` 提取中文发行说明，不使用自动生成的提交列表。
- 发布前必须完成人工测试。未经用户明确确认人工测试通过，不要创建或推送正式 Tag。
- Tag 推送后由 GitHub Actions 构建 Android 分架构/通用 APK 和未签名 iOS IPA，并创建 GitHub Release。
