# 更新日志

本文件记录 PiliPalaZ 的公开版本变化。版本号遵循[语义化版本](https://semver.org/lang/zh-CN/)，尚未发布的变更统一记录在 `[Unreleased]`。

## [Unreleased]

### 新增

- 播放器进度条与播控交互深度适配视频分章分节（ViewPoints / 章节标记）完整交互体系：
  - 接入 B 站视频分段元数据接口（`view_points`），智能解析视频分段起止时间、章节标题与看点缩略图；
  - 进度条（`ProgressBar`）适配分段绘制：支持配置切分点列表（`chapterPoints`）与分段物理间隙（`chapterGapWidth`），对底色轨、缓冲轨与进度填充轨实现独立分节与圆角自适应绘制，无章节视频平滑保持连续；
  - 底栏控件新增「看点/章节」按钮（`BottomControlType.chapter`），随视频分段状态动态挂载或溢出至更多菜单；
  - 打造 Material 3 沉浸式看点列表抽屉（`ChapterBottomSheet`）：展示章节封面大纲、起止时间区间与播放中高亮标记，支持点选即时跳章定位；
  - 交互手感与微动效打磨：拖拽进度条跨越章节边界时触发细微触觉震动反馈（`HapticFeedback.selectionClick`），手势寻道 HUD 居中联动显示目标分段标题与大纲封面卡片；
  - 净化收起态微型进度条与竖屏底栏布局，杜绝控件挤压溢出，保证各终端最佳视觉观感；
  - 打造全屏与横屏沉浸态右侧看点面板（`FullScreenChapterPanel`）：在全屏/横屏模式下自适应分发右侧半透明滑出式看点面板，左侧覆盖暗色遮罩并彻底阻断触摸穿透；支持点选章节即刻 Seek 定位并自动收起（Auto-dismiss）、向右侧滑手势（Swipe to Dismiss）平滑退出，以及旋转切回竖屏自动销毁防御。
- 评论区时间戳与播放器深度联动（Timestamp Deep-link & Seek）：
  - 提取高内聚纯函数解析与统一寻道服务（`ReplyTimestampParser`），彻底废除原逻辑对 `Get.arguments['heroTag']` 的脆弱依赖，彻底解决外部直达、推荐流跳转及二级评论中点击时间戳抛出“跳转失败”的缺陷；
  - 强化时间戳匹配与防护：支持 `mm:ss`、`m:ss`、`hh:mm:ss`、`h:mm:ss` 以及中文全角冒号 `：`，引入前后负向断言严密隔离 URL 端口（如 `:8080`）与非法多段连缀冒号；
  - 增强寻道交互闭环：点击时间戳精准定位并自动起播（解除暂停态），伴随轻微触感震动反馈（`selectionClick`），智能识别并弹出章节感知 Toast（如 `跳转至 11:10 · 结尾`）；
  - 二级回复抽屉（楼中楼）深度联动：在二级评论面板内点击时间戳后毫秒级自动关闭收起抽屉，让用户视口无缝平滑回归视频播放器；
  - 完善手势竞技防护与总时长边界拦截，超出视频时长的非法时间戳友好拦截并提示。
- 进度条磁吸吸附（Snap-to-chapter）与手势震动打磨：
  - 打造高内聚数学物理吸附协调器（`ChapterSnapCoordinator`）：基于视宽自适应计算抓取距离（$D_{\text{snap}} = \text{clamp}(W \times 0.015, 10.0, 15.0)\,\text{dp}$），引入施密特触发器（Schmitt Trigger）逃逸滞后模型（$D_{\text{escape}} = 1.5 \times D_{\text{snap}}$），彻底杜绝临界区抖颤；
  - 拟物弹性阻尼与脱吸手感：在吸附捕获区与逃逸区之间提供柔和的弹性拉扯张力（Elastic Tension），超出阈值后瞬时平滑脱吸；支持高速度挥动跳过（Velocity Bypass）；
  - 120Hz 高刷 Zero-GC 优化：在进度条渲染对象（`_RenderProgressBar`）中对清洗后章节断点进行不可变缓存预计算，仅在属性变更与重新布局时失效，根除拖拽寻道时的微内存分配与 GC 抖动；
  - 多感官微动效反馈：滑块吸附瞬间触发轻脆微触觉反馈（`selectionClick`）并配备 120ms 防蜂鸣限频；吸附状态下滑块半径放大 1.25 倍并呈现 1.3 倍半径 Halo 外层柔光晕；
  - 屏幕横向滑动手势寻道（Screen Gesture Seek）跨越章节分段边界时即时联动轻微触觉反馈与 HUD 章节封面卡片高亮。
- 播放器长按动态高倍速（Press-to-Fast-Forward）与动效触觉微反馈：
  - 打造极简高质感毛玻璃胶囊指示器（`FastForwardIndicator`）：采用高斯模糊（`BackdropFilter`）、微亮描边与悬浮投影设计，结合正弦波相位差双箭头流光波浪推进微动效与极简倍速数值（如 `>> 2.0X`），去繁从简、零文字冗余，彻底取代旧版单调的静态浮动文本框；
  - 120Hz 高刷 Zero-Jank 架构隔离：指示器内置 `RepaintBoundary` 图层隔离，手势退场后彻底关闭 Ticker 并收敛为 `SizedBox.shrink()`，保证超高帧率下视频解码与界面渲染零卡顿；
  - 视口形态自适应与安全区规避：外层结合 `SafeArea(top: true)` 与 `LayoutBuilder` 避让防线，自适应竖屏、横屏全屏与打孔屏，并在迷你小窗/画中画等矮视口（$< 160\,\text{dp}$）中智能避让隐藏；
  - 严密状态机守卫与自愈防线：仅在视频处于播放中（`PlayerStatus.playing`）且控件未锁定、非直播模式下响应长按；补齐 `onLongPressCancel` 手势取消监听，彻底根除系统手势中断、通知栏下拉或来电打断造成的“永久高倍速锁死”问题；
  - 异步竞态防御与平滑还原：引入单调自增 `_speedSessionToken`，杜绝急速连续点按产生的平台通道时序竞争与定时器复活；长按结束后 100% 精确还原用户先前的基准播放倍速（如 1.25x 或 1.5x）；
  - 累进加速硬件保护与多层次触觉反馈：将自动递增倍速上限收敛钳制为 4.0x，防范移动端硬解码器掉帧与音频缓冲区溢出；长按起速触发 `selectionClick`、松手回弹触发 `lightImpact`、封顶触发 `mediumImpact`，提供层次丰富的细腻触感。
- 普通视频详情页（VideoDetailPage）大屏/平板横屏双栏与响应式重构（Tablet & Responsive Dual-Column Excellence）：
  - 打造高内聚大屏几何与约束协调器（`VideoDetailLayoutCoordinator`）：设立 640dp 物理宽度门槛，低于门槛或分屏塌陷时自适应平滑降级；实现黄金分割比例切分（左栏 ~62%，右栏 Expanded）与播放器 16:9 视高安全钳制（`maxHeight * 0.62`），确保大屏下播放器下方简介与选集卡片拥有充裕视口；
  - 架构重构与单一 Scaffold 容器：彻底废除原系统针对全屏、平板双栏、近方屏与竖屏分散实例化的 4 个独立 Scaffold 反模式，收敛为根节点唯一的单一 Scaffold 容器，彻底消除设备旋转、分屏尺寸拉伸时的组件重建闪烁、白屏跳动与状态丢失；
  - 软键盘单侧消费与 Inset 隔离（SPEC-02）：根 Scaffold 启用 `resizeToAvoidBottomInset: false`，杜绝软键盘弹起时挤压左侧播放器引发的变形与 `RenderFlex overflow`；右栏通过 `clampedKeyboardHeight` 动态预留至少 120dp 视口高度，并通过 `MediaQuery.removeViewInsets(removeBottom: true)` 彻底切断内层组件二次 Inset 重复消费；
  - 根 PopScope 导航防死锁与画中画联动（SPEC-03）：将返回监听提升至根节点，`didPop == false` 时仅精准消费全屏退出与手机横屏旋转，杜绝深层 child PopScopes 递归导致的无限死锁；平板横屏模式放行返回事件并平滑联动画中画小窗；
  - 平板大屏横屏观影与交互净化（SPEC-05）：修复 `HeaderControl` 顶栏返回键在平板横屏下误触强制转竖屏的缺陷；在双栏模式下移除左栏下划全屏（`pullToFullScreen`）手势包装，杜绝大屏滑动浏览简介时的误触全屏。
- 番剧/影视详情页（PGC VideoDetail）与电影观影模式大屏适配（Cinema Viewport & FullScreenEpisodePanel）：
  - 打造电影级宽银幕动态视口引擎（Cinema Viewport Engine）：在 `VideoDetailLayoutCoordinator` 中实现动态宽高比计算，精准自适应 16:9、21:9、2.35:1 与 2.39:1 电影宽银幕视频，并将极限比例安全钳制在 4:3 至 2.40 黄金区间；根据真实流媒体宽高比动态缩放播放器高度，从根源消除宽银幕电影在大屏双栏下的无效黑场与留白；
  - PGC 大屏双栏动态 Tab 架构：在双栏模式下智能感知内容形态（`sourceType.isPgc`），将右栏 Tab 动态切换为【剧集选集】与【评论交流】，彻底解决番剧/影视选集被硬塞在左栏狭窄区域内的痛点；
  - 打造独立大屏双栏剧集目录组件（`BangumiEpisodeCatalog`）：支持多季/PV/花絮横向滑动 Chip 筛选，以网格与卡片形态优雅呈现全话列表，并集成正在播放实时高亮与初始自动定位居中滚动；
  - 参数解耦与生命周期安全防线：重构 `BangumiPanel`、`BangumiInfo` 与 `BangumiIntroController`，显式传递 `heroTag` 与控制器实例，彻底消除空参外部调用与 Scheme 直达时的 `TypeError` 崩溃风险；并在控制器与面板 `dispose` 时可靠取消 `StreamSubscription`，根绝内存泄漏；
  - 打造全屏与横屏沉浸态右侧选集面板（`FullScreenEpisodePanel`）：在全屏/横屏模式下点击选集按钮时自适应滑出右侧半透明选集抽屉，左侧覆盖暗色遮罩；全面兼容 UGC 分 P、合集、番剧选集以及统一播放队列（`PlayQueueItem`），支持正在播放指示器、大会员权益拦截、右滑手势退场与竖屏自我销毁；
  - 播放队列弹窗防抖加固：为 `PlayQueueBottomSheet.show` 增加 `_isShowing` 单例守卫，杜绝快速连续点击造成的弹窗多层叠加与文字重叠渲染。

## [1.5.0] - 2026-10-05

### 新增

- 直播功能完整体系构建（Live Streaming Suite）：
  - 直播间大屏与平板横屏左右双栏交互（`LiveRoomPage`）：
    - 建立五元正交状态机（`isFullScreen`、`isLandscape`、`isTablet`、`isSquarish`、`isDualColumn`），精准界定显式全屏、大屏横屏双栏、手机横屏沉浸、折叠屏近方屏与手机竖屏单栏形态，杜绝折叠屏展开态误入沉浸态；
    - 落地平板与大屏左右双栏布局：左栏（65% 视宽）集成微型返回栏、16:9 动态安全钳位播放器与主播卡片；右栏（35% 视宽）自适应承载 SC 留言横幅、公屏聊天流与发送栏；
    - 双栏模式下单侧消费软键盘高度，彻底根除唤起输入法时左栏播放器高度压缩引发的 `RenderFlex overflow` 崩溃；
    - 顶层统一调度 `PopScope`，平板双栏与竖屏单栏放行系统返回键，全屏模式退全屏，根除大屏返回键死锁与误退房间问题。
  - 直播画中画（PiP）自适应比例与沉浸式体验：
    - 引入基于最大公约数（GCD）的宽高比化简与 Android 原生极限比率 `[100/239, 239/100]` 安全钳制，彻底根治特殊或竖屏流宽高比越界引发的系统级崩溃；
    - 播放器内核尺寸响应流（`onDimensionChanged`）与自动画中画配置热联动，纯音频模式下自动挂起后台画中画；
    - 画中画独立渲染面板接入无弹幕偏好（`SettingBoxKey.pipNoDanmaku`），全屏与横屏沉浸态统一。
  - 直播后台播放、锁屏纯音频（听直播）与系统播控：
    - 媒体通知与播控扩展（`VideoPlayerServiceHandler`）：将直播房间号、标题、主播名及封面无缝同步至系统通知中心，精简直播态播控按钮仅保留播放/暂停与停止；
    - 单活动纯音频占位卡片（`LiveAudioOnlyCard`）：听直播模式下从组件树中完全卸载底层视频原生 Texture，消除 GPU 光栅化渲染与发热，仅保留底层音频输出并释放屏幕常亮锁（Wakelock），支持正常息屏待机省电；
    - 纯音频卡片融入高斯模糊封面背景、主播头像脉冲声波呼吸动效、一键恢复画面与底栏耳机快捷入口；切房代际校验防串房。
  - 直播广场与发现页重构：
    - 引入“我的关注正在直播”横向滑动吸顶栏（`LiveFollowBar`），支持红环动效与专属 LIVE 徽标；
    - 引入官方直播大分区吸顶胶囊选择栏（`LiveAreaHeader`），支持全分区平滑横向滚动与选中态高亮；
    - 建立分区切换原子状态机，自增代际序列号与 Dio 取消令牌彻底防御快速切区时的 ABA 乱序回包；
    - 进房透传 `parentAreaId` 分区上下文，实现分区卡片进房后上下滑屏切房持续在同分区内翻阅。
  - 直播间垂直手势上下滑屏快速切房与无缝切流：
    - 建立“单活动播放器槽位架构”，全局仅对激活页挂载底层播放器，非激活项使用轻量预览卡片，零原生 Texture 冲突；
    - 实施“静止停稳提交策略（Commit-on-Settle）”，手势中途回弹保持原流不断流；
    - 切房自增代际校验掐断在途请求，消除并发乱序回包与重复 WebSocket 握手。
  - 直播间互动聊天室与信息架构重构（标杆模式）：
    - 彻底废除三 Tab 布局，下半屏升级为全高沉浸式公屏互动流，竖屏视高增加 25%；
    - 播放器正下方常驻紧凑主播栏（`LiveAnchorStrip`），聚合主播信息、一键关注与半屏主播公告抽屉；
    - 公屏顶部动态置顶 SC 横幅（`LiveScTicker`）与全量醒目留言抽屉（`LiveScSheet`）；
    - 120ms 时间窗口消息合批（Batch Flush）与 200 条最大容量 FIFO 队列截断，杜绝刷屏卡顿与内存泄漏；
    - 倒序贴底渲染与双向未读计数气泡；实现弹幕发送栏（`LiveInputBar`），支持防刷屏冷却。
  - 直播多清晰度/画质与多 CDN 线路平滑切换：
    - 支持直播默认画质本地持久化偏好（`SettingBoxKey.defaultLiveQa`）；
    - 基于流编解码实际支持能力的画质交集过滤与降序算法，彻底剔除不支持的伪选项；
    - 支持多清晰度（原画/蓝光/超清/高清/流畅）、多 CDN 线路与编解码器（AVC/HEVC）状态管理与平滑切换。
  - 直播弹幕长连 WebSocket 引擎与飘屏：
    - 基于 `dart:io` 原生实现 16 字节头部编解码器与 zlib 原生解压引擎，零额外三方 FFI 依赖；
    - 建立独立长连引擎，支持 Comet 动态节点认证、周期心跳与指数退避重连；挂载 `canvas_danmaku` 弹幕引擎实现丝滑飘屏。
- Android Media3 原生播放内核全面落地（Player Engine Evolution）：
  - 抽离统一播放器抽象契约 `IPlayerEngine`，抹平底层播放引擎差异，建立统一媒体源与状态数据结构；
  - Android 平台全面确立 Media3 (ExoPlayer 1.5.1) 为生产环境默认播放内核，原生支持 B 站 DASH 音视频双流直出（`MergingMediaSource`）与精确剪裁，桌面平台平稳保持 MPV 内核；
  - 改用 Flutter 原生 `createSurfaceTexture()` 提供 64 缓冲槽 `BufferQueueCore`，彻底根除海思麒麟等芯片硬件解码器启动失败与绿屏卡死问题；
  - 完善 Surface 纹理销毁时序，杜绝多线程销毁引发的管道破裂（Broken Pipe）；
  - 保留 MPV 作为容灾备用，支持在设置中手动切换以及原生层初始化异常时的自动无感降级；
  - 全面重构并升级「播放信息」统计与排障诊断面板（Stats for Nerds），统一提取播放内核、渲染管线、视音频流规格、缓冲健康度与网络节点，支持一键导出 Markdown 排障数据。
- 单轨融合主音量与音量均衡（Volume Architecture & Loudness Normalization）：
  - 引入「音量均衡（响度对齐）」功能：基于 B 站 EBU R128 音频元数据自动计算增益补偿，衰减优先与真峰值防削波保护，并在离线缓存中同步持久化响度元数据；
  - 引入「单轨融合主音量（1% 物理真细粒度调节）」架构：以系统 15 级阶梯为骨架，底层播放引擎微增益插值，实现 1% 连续变化的物理声压输出；
  - 非对称硬件调度策略与 Token 状态机（EchoGuard），彻底消除系统广播回弹误判；绝对位移映射与动态虚拟锚点算法实现 120fps 满帧跟手手势；
  - 重构系统音频打断（Audio Ducking）逻辑，基于独立幂等衰减因子，杜绝状态漂移。
- UGC 视频多分卷合集（UGC Season Sections）交互与架构重构：
  - 详情页主屏收敛为紧凑卡片，清晰呈现当前合集名称、当前分卷与实时播放序号；
  - 引入专属选集抽屉（`SeasonListSheet`），支持顶部分卷选择器一键平滑切换与多维智能定位（按 cid / page.cid / bvid）。
- 机器自动化架构守卫测试体系：
  - 建立全自动化 AST 架构测试套件（`test/architecture/`），在 CI 门禁中机械拦截局部变量遮蔽、控制器非法 `late` 及裸吞异常；
  - 激活严格静态代码分析规则（`unnecessary_late`、`cancel_subscriptions`、`close_sinks` 等）。

### 优化

- 直播大分区栏右侧内联微型排序入口：
  - 移除独立占行组件，消除累积位移（CLS）跳跃，大分区栏高度恒定锁定为 38px；
  - 支持热门排行（`online`）与最新开播（`live_time`）双排序，结合切房上下文透传；
  - 优化静默刷新心智，比对房间序列精准派发反馈 Toast。
- 播放器滑动手势与交互打磨：
  - 引入人体工程学自适应行程计算，解决大屏/平板滑动音量行程过长问题；
  - 增加手势边缘防误触保护，智能避让顶部系统通知栏、底部全面屏手势条与两翼侧滑返回；
  - 提供音量滑动手势灵敏度调节与防误触偏好开关。
- 历史记录管理与删除链路加固：
  - 统一历史记录资源标识前缀解析，全面覆盖视频、直播、专栏与番剧/影视；
  - 重构为 5 路并发分块请求与原子视图刷新，大幅缩减批量清理耗时并杜绝重绘抖动。
- 代码库规范化与现代化 API 迁移：
  - 全量迁移工程内弃用的 `Color.withOpacity` 至推荐的 `Color.withValues(alpha: ...)`；
  - 加固播放器内核与核心服务的顶层类型注解与泛型语法。

### 修复

- 修复直播间横屏、全屏与沉浸式黑屏及 0x0 塌陷缺陷，跨模态无损复用视频纹理；
- 修复平板设备在横屏常规状态下的返回键吞噬与退出死锁；
- 修复搜索直播间点击崩溃与多态模型解析隐患；
- 修复用户个人空间开播状态下点击主头像无响应问题，加固开播动画与反序列化容错；
- 修复直播广场关注主播开播状态误判缺陷，实施严格开播过滤；
- 修复播放器播放/暂停按钮状态不同步、播放期间意外熄屏及多路由跳转返回黑屏缺陷；
- 修复切换视频与换集时音量 HUD 异常弹出，以及 MPV 内核下音量设置严重失真的量纲映射缺陷；
- 修复全屏放大视频、竖屏全屏以及手机旋转至横屏时播放器顶栏与底栏的布局溢出缺陷；
- 修复直播模块生命周期治理、防单例播放器后台“幽灵播放”与退房内存泄漏。

## [1.5.0-beta.6] - 2026-10-02

### 优化

- 直播间横屏与全屏概念彻底解耦，支持大屏/平板横屏左右双栏交互（`LiveRoomPage`）：
  - 建立五元正交状态机（`isFullScreen`、`isLandscape`、`isTablet`、`isSquarish`、`isDualColumn`）：
    - 废除原有一刀切的 `isImmersive = isFullScreen || isLandscape` 逻辑，精准界定显式全屏、大屏横屏双栏、手机横屏沉浸、折叠屏近方屏与手机竖屏单栏形态；
    - 引入 `!isSquarish && !isTablet` 防守链，杜绝折叠屏展开态（8:7 / 4:3 等比例）因宽大于高被误杀进入横屏沉浸态的缺陷；
  - 落地平板与大屏横屏左右双栏架构（`_buildDualColumnLayout`）：
    - 左栏（65% 视宽）：集成微型返回栏、16:9 动态安全钳位播放器容器与 `LiveAnchorStrip` 主播卡片；
    - 右栏（35% 视宽）：自适应承载 `LiveScTicker`、`LiveChatPanel` 公屏聊天流与 `LiveInputBar` 发送栏；
    - 键盘防溢出架构：双栏模式下关闭全局 Scaffold `resizeToAvoidBottomInset`，由右栏单侧消费键盘避让高度，彻底根除唤起输入法时左栏播放器因高度压缩引发的 `RenderFlex overflow` 崩溃；
  - 导航与拦截架构治理：
    - 将 `PopScope` 从播放器容器深处抽离至 `_buildActiveRoomView` 顶层统一调度，播放器容器恢复纯粹视窗职责；
    - 平板双栏与竖屏单栏模式下放行返回键（`canPop = true`），全屏模式退全屏，手机横转退竖屏，根除大屏返回键死锁与误退房间问题；
  - 自动化测试与质量守卫（`test/live/live_room_landscape_test.dart`）：
    - 覆盖五元状态机多端真值表断言、350dp 虚拟键盘激进溢出压测与生产代码防劣化契约守卫，变异消灭率 100%。

## [1.5.0-beta.5] - 2026-10-02

### 新增

- 直播画中画（PiP）自适应比例、纯音频互斥与沉浸式体验优化：
  - 画中画极限宽高比安全钳制（`VideoUtils.clampPiPRational`）：
    - 引入基于最大公约数（GCD）的宽高比化简与 Android 系统原生极限比率 `[100/239, 239/100]` 安全钳制，彻底根治特殊或竖屏流宽高比越界引发系统 `IllegalArgumentException` 导致 PiP 崩溃的隐患；
  - 播放器内核尺寸响应流与设置热联动（`PlPlayerController` & `PlaySetting`）：
    - 暴露响应式 `videoDimension` 状态与 `onDimensionChanged` 流，实时捕获底层多媒体内核视频流宽高变化；
    - 自动画中画配置接入动态宽高比计算；联动 `_onlyPlayAudio` 状态，纯音频模式下自动挂起后台画中画；
    - 播放设置页切换自动画中画时即时触发 `PlPlayerController.updateSettingsIfExist()` 热生效；
  - 直播流横竖屏方向自适应与生命周期互斥（`LiveRoomController`）：
    - 接入流尺寸监听并实时同步 `direction.value`（高大于宽判定为 vertical），自适应竖屏直播；
    - 切换听直播模式与房间销毁注销时安全停用后台画中画（`_safeDisableBackgroundPiP`），避免音画混淆与后台资源泄漏；
  - 画中画无弹幕选项与横竖屏沉浸式布局（`LiveRoomPage` & `BottomControl`）：
    - 画中画独立渲染面板接入 `SettingBoxKey.pipNoDanmaku` 开关判定，并隐去多余底栏控制项；
    - 统一全屏与横屏沉浸态（`isImmersive`），优化返回拦截 `PopScope` 与全屏退出手势；
    - 底栏手动画中画按钮使用安全比例并补充开启异常 Toast 提示，全屏切换按钮接入响应式状态监听；
  - 自动化测试套件（`test/live/live_pip_orientation_test.dart`）：
    - 10 项端到端单元与 Widget 测试覆盖宽高比化简与极限钳制、内核尺寸响应流、横竖屏流判断及沉浸式 PopScope 返回栈拦截。

- 直播后台播放、锁屏纯音频（听直播）与系统播控：
  - 系统媒体通知与播控扩展（`VideoPlayerServiceHandler`）：
    - 引入 `isLiveStream` 状态标识与 `onLiveDetailChange` 元数据注入，将直播房间号、标题、主播名及封面无缝同步至系统通知中心；
    - 精简直播态播控按钮（`_buildMediaControls`）：彻底剔除快进、快退、进度条拖拽与切集等对直播无效的控制项，仅保留播放/暂停与停止按钮，系统通知紧凑动作锁定为播放/暂停；
    - 状态机闭环防污染治理：在点播元数据同步（`onVideoDetailChange`）、停止（`stop`）与清理（`clearImpl`）中确定性重置 `isLiveStream = false`，彻底消除直播流污染普通点播视频播控的隐患；
  - 纯音频（听直播）模式与功耗优化（`LiveRoomController` & `LiveAudioOnlyCard`）：
    - 控制器新增 `isAudioOnly` 响应式状态与 `toggleAudioOnly` 原子切换方法，联动 `PlPlayerController.setOnlyPlayAudio` 释放系统屏幕常亮唤醒锁（Wakelock），支持听直播时正常息屏待机省电；
    - 创立单活动纯音频占位卡片（`LiveAudioOnlyCard`）：听直播模式下从组件树中完全卸载底层视频 `PLVideoPlayer` 原生 Texture，消除 GPU 光栅化渲染与发热，仅保留底层音频管线持续输出；
    - 听直播卡片融入高斯模糊封面背景、主播头像脉冲声波呼吸动效、模式状态胶囊、一键“恢复画面”胶囊按钮及全屏退出按钮；
    - 控制栏快捷入口接入（`BottomControl`）：底栏画质选择旁增设耳机快捷图标按钮，响应式联动主题色与实时状态；
  - 切房与销毁生命周期联动治理：
    - 切房时引入 `_switchGeneration` 代际校验同步更新系统通知元数据，杜绝并发网络乱序导致的串房污染；
    - 房间销毁与切房复位时确定性释放系统媒体通知，保持纯净状态；
  - 自动化测试套件（`test/live/live_audio_mode_test.dart`）：
    - 9 项端到端单元与组件测试覆盖直播 MediaItem 构造、controls 精简过滤、点播状态重置、Wakelock 联动、切房代际防串与 `LiveAudioOnlyCard` 交互渲染。

- 直播分区排序增强与刷新交互心智对齐：
  - 接口层扩展（`LiveHttp.areaLiveList`）：支持 `sort_type`（`online` 热门排行 / `live_time` 最新开播）参数；
  - 直播大分区栏右侧内联微型排序入口（方案 A 架构重构）：
    - 彻底移除废弃的独立占行组件（`LiveSortBar`），消灭主视口无谓的 `SliverToBoxAdapter`，立省 38px 宝贵垂直空间，大幅提升首屏内容曝光率；
    - 彻底根除从推荐切入分区时下方卡片流突发下推 38px 的累积位移（CLS）跳跃，大分区栏高度恒定锁定为 38px；
    - 并轨重构 `LiveAreaHeader`：采用 `Row` 架构将横向滚动大分区与右侧微型排序入口（`PopupMenuButton`）一体化整合，辅以 14px 细分割线；
    - 彻底肃清系统 Emoji 与说明型冗余标签，对齐 Material 3 纯净文字与矢量下三角/勾选图标规范，支持文字等比缩放防溢出；
  - 控制器状态机与并发防竞态治理（`LiveController`）：
    - 实现 `switchSortType` 原子切换，具备当前状态短路守卫与在途网络取消续期，配合自增代际序列号（`_feedGeneration`）彻底消除 ABA 乱序回包；
    - 切换大分区时自动重置排序策略为默认的 `online`（热门），确保符合直觉的用户体验；
  - 解决静默刷新心智冲突的即时反馈机制：
    - 在下拉刷新时比对刷新前后房间 ID 切片序列，非推荐分区下根据变动情况精准派发反馈 Toast（“已是最新直播排行”、“已更新直播排行”、“当前暂无新主播开播”等），彻底消除用户对静态排行榜刷新的困惑；
    - 防御性 Toast 封装（`_showToast`）：集成测试环境无 UI 上下文静默容灾与 `@visibleForTesting toastHandler` 拦截钩子；
  - 切房上下文完整联动（`LiveRoomPlaylistManager` & `LiveCardV`）：在卡片进房与滑动切房边界预拉取时全程透传 `sortType`，确保滑屏切房与当前排序策略严密一致；
  - 单元与组件测试用例全面扩充（`test/live/live_feed_test.dart`）：覆盖排序切换、大区重置、有序刷新变动判定与 `LiveAreaHeader` 内联菜单交互测试。

- 直播广场与发现页重构（Phase 5）：
  - 引入“我的关注正在直播”横向滑动吸顶栏（`LiveFollowBar`），支持红环动效与专属 LIVE 发光徽标，展示主播头像与昵称，点击直达对应直播间；未登录或无开播时自适应收缩为零像素；
  - 引入官方直播大分区吸顶胶囊选择栏（`LiveAreaHeader`），包含推荐、网游、手游、单机游戏、娱乐、电台、虚拟主播、生活等官方分区，支持平滑横向滚动与选中态高亮动效；
  - 建立分区切换原子状态机（`LiveController.switchArea`）：实施自增代际序列号（`_feedGeneration`）与 Dio 取消令牌（`_feedCancelToken`），彻底防御快速切区时的 ABA 乱序回包与网络请求风暴；
  - 优化切区过渡体验：切区瞬间进入轻量骨架屏（Shimmer Skeleton）过渡，网络异常静默容灾；
  - 修正切房上下文契约（`LiveRoomPlaylistManager`）：透传 `parentAreaId` 分区上下文，实现从分区卡片进房后，上下滑屏切房持续在同分区内翻阅，彻底消除“分区模式切房突变全局推荐”的断裂感；
  - 手势竞争与渲染性能治理：外层 `RefreshIndicator` 配置 `depth == 0`，根除横向滑屏误触纵向下拉刷新的手势冲突；横向栏使用 `RepaintBoundary` 隔绝局部重绘；`CustomScrollView` 优化预加载缓冲区（`cacheExtent: 1200`）；
  - 数据模型别名鲁棒化（`LiveItemModel.fromJson`）：支持 `room_id`/`roomid`、`avatar`/`face`、`keyframe`/`cover`、`parent_area_id`/`parent_id` 等多接口别名降级，彻底清除 UI 组件中的强制解包断言 `!`（Zero-Crash）；
  - 新增 `test/live/live_feed_test.dart` 自动化测试套件（10 项单元与 Widget 测试，覆盖模型别名容错、零崩溃渲染、状态机代际切换与手势安全）。

- 直播间垂直手势上下滑屏快速切房与无缝切流（Phase 4B）：
  - 建立双模式进入策略（`LiveRoomPlaylistManager`）：推荐流卡片直入携带全量列表上下文与索引，单房/深度链接直入自动后台异步增补推荐候选池；
  - 创立“单活动播放器槽位架构（Single Active Player Slot）”：严格遵守全局单例播放器约束，仅对激活页挂载底层播放器，非激活项使用轻量预览卡片（`LiveRoomPreviewCard`）与自适应骨架屏，零原生 Texture 冲突与白屏；
  - 实施“静止停稳提交策略（Commit-on-Settle）”：监听垂直滚动完全停稳并判定 `(page - round).abs() < 0.001` 后才触发切房，手势中途回弹 100% 保持原流不断流；
  - 建立切房状态机（`LiveRoomController.switchRoom`）：引入 Dio `CancelToken` 与自增代际序列号（`_switchGeneration`），主动掐断在途网络请求，彻底消除并发乱序回包；
  - 完善手势分层与冲突隔离：横屏与全屏模式下锁闭 `PageView` 滑动手势（`NeverScrollableScrollPhysics`），确保音量/亮度调节无冲突；竖屏下播放器让渡垂直手势；
  - 完善长短房间号解析与 WebSocket 握手幂等守卫，彻底杜绝重复连接风暴；
  - 切房时同步清空弹幕、未读消息与流元数据（`_resetConnectionsAndState`），杜绝状态残留与内存泄漏；
  - 新增 `test/live/live_room_paging_test.dart` 自动化测试套件（9 项端到端及单元测试覆盖）。

- 直播间互动聊天室与信息架构重构（Phase 4A · 标杆模式）：
  - 彻底废除低效的三 Tab 布局，将下半屏完整提升为全高沉浸式公屏互动流，竖屏视高增加 25%；
  - 引入播放器正下方常驻紧凑主播栏（`LiveAnchorStrip`），聚合主播头像、昵称、分区标签、一键关注与公告入口；
  - 补齐主播空间跳转触点闭环（`LiveNavHelper`），支持 AppBar 与主播栏头像/昵称点击平滑进入个人主页（`/member`），并透传 `face` 与 `heroTag`；
  - 引入公屏顶部动态置顶 SC 横幅（`LiveScTicker`）与全量醒目留言抽屉（`LiveScSheet`），无 SC 时零像素占用，有 SC 时尊贵高亮展示；
  - 引入半屏主播公告抽屉（`LiveNoticeSheet`），支持一键展开直播间标题、分区与完整公告详情；
  - 公屏聊天流精准识别主播 UID，发言时渲染粉红 `[UP主播]` 专属尊贵徽标与高亮字体；
  - 控制器支持原地关注状态切换（`isFollowed`）与防抖鉴权；
  - 采用 120ms 时间窗口消息合批（Batch Flush）机制与 200 条最大容量 FIFO 队列截断，杜绝高频刷屏卡顿与挂机 OOM；
  - 互动聊天流重构为 `ListView.builder(reverse: true)` 倒序贴底渲染，配合双向迟滞（>30/<=10）未读计数与悬浮气泡；
  - 实现直播弹幕发送栏（`LiveInputBar`），支持 CSRF 校验、3 秒冷却倒计时防刷屏与软键盘呼起自适应；
  - 新增 `test/live/live_anchor_strip_test.dart` 与 `test/live/live_chat_room_test.dart` 自动化测试套件（通过全部 10 项 Tier 3 质量门禁）。

- 直播多清晰度/画质与多 CDN 线路平滑切换支持（Phase 3）：
  - 新增 `SettingBoxKey.defaultLiveQa` 设置项，支持直播默认画质本地持久化偏好；
  - 实现 `VideoUtils.getLiveCdnUrl` 安全多线路流地址拼接，增加线路索引越界 Clamp 保护与非空防御；
  - 建立基于流编解码实际支持能力（`accept_qn`）的画质交集过滤与降序算法（`VideoUtils.filterAndSortQualities`），彻底剔除 B 站全局字典中直播间不支持的 4K/杜比等伪选项；
  - 支持编码切换时的画质联动与平滑降级（`VideoUtils.resolveSupportedQn`），并在发生画质降级时精准重发权威网络拉流，杜绝空流与 403 播放失败；
  - `LiveRoomController` 支持多清晰度（原画/蓝光/超清/高清/流畅）、多 CDN 线路（主线/备线）与编解码器（AVC/HEVC）状态管理与无缝切换；
  - 引入 `isSwitchingStream` 双层并发防重机制与异常降级恢复策略，保障切流过程无死锁、无黑屏崩溃；
  - 底栏集成实时画质胶囊按钮，提供加载状态指示与自适应横竖屏、全屏与非全屏的 `LiveQualitySheet` 选择抽屉面板；
  - 新增 `test/live/live_quality_selection_test.dart` 单元测试套件（含 6 大 BDD 真实画质能力过滤与降级用例），全面覆盖画质与线路切流逻辑。
- 直播弹幕长连 WebSocket 引擎与基础飘屏（Phase 2）：
  - 接入 B 站官方直播弹幕网关配置 API（`/room/v1/Danmu/getConf`），动态获取 Comet 节点与认证 Token；
  - 基于 `dart:io` 标准库原生实现 16 字节头部编解码器（`LivePacketCodec`）与 `zlib.decode` 原生解压引擎，零额外三方 FFI 依赖；
  - 建立防零步长死循环与网络畸形包截断保护机制，保障高并发粘包数据安全解码；
  - 构建独立长连引擎（`LiveDanmakuClient`），支持 Op 7 认证、30 秒 Op 2 周期心跳与指数退避自动重连；
  - 挂载 `canvas_danmaku` 弹幕引擎至直播播放器，实现实时弹幕丝滑飘屏；
  - 直播控制栏新增弹幕开关切换按钮，支持状态实时联动、算力短路优化与偏好持久化。

### 修复

- 直播间横屏、全屏与沉浸式黑屏及布局尺寸塌陷修复（`LiveRoomPage`）：
  - 根除 RenderStack 0x0 塌陷：引入同构渲染层级（`SizedBox.expand` + `Stack(fit: StackFit.expand)`），并通过 `MediaQuery.sizeOf(context)` 向播放器容器向下传递精确紧约束，彻底根治全屏与横屏沉浸式状态下 0x0 尺寸折叠导致的画面纯黑缺陷；
  - 跨模态无损纹理复用：将播放器容器统一收敛在恒定 `Column` 父级并在外层声明稳定 `GlobalKey`（`_playerContainerKey`），杜绝横竖屏切换时 Element 树解挂与底层原生视频纹理（TextureId）销毁重建，消除切屏掉帧；
  - 杜绝平板设备横屏退出死锁：优化 `PopScope` 拦截判定（`shouldIntercept = isFullScreen || (isLandscape && !ScreenUtils.isTabletDevice())`），解除平板在横屏常规状态下的返回键吞噬，并在回调中追加 `Navigator.maybePop` 安全兜底；
  - 横屏全屏手势与视口对齐防护：横屏模式下同步开启垂直音量与亮度调节手势（`enableVerticalGesture`）；在 `didChangeDependencies` 捕获切回竖屏时，通过后帧安全调度 `jumpToPage` 保持 `PageView` 视口精准锚定当前房间；
  - 自动化测试套件（`test/live/live_room_immersive_test.dart`）：覆盖全屏沉浸与竖屏 16:9 尺寸约束验证、生产代码防塌陷防死锁契约断言及变异消灭测试。

- 搜索直播间点击崩溃与多态模型解析加固：
  - 在 `LiveItemModel` 引入 `LiveItemModel.fromDynamic(dynamic raw)` 领域解构器，平铺 `SearchLiveItemModel` 分词高亮标题为纯净文本，并映射 `roomid`、`cover`、`face`、`areaName`、`online`，支持 Map 与动态对象安全解构；
  - 修复 `LiveRoomPage` 与 `LiveRoomController` 中由 `argMap?['liveItem'] as LiveItemModel?` 强制类型断言引发的运行时 `TypeError` 崩溃；
  - 加固进房列表透传 `liveList` 的流式多态过滤（`rawList.map(LiveItemModel.fromDynamic).whereType<LiveItemModel>().toList()`），杜绝异构模型引发崩溃。
- 用户空间头像开播交互与反序列化容错加固：
  - 修复用户个人空间（`MemberPage`）开播状态下点击 90×90 主头像无任何响应的交互缺失，将手势检测层包裹至完整头像卡片，主播开播时显示 2.5px 主题色动效外环，并精确居中底部的“直播中”呼吸徽标，点击直达对应直播间；
  - 加固 `MemberInfoModel.fromJson` 支持 `live`、`live_room`、`liveRoom` 与 `card.live_room` 多路径服务端字段提取；
  - 加固 `LiveRoom.fromJson` 兼容 `snake_case`（`live_status`、`room_id`）与 `camelCase` 以及字符串数值安全容错，修复个人资料卡 `sign` 与 `vip` 潜在的空安全隐患。
- 直播广场关注主播开播状态误判修复：
  - 修复 `LiveItemModel` 缺失 `live_status` 字段导致的开播状态误判，扩展支持 `int`、`String`、`bool` 以及驼峰别名（`liveStatus` / `is_live`）的鲁棒解析，并提供 `isLive`、`isRoundRobin`、`isOffline` 语义 Getter；
  - 修复 `LiveHttp.followingLiveList` 仅凭 `roomId > 0` 恒真判断导致的离线主播被全量错误打上 LIVE 徽标的缺陷，在网络层与控制器层实施“严格开播过滤（Strictly Live Guard）”（`item.isLive`），并补充 `ignoreRecord: 1, hit_ab: true` 请求参数；
  - 视图层 `LiveFollowBar` 与头像外圈高亮仅在 `item.isLive` 时渲染专属 LIVE 徽标与主色外圈，杜绝已关播主播误显。
- 直播模块稳定性加固与生命周期治理（Phase 1）：
  - 修复 `RoomInfoH5Model` 中 `live_status` 字段键名拼写错误（`liveS_satus`），支持双向兼容反序列化；
  - 加固 `RoomInfoModel` 及其子树反序列化空安全，对未开播、封禁或空流数据进行全面防御，彻底根除强解包导致的 `Bad state: No element` 崩溃；
  - 修复 `VideoUtils.getCdnUrl` 针对直播 `CodecItem` 相对路径拼接与空 URL 导致的崩溃与播放失败；
  - 引入实例唯一 Tag 隔离 `LiveRoomController` 生命周期，退出直播间时彻底销毁释放，杜绝多房间状态串房；
  - 增加异步请求 `isDisposed` 状态守卫，防止快速进出房间导致的单例播放器后台“幽灵播放”；
  - 完善 `LiveRoomPage` 视图层空安全，消除主播头像与昵称强解包空指针风险，并增加主播未开播/无流占位状态；
  - 退出直播间时结合设备类型（非平板）安全复原竖屏方向，修复全屏返回横屏卡死问题；
  - 修复直播广场下拉刷新未重置分页 `_currentPage` 的缺陷，并增加并发加载互斥守卫与滚动监听器解绑防内存泄漏；
  - 清理从未使用的废弃死代码 `live_card.dart`。

## [1.5.0-beta.4] - 2026-09-30

### 优化

- 离线下载支持音量均衡：
  - 离线缓存任务（`DownloadTask`）持久化存储 B 站音频响度元数据，离线播放时无缝恢复响度均衡能力。
- 音频与响度系统边界鲁棒性提升：
  - 增加对服务端响度元数据异常值（NaN / Infinity）的防御性过滤与安全回退；
  - 支持在服务端缺失 `target_offset` 时，自动从 `target_i - measured_i` 逆向推导增益偏置；
  - 修复多集连播或切换视频时，外部音频闪避（Ducking）状态可能残留泄漏到下一集的边界问题。
- 播放器滑动手势与交互打磨：
  - 引入人体工程学自适应行程计算，解决大屏/平板设备（如 Galaxy Tab S7 等）滑动音量行程过长的问题；
  - 增加手势边缘防误触保护，智能避让顶部系统通知栏下拉、底部全面屏手势条与两翼侧滑返回；
  - 在「播放器设置」中新增「音量滑动手势灵敏度」调节（0.75x ~ 1.5x）与「手势边缘防误触保护」偏好开关。
- 历史记录管理与删除链路加固：
  - 统一历史记录资源标识前缀解析（`resolveResourceKid`），全面覆盖普通视频（`archive`）、直播（`live`）、专栏（`article`）与番剧/影视（`pgc`），规避类型拼装缺陷；
  - 历史记录清理与批量删除重构为 5 路并发分块请求与原子视图刷新，大幅缩减批量清理耗时并杜绝列表重绘抖动；
  - 全流程引入 `try ... finally` 确保 Loading 弹窗安全关闭，清理已看记录增加前置空态提示，杜绝界面假死。
- UGC 视频多分卷合集（UGC Season Sections）交互与信息架构重构：
  - 详情页主屏收敛：彻底终结多分卷垂直堆叠霸占视高问题，重构为恒定 1 张紧凑卡片，清晰呈现当前合集名称、当前分卷与实时播放序号；
  - 独立专属选集抽屉（`SeasonListSheet`）：点击合集卡片唤起专属选集抽屉，通过顶部分卷选择器（Horizontal Chips）实现多分卷一键平滑切换，避免污染通用选集组件；
  - 智能动态定位与多层匹配：支持按 `cid`、`page.cid`、`bvid` 多维识别当前播放集，打开抽屉时自动高亮并平滑滚入可视区域；
  - 严密安全防护与健壮性：增加跨分卷切换的列表 Key 隔离与多重越界保护，彻底杜绝 `RangeError: -1` 崩溃；加固反序列化空安全并消除窄屏下抽屉顶栏溢出（RenderFlex overflow）。
- 代码库规范化与现代化 API 迁移：
  - 全量迁移工程内弃用的 `Color.withOpacity` 至 Flutter 3.27+ / 3.38 推荐的 `Color.withValues(alpha: ...)`，避免广色域屏幕下的浮点精度截断与重绘损耗；
  - 加固播放器内核与核心服务（`PlPlayerController`、`AudioHandler`、`EventBus` 等）的顶层类型注解与泛型语法，补全显式返回值与不可变字段；
  - 移除多余的底层渲染引擎导入并清理已落地的滞后 TODO 注释。

## [1.5.0-beta.3] - 2026-09-22

### 新增

- 引入「音量均衡（响度对齐）」功能：
  - 基于 B 站官方 EBU R128 音频元数据（`measured_i`、`target_offset`、`target_tp`），自动计算增益补偿，拉平不同 UP 主视频之间的音量差异；
  - 采用衰减优先（Attenuate-only）策略与真峰值防削波保护，彻底规避音量溢出失真与播放器高音量调节死区；
  - 在「播放设置」中提供开关，并在新视频加载时原子生效，无元数据（如 PGC/直播）自动直通。
- 引入「单轨融合主音量（1% 物理真细粒度调节）」架构：
  - 彻底摒弃脱钩的双音量模型，统一为唯一的主音量轨道（0% ~ 100%），屏幕手势与机身物理按键双向镜像联动；
  - 采用系统 15 级硬件阶梯为骨架，底层播放引擎无级微增益插值（Engine Micro-Gain），真正输出 1% 连续变化的物理声压，彻底解决深夜 1 档（6.7%）太响、0 档又无声的顽疾；
  - 采用非对称硬件调度策略：向下滑动 100% 内存纯数字衰减（0 次 Binder 调用、无爆音无延迟），抬手静默收敛最优阶梯，结合 Token 状态机（EchoGuard）彻底消除系统广播回弹误判；
  - 重构滑动手势为绝对位移映射与动态虚拟锚点算法，彻底根治此前节流器导致的 80% 掉帧与折返死区粘滞感，实现 120fps 满帧跟手。

### 修复

- 修复切换视频与换集时音量 HUD 异常弹出的缺陷：
  - 显式关闭音量监听器建立连接时的初始广播派发（`emitOnStart: false`），并在平台通道异步恢复后增加组件生命周期校验（`mounted guard`）；
  - 引入硬件阶梯差分守卫（Hardware Step Diff Guard），过滤系统音频焦点转移（`abandonAudioFocusRequest`）与通道重置时的同等无变化冗余广播，杜绝 HUD 误唤起与微增益被误重置。
- 修复 MPV 内核下音量设置严重失真的量纲映射缺陷：`media_kit` 接受 0.0~100.0 音量范围，修复此前传入 0.0~1.0 导致视频几近静音的问题。
- 重构系统音频打断（Audio Ducking）逻辑，废除破坏性就地修改全局音量（`* 0.5` / `* 2`），改为基于 `PlaybackVolumeCoordinator` 的独立幂等衰减因子，杜绝状态漂移与不可逆截断。

## [1.5.0-beta.2] - 2026-09-21

### 新增

- 引入基于 AST 的机器自动化架构守卫与静态分析加固体系：
  - 建立全自动化 AST 架构测试套件（`test/architecture/`），在 `flutter test` 与 CI 门禁中以毫秒级机械拦截局部变量同名遮蔽类属性（`FieldShadowingGuard`）、控制器非法 `late` 声明（`ControllerZeroLateGuard`）及核心诊断链路裸吞错误（`CriticalBareCatchGuard`），彻底替代脆弱的人工 Checklist；
  - 依托 AST 守卫扫描全库，根除 `video_detail_res.dart`、`login/controller.dart` 等历史遗留的 8 处变量遮蔽隐患与潜在序列化 Bug；
  - 在 [`analysis_options.yaml`](file:///E:/Documents/PiliPalaZ/analysis_options.yaml) 激活 `unnecessary_late`、`cancel_subscriptions`、`close_sinks` 与 `avoid_shadowing_type_parameters` 严格静态检查规则。
- 全面重构并升级「播放信息」统计与排障诊断面板（Stats for Nerds）：
  - 彻底解决 Media3 内核下由于直接读取已闲置的 media_kit 控制器而导致的字段全空（`nullxnull`、空白参数与空列表）缺陷，统一从 `IPlayerEngine`、`VideoItem`、`AudioItem` 与响应式控制器提取真实运行时指标；
  - 结构化整合 5 大诊断模块：播放内核与渲染管线（清晰标识当前运行的 Media3 / MPV 内核、SurfaceTexture 渲染后端、硬解配置与音频输出）、视频流规格（画质、画面尺寸、编码格式、帧率、码率）、音频流规格（音质、编码、码率）、播放与缓冲健康度（当前进度、总时长、缓冲进度与百分比、播放状态与倍速）、网络与元数据（稿件来源、BVID、CID、脱敏 CDN 节点）；
  - 独立抽离模块化组件 [`player_info_dialog.dart`](file:///E:/Documents/PiliPalaZ/lib/pages/video/widgets/player_info_dialog.dart)，移除 [`header_control.dart`](file:///E:/Documents/PiliPalaZ/lib/pages/video/widgets/header_control.dart) 中 180 余行冗余硬编码逻辑，并优化设置弹窗呼出层级；
  - 提供单项条目点击快捷复制（附带 Toast 提示）与「复制全部 (Markdown)」一键排障数据导出功能，极大便利社区 Issue 与反馈排障。

### 修复

- 修复播放器播放/暂停按钮状态不同步、播放期间意外熄屏以及多路由跳转返回无画面黑屏缺陷：
  - 完善 Android Media3 原生层事件流，在 `onIsPlayingChanged` 中精确派发 `playing`/`paused` 状态并对缓冲与播放结束状态增加安全保护，在 Dart 引擎层补全 `paused` 状态机并引入乐观更新，消除通道延迟与按钮状态脱节；
  - 恢复并规范响应式唤醒锁（Wakelock）管理，建立 `_updateWakelock()` 综合联动播放状态、纯音频后台播放模式与应用前后台生命周期，彻底解决视频播放时自动熄屏且杜绝后台常驻耗电；
  - 修复播放控制器在多路由切换并返回时画面黑屏（有声音无画面）缺陷：在底层引擎重新完成初始化并获取全新 `textureId` 后强制递增 `engineGeneration` 代际标识，驱动 Flutter `ValueKey` 销毁旧纹理并挂载新纹理组件，同时在页面重入生命周期（`didPopNext`）与恢复播放结束时安全触发视图刷新。
- 修复播放信息（Stats for Nerds）面板中音频编码与音频码率显示为“未知”及音轨状态脱节问题：
  - 根除 [`controller.dart`](file:///E:/Documents/PiliPalaZ/lib/pages/video/controller.dart) 中局部变量 `late AudioItem? firstAudio;` 遮蔽类属性引发的 `LateInitializationError`，将音轨字段改造为安全可空声明；
  - 修复 `updatePlayer()` 中音频音轨与底层 URL 脱节缺陷，扩充音轨候选池以完整支持杜比全景声与 Hi-Res/FLAC 无损音轨，防止切换画质时杜比/无损被静默降级为普通音质；
  - 针对离线缓存播放与 DURL 单流模式补齐音轨规格智能推断，准确展示标称码率、音频编码与单流标识；
  - 加固 [`AudioItem.fromJson`](file:///E:/Documents/PiliPalaZ/lib/models/video/play/url.dart) 反序列化未知音质枚举容灾，并防御性加固未就绪时缓存与设置菜单对 `data` 的前置读取。
- 修复手机在视频播放页旋转至横屏时底部布局溢出（`RenderFlex overflowed by 24 pixels on the bottom`）问题：
  - 针对常规手机横屏播放场景，修复 [`view.dart`](file:///E:/Documents/PiliPalaZ/lib/pages/video/view.dart) 中 `childWhenDisabled` 的 `Scaffold` 在横屏时仍渲染 `AppBar(toolbarHeight: 0)` 占用 24dp 状态栏高度的缺陷，在横屏下置空 `AppBar`；
  - 在横屏下排除垂直排列的 `Expanded` 简介/评论标签页，使全屏高度播放器独占显示，彻底消除弹性子组件空间挤压与黄黑警告条。

## [1.5.0-beta.1] - 2026-09-20

### 修复

- 修复全屏放大视频及竖屏全屏时播放器顶栏布局溢出（`RenderFlex overflowed by 22/29 pixels on the right`）问题：
  - 顶栏 [`HeaderControl`](file:///E:/Documents/PiliPalaZ/lib/pages/video/widgets/header_control.dart) 严格结合全屏状态与横屏方向（`showLandscapeExpandedHeader`），避免在系统物理旋转延迟过渡期间以及竖屏全屏模式下强行渲染第二行操作栏导致宽度溢出；
  - 首行 `PlayerHeaderActionRow` 保持紧凑模式，保留弹幕开关与画中画等核心操作；第二行操作栏采用 `Expanded` + `Align(centerRight)` + `SingleChildScrollView` 弹性防御架构，清除历史遗留的硬编码空循环与多余占位，确保窄宽与多窗口分屏下绝对零溢出。
- 修复 Android 平台 Media3 内核硬件解码器缓冲槽位受限与绿屏卡死问题：
  - 改用 Flutter 原生 `createSurfaceTexture()` (SurfaceTextureEntry) 替代 `createSurfaceProducer()`，突破 `ImageReader` 仅允许 <=6 缓冲槽位的硬编码限制，提供完整的 64 缓冲槽 `BufferQueueCore`，彻底根除海思麒麟（Kirin 710F 等）芯片 `ACodec: setting nBufferCountActual failed: -1010` 硬件解码器启动失败；
  - 避免硬件解码失败降级至软件解码器后因 Android < 33 缺少图形栅障（Fence）同步而渲染空白 YUV 缓冲导致的纯绿屏故障，实现海思芯片硬件解码器直接启动并以 25/60 fps 满帧流畅解码；
  - 倒置 `Media3PlayerPlugin.disposePlayer()` 销毁时序，确保 ExoPlayer 内部解码线程停止后再释放 Surface 纹理，彻底杜绝多线程销毁时序引发的管道破裂（Broken Pipe）。
- 修复 Android 平台 Media3 内核硬件解码器 Surface 管道破裂问题：
  - 严格遵循 Google 官方 `video_player_android` (TextureVideoPlayer) 规范，禁绝动态 `producer.setSize()`，原生层补齐画面物理旋转角度（90°/270°）自动宽高换算与非方像素比（PAR）校正，Dart 端改由响应式 `StreamBuilder<VideoDimension>` 与 `FittedBox` / `ClipRect` 处理画面裁切与多 `BoxFit` 模式。

### 重构

- 播放器架构全平台抽象解耦（Phase 2: Player Engine Abstraction）：
  - 抽离统一播放器内核抽象契约 `IPlayerEngine`，全面抹平底层播放引擎（`media_kit`、`libmpv` 与后续 `Media3`）差异；
  - 建立统一媒体源与状态数据结构：`PlayerMediaItem`、`VideoDimension`、`EnginePlaybackState` 及错误自愈模型 `EngineError`；
  - 实现 `MpvPlayerEngine` 适配类，完整内聚 libmpv 解复用器缓冲调控、`video-sync=audio`、断网重连与 Surface 销毁回调安全排空逻辑；
  - 落地 `HeadlessPlayerEngine`，彻底解耦自动化单元/旅程测试对原生平台动态库的硬性依赖；
  - 重构 `PlPlayerController` 与 `view.dart` 对接引擎抽象契约与统一视图工厂 `buildVideoView()`，向下保留兼容垫片与画中画宽高同步获取，达成全业务零回归。
- Android 原生 Media3/ExoPlayer 播放内核接入（Phase 3: Android Media3 Native Engine）：
  - 引入 AndroidX Media3 (1.5.1) 原生依赖，落地 `Media3PlayerPlugin`、`Media3PlayerHolder` 与 `Media3SurfaceManager`；
  - 采用 Flutter 3.38+ 推荐的 `TextureRegistry.SurfaceProducer` 与双重销毁安全守卫，根治 Impeller/Vulkan 架构下的纹理崩溃与内存泄漏；
  - 原生支持 B 站 DASH 音视频双流直出（`MergingMediaSource`）与精确剪裁，统一网络请求头与 25 秒防抖缓冲池；
  - 实现 Dart 端 `Media3PlayerEngine` 并入统一引擎体系，通过 Platform Channel 达成 100ms 节流事件同步；
  - 确保 Media3 专注于音视频解码渲染，100% 隔离 AudioFocus 与 MediaSession，杜绝与前台服务及 `audio_service` 冲突。
- 播放器内核双引擎灰度切换与全业务对齐（Phase 4: Dual-Engine Switch & Alignment）：
  - 音视频设置页增加“播放器内核”选项，Android 默认推荐采用 Media3 (ExoPlayer) 内核，保留 MPV (media_kit) 传统内核作为容灾备用；
  - 彻底治理控制器“精神分裂”缺陷，统一通过 `_engine` 驱动媒体装载、倍速调控、精准 Seek、音量调节与状态监听；
  - 落地 Media3 内核异常自动降级机制，若原生层初始化异常无感回退至 MPV 并记录诊断检查点；
  - 建立双引擎统一条约单元与集成测试套件（`test/player_kernel_selection_test.dart`），全量 649 个测试 100% 通过。
- 播放器架构全量切换与历史残留剥离收官（Phase 5: Full Switch & Cleanup）：
  - Android 平台全面确立 Media3 (ExoPlayer) 为生产环境默认播放内核，桌面平台平稳保持 MPV 内核；
  - 收敛控制器与页面离开生命周期，在 `disable()` 路径对称调度 `_engine?.stop()`，彻底消除路由切换可能引入的原生音频残留；
  - 交付端到端生命周期与容灾断言测试套件（`test/player_engine_phase5_e2e_test.dart`），全量 653 个自动化测试通过。

## [1.4.0] - 2026-09-18

### 新增

- 全新离线缓存与离线播放功能（Offline Cache & Playback）：
  - DASH 零混流双流直出：独立拉取视频流与音频流，本地通过外部音频指令直接组合挂载，免除移动端 FFmpeg 混流重封装的高额耗电与性能损耗；
  - 离线弹幕与 WebVTT 多语言字幕缓存：视频下载完成后自动拉取多段 Protobuf 弹幕聚合归档为 `danmaku.bin`，并同步缓存多语言 WebVTT 字幕；离线播放打通本地字幕解析装载与用户偏好联动；
  - 存储水位红线与断点自愈引擎：管理应用私有下载目录，内置 200MB 磁盘可用空间安全红线与任务熔断，支持 HTTP 206 续写与 403/410 CDN 凭据过期自动换新；
  - 视频详情页下载弹窗（`DownloadSheet`）：支持多画质分 P 选集批量勾选、DRM 版权过滤、时间码（`mm:ss` / `hh:mm:ss`）规范化与智能默认勾选；
  - 媒体库离线中心与存储仪表盘：正式激活“离线缓存”中心（`/download`），支持实时网速进度、单项/批量管理及磁盘占用可视化；
  - 纯本地离线详情面板与无网安全隔离：竖屏/折叠屏/平板下切除不可用的假点赞/投币/收藏互动栏与轮询定时器，彻底闭环离线源短路拦截，消除无网环境下向外网发起心跳与弹幕请求的网络泄漏。
- 统一播放队列体系（Unified Playback Queue）：
  - 全面统一分 P、UGC 合集、PGC 影视剧集、稍后再看与相关视频的播放流转，抽象通用 `PlayQueueItem` 模型；
  - 活跃实例堆栈式生命周期管理与外部队列锁定保护，避免页面进出或多 P 切换时待播序列被冲刷；
  - 可视化播放队列面板（`PlayQueueBottomSheet`）：支持打开自动聚焦居中当前播放条目、列表循环/单曲循环/自动连播模式切换、单项移除与清空待播；
  - 播放器底栏控制与系统通知栏联动：上一集/下一集深度绑定队列状态，打通 Android 锁屏界面通知与蓝牙耳机 AVRCP 硬件切歌。
- 深度无障碍支持（Accessibility Hardening）：
  - 核心控件触控热区全面达标：播放器底栏控制项、顶部控制按钮、互动操作项及用户头像均满足 Android 48×48dp 与 iOS 44×44dp 触控规范；
  - 屏幕阅读器深度支持：补全各类控制按钮辅助标签与选中/长按提示状态；控制层隐藏时自动通过 `ExcludeSemantics` 与 `ExcludeFocus` 剪枝；建立自动化无障碍基线测试套件。
- Android 16 大屏、平板与折叠屏适配：
  - 平板及大屏设备自动解除固定竖屏限制，支持全方向自适应旋转与多窗口尺寸调整；
  - 挖孔全屏展示策略升级至 `LAYOUT_IN_DISPLAY_CUTOUT_MODE_ALWAYS`，消除横向 letterbox 黑边；
  - 视频详情页平板横屏自适应双栏（左侧播放器、右侧推荐与评论独立切换）与折叠屏近方屏自适应分栏排布。

### 优化

- 播放界面锁定与截图功能恢复与立体视觉增强：
  - 解耦播放界面【锁定】与【截图】按钮的可见性判定，在横屏视口（手机横屏、平板双栏分屏或全屏模式）下恢复受控显示，彻底解决大屏设备横屏时锁定与截图按钮意外消失的问题；
  - 增强锁定按钮与截图按钮的立体视觉对比度：引入 45% 黑色半透明圆盘底座（44×44dp）与抗锯齿剪裁，确保在纯白高亮或复杂视频画面下肉眼清晰可见；
  - 优化横屏沉浸模式与刘海异形屏物理安全区避让（`safeLeft`/`safeRight`），防止按钮被摄像头刘海遮挡或紧贴屏幕边缘导致误触；
  - 锁定激活状态下严格屏蔽截图按钮与其余播放控制手势，实现纯净防误触体验。
- 播放器动态缓冲容量与网络抖动自愈：
  - 点播 Wi-Fi 默认解复用器缓冲提升至 32MB，蜂窝网络 16MB，扩展/VPN 模式 64MB；直播默认 16MB，扩展 32MB；回退缓冲解耦为 `(maxBytes ~/ 4).clamp(2MB, 8MB)`；
  - 前向预读锁定为点播 30s / 直播 10s；卡顿恢复设为点播 2.0s / 直播 1.0s；
  - 在底层网络流协议层配置安全的 `reconnect_on_http_error=5xx` 与 DASH 外置音轨重连容灾，解决音视频分离流闲置断连导致的停滞，并在退出与切集时规避死循环。
- 动态卡片系统全量补全与交互加固：
  - 补齐商品带货卡片、通用活动与游戏中心卡片、赛事对抗卡片与投票卡片；
  - 根治动态流富文本手势死锁，移除列表态物理屏蔽，打通话题搜索与内嵌超链接直达。

### 修复

- 根治 Android 高通骁龙与高刷（LTPO）设备起播定格卡死与解码器死锁：
  - 修复 `media_kit_video` 原生 `VideoOutput.java` 在分辨率变更时重复触发 `onSurfaceAvailable` 导致的 JNI GlobalRef 内存泄漏与 Surface 频繁销毁重建死循环；在 `onSurfaceCleanup` 中显式复位句柄消除脏指针隐患；
  - 彻底拔除 Android 视频控制器 `widListener` 内部触发的非预期 `seek` 冲刷调用，消除起播元数据就绪时的解码器清空、网络重新握手与高通 MediaCodec 缓冲队列挂起；
  - 将移动端 `video-sync` 默认基线由 `display-resample` 调整为 `audio`，避免动态帧率与 LTPO 高刷屏下重采样算法发散导致 AudioTrack 欠载死锁，并在存储层引入平滑迁移与备份导入对称守卫。
- 根治播放器底栏控制按钮 GetX 0-Rx 致命断言红屏崩溃：
  - 重构播放/暂停按钮（`PlayOrPauseButton`），在 `Obx` 入口处显式解构状态变量，绑定响应式生命周期，杜绝冷启动与未就绪状态下的 `0-Rx` 异常；
  - 重构上一集与下一集控制按钮（`PreEpisodeButton` / `NextEpisodeButton`），实施二态分支隔离，彻底消除 0-Rx 闪退。
- 修复播放器倍速初始化时序缺陷：解决生命周期未就绪时默认倍速指令被拦截导致的 UI 倍速与实际播放速率失步问题。
- 修复真机离线播放时多项类型转换（`descV2`）与空安全解包崩溃，修复下载卡片在窄屏视口下的布局溢出。
- 修复动态流反序列化条目级故障隔离，单张异常动态解析失败仅单项跳过，杜绝局部畸形导致整页空白。
- 修复播放器在页面退出或切集时偶发的 `Player has been disposed` 异常与定时器泄漏。


## [1.4.0-beta.6] - 2026-09-18

### 修复

- 播放界面锁定与截图功能恢复：
  - 解耦播放界面【锁定】与【截图】按钮的可见性判定，在横屏视口（手机横屏、平板双栏分屏或全屏模式）下恢复受控显示，彻底解决大屏设备横屏时锁定与截图按钮意外消失的问题；
  - 增强锁定按钮与截图按钮的立体视觉对比度：引入 45% 黑色半透明圆盘底座（44×44dp）与抗锯齿剪裁，确保在纯白高亮或复杂视频画面下肉眼清晰可见；
  - 优化横屏沉浸模式与刘海异形屏物理安全区避让（`safeLeft`/`safeRight`），防止按钮被摄像头刘海遮挡或紧贴屏幕边缘导致误触；
  - 维持平板双栏分屏下的控制条高度保护，严格避免底部控制条遮挡视频画面；
  - 补充针对平板横屏、手机竖屏、显式锁定态等全场景的按钮可见性与布局渲染单元测试覆盖。
- 根治 Android 高通骁龙与高刷设备起播卡顿与解码器死锁：
  - 修复 `media_kit_video` 原生 `VideoOutput.java` 在分辨率变更时重复触发 `onSurfaceAvailable` 导致的 JNI GlobalRef 内存泄漏与 Surface 频繁销毁重建死循环；在 `onSurfaceCleanup` 中显式复位句柄消除脏指针隐患；
  - 彻底拔除 Android 视频控制器 `widListener` 内部触发的非预期 `seek` 冲刷调用，消除起播元数据就绪时的解码器清空、网络重新握手与高通 MediaCodec 缓冲队列挂起；
  - 在底层网络流协议层配置安全的 `reconnect_on_http_error=5xx` 重连容灾，严格规避 `reconnect_at_eof` 引发的完播切集无限死循环，并保持迟滞拉流参数为 0 避免直播流周期性断流卡死。

## [1.4.0-beta.5] - 2026-09-17

### 修复

- 播放器定格卡死与高倍速缓冲断流综合治理：
  - 动态缓冲容量阶梯与解复用器配置：点播 Wi-Fi 默认解复用器缓冲提升至 32MB，蜂窝网络 16MB，扩展/VPN 模式 64MB；直播默认 16MB，扩展 32MB；回退缓冲解耦为 `(maxBytes ~/ 4).clamp(2MB, 8MB)`；前向预读锁定为点播 30s / 直播 10s；卡顿恢复设为点播 2.0s / 直播 1.0s；多网并发准确识别避免 Wi-Fi 下被误判为蜂窝限制；
  - 根治 Android 动态高刷屏下的播放定格假死：将移动端 `video-sync` 默认基线由 `display-resample` 调整为 `audio`，避免动态帧率与 LTPO 高刷屏下重采样算法发散导致 AudioTrack 欠载死锁；在存储层引入平滑迁移与备份导入对称守卫，自动将老用户的历史遗留配置规整为 `audio` 并保护主动自定义配置；
  - DASH 外置音轨与视频流断线自愈：在底层 FFmpeg 协议层注入 `stream-lavf-o` 网络重连参数（`reconnect=1,reconnect_streamed=1,reconnect_delay_max=5,reconnect_on_network_error=1`），解决 B 站音视频分离流中音频连接闲置被 CDN 断开导致的播放停滞，配合 30s 前瞻缓冲实现网络抖动无感自愈。

## [1.4.0-beta.4] - 2026-09-17

### 新增

- 离线缓存支持字幕文件拉取与本地离线播放装载：
  - 离线下载支持同步缓存视频字幕文件（`subtitles.json`），在音视频与弹幕下载完成后于非致命辅助资产拉取阶段拉取全部多语言 WebVTT 字幕，遵循 CancelToken 及时取消与异常安全降级；
  - 存储层扩展 `DownloadTask.subtitlesRelativePath`，保持 Hive 持久化向后兼容性与旧版本任务物理平滑回退；
  - 离线播放（`DataSourceType.file`）打通本地字幕解析与装载，严格遵循 Index 0 占位轨道契约，联动用户字幕偏好设置（全部开启 / 仅非 AI 字幕 / 关闭）自动选择轨道并在底栏控制条唤出字幕切换面板；
  - 播放器切源与换集引入 `session == _playbackSession` 异步生命周期守卫，彻底消除弱网或快速切集时的字幕竞态与串台隐患。

### 修复

- 播放器播放暂停控制按钮 GetX 0-Rx 致命短路根治与响应式契约加固：
  - 修复平板横屏双栏冷启动或播放器未就绪时，底部控制栏播放/暂停按钮（`PlayOrPauseButton`）在 `Obx` 中因 `canControlPlayback`（非响应式普通布尔属性）为 `false` 触发 `false && playerStatus.playing` 短路，导致未读取任何 Rx 变量触发 GetX 致命断言（`0-Rx` 导致界面红屏崩溃）的问题；
  - 重构 `PlayOrPauseButton`，控制器为空时直接返回无状态占位组件，在 `Obx` 入口处无条件显式解构 `playerStatus.status.value` 与 `playbackLifecycleState.value`，确保响应式变量读取数永远 $\ge 2$，彻底消除短路风险；
  - 重构 `PlPlayerController.canControlPlayback` 与 `isPlaying`，底层绑定响应式生命周期状态 `playbackLifecycleState.value == PlaybackLifecycleState.ready`，从根源上实现播放器就绪后控制按钮自动响应式点亮；
  - 加固 `view.dart` 中平板横屏双栏与方屏布局内部容器，在 `Obx` 入口处无条件解构 `direction` 与 `isFullScreen`，消除大粒度布局偶合式依赖；
  - 补充 `PlayOrPauseButton` 与包含完整控制条的 `AdaptiveBottomControlRow` 在未就绪状态下的专用 Widget 自动化测试。

## [1.4.0-beta.3] - 2026-09-16

### 变更

- 动态内容补全与手艺坏味道专项治理（P2-3）：
  - 附加卡片全量补全与 UX 规范化：解除商品带货卡片代码注释并重构，支持商品封面图、品名、简介、主题色价格与“去看看”胶囊按钮；实现通用活动与游戏中心卡片（展示图标、副标题、行动按钮）；实现赛事对抗卡片（对称战队徽标、队名、比分、状态徽标与防溢出保护）；实现投票卡片（投票标题、参与人数、进行中/已结束状态指示并打通 H5 投票交互）；彻底清除 `Text('11')` 调试残留字符串，未知类型安全返回 `SizedBox.shrink()`。
  - 根治动态流富文本手势死锁：移除 `content_panel.dart` 在列表态包裹的 `IgnorePointer(ignoring: true)`，解除对话题、网页链接、抽奖与商品等内嵌 Span 的物理屏蔽；仅在详情页保留 `SelectableRegion`；外层动态卡片增加详情页防递归入栈保护。
  - 路由契约与参数非空加固：打通 `#话题` 跳转全局搜索；打通抽奖与商品富文本节点直达；针对 `WebviewController` 严格落实 `url`, `type`, `pageTitle` 三元非空安全约束，URL 协议统一清洗规范化。
  - 模型层强类型化与全动态类型挂载闭环：`DynamicAddModel` 中的 `match` 与 `common` 升级为强类型反序列化模型并支持双轨容错解析；在视频投稿（`AV`）、合集（`UGC_SEASON`）、番剧（`PGC`）、专栏（`ARTICLE`）及转发纯文本中全量补齐附加卡片挂载。

### 修复

- 播放器底栏控制按钮 GetX 0-Rx 异常与防空架构重构：
  - 修复多 P 视频或平板横屏冷启动下，底部控制栏上一集与下一集按钮在 `_queueController == null` 时因短路跳过 Rx 变量读取，触发 GetX 致命断言（`[Get] the improper use of a GetX has been detected`）导致界面异常崩溃的问题；
  - 抽离独立安全组件 `PreEpisodeButton` 与 `NextEpisodeButton`，严格实施二态分支：未绑定队列控制器时渲染降级可用静态按钮（绝不包 `Obx`），绑定后由局部 `Obx` 精确监听 `hasPrevious.value` 与 `hasNext.value`，彻底消除 0-Rx 异常风险；
  - 加固 `_queueController` 获取链路为三级容灾模式（实例直引 -> tag 检索 -> 全局活跃栈兜底），并在视频详情页与简介控制器初始化中补齐 `heroTag` 的非空与默认值安全兜底。

## [1.4.0-beta.2] - 2026-09-16

### 修复

- 播放器倍速初始化时序与生命周期守卫修复（BAC-19）：
  - 修复 `PlPlayerController.setDataSource` 在初始化视频播放器时生命周期尚未就绪（`canControlPlayback == false`），导致 `_initializePlayer` 内的默认倍速设置指令被完全拦截短路、底层原生播放速率未设置而 UI 仍显示设定倍速的严重失步 Bug。
  - 将 `_playbackLifecycle.markReady(session)` 前移至 `_initializePlayer()` 之前，并增加 session 失效中断守卫与异步后置校验；
  - 规范化 `setDefaultSpeed()` 调度，统一收拢委托至 `setPlaybackSpeed(speed)`，纳入生命周期守卫与长按倍速状态机保护。
- 平板横屏离线视频纯黑影院视口与安全区隔离治理（BAC-20）：
  - 修复平板横屏双栏模式下离线视频左侧播放器列上下露出大面积浅色主题白边（Letterbox 缺失）以及左侧安全区避让条白边的视觉缺陷。
  - 将离线视频左侧播放器列强制设为纯黑（`Colors.black`）影院视口；
  - 在横屏双栏脚手架中实现条件化隔离（`videoDetailController.isOffline`）：离线模式下外层设为纯黑且将播放视口延伸至屏幕物理边缘，右侧面板显式保持浅色/深色主题表面色（`colorScheme.surface`）并独立处理右侧安全区；在线视频保持既有主题背景与避让行为，彻底杜绝浅色模式“黑底黑字”退化。

## [1.4.0-beta.1] - 2026-09-15

### 变更

- 新增离线缓存与播放功能（Offline Cache and Playback）：
  - 纯领域模型与持久化 DAO：定义无 UI 依赖的 `DownloadTask` 领域模型与状态机（`pending`、`downloading`、`paused`、`completed`、`failed`），基于 Hive 轻量持久化存储，支持多维任务元数据与进度持久化。
  - DASH 零混流本地双流直出：独立拉取视频流与音频流（`video.m4s` 与 `audio.m4s`），播放时通过播放器外部音频指令（`buildExternalAudioCommand`）直接组合挂载，免除移动设备本地 FFmpeg 混流重封装的高额 CPU/耗电损耗。
  - 离线多段弹幕聚合归档：根据视频总时长自动分段批量获取 Protobuf 弹幕消息体，聚合归档为单个本地 `danmaku.bin` 文件；播放器初始化自动探测并挂载离线弹幕文件，全量短路网络请求。
  - 存储水位红线与断点自愈引擎：管理应用私有下载目录与相对路径持久化，内置 200MB 磁盘可用空间安全红线与任务熔断保护；支持 HTTP 206 续写与 HTTP 200 容错截断，遇 403/410 CDN 凭据过期自动同编码规格保真换新续传，应用冷启动自动自愈未竟任务。
  - 视频详情页下载弹窗（`DownloadSheet`）：支持不同清晰度与分 P 选集批量勾选，集成 DRM 版权保护与试看片段（`tryLook` / `trial` / `-10403`）前置拦截；规范化视频分 P 时长显示为标准时间码（`mm:ss` / `hh:mm:ss`），废弃不合常理的裸秒拼接；实时感知本地已有任务状态并展示 M3 状态胶囊徽标（已缓存·清晰度、下载中、已暂停、下载失败）；引入“全选未缓存 -> 全选所有 -> 取消全选”三态状态机与智能默认勾选；健全四分法提交流水线，支持同画质重复缓存自动跳过与不同画质聚合二次确认替换下载，杜绝假成功 Toast 与静默失效。
  - 媒体库离线中心与存储仪表盘：媒体库正式激活“离线缓存”中心（`/download`），支持“已完成”与“下载中”双 Tab 切换、实时网速与进度、单项/批量操作及磁盘存储占用可视化指示条。
- 规范化离线播放架构设计（Offline Video UX Hardening）：
  - 物理隔离离线信息面板：新建纯本地 `OfflineVideoIntroPanel`，在竖屏、折叠屏近方屏与平板大屏下完全切除 `TabBar`、`TabBarView`、评论列表与网络推荐，彻底剔除不可用的假点赞/投币/收藏互动栏与轮询定时器。
  - 离线资产规格与本地多 P 选集：展示已下载画质、编码规格、音质、文件占用大小及离线弹幕状态；本地聚合多 P 分集卡片支持无缝切集，接入 `PlaybackQueueController` 实现锁屏通知与耳机按键切集联动。
  - 查看在线原视频无缝接力：提供独立时间戳盐的在线跳转通道，自动携带当前离线播放进度接力播放。
- 统一播放队列体系（Unified Playback Queue）：
  - 领域模型与跨源统一：抽象通用 `PlayQueueItem` 与 `PlayQueueSourceType`，全面统一分 P（`part`）、UGC 合集（`ugcSeason`）、PGC 影视剧集（`pgcEpisode`）、稍后再看（`watchLater`）以及相关视频（`related`）的播放与流转控制。
  - 队列生命周期与堆栈式激活：实现 `PlaybackQueueController`，引入堆栈式活跃实例管理（`_activeStack`）与回退自动重新激活机制（`markActive`），避免页面多次进出时控制指针失效或悬空。
  - 外部队列锁定保护：支持稍后再看或自定义队列锁定（`isExternalQueue`），防止多 P 视频或合集在切换集数重刷详情时冲刷或覆盖待播序列。
  - 队列自愈与越界保护：支持条目实时移除、清空后续待播项、正反序排布、列表循环回绕以及单项排空停止，自动平滑自愈当前播放索引。
  - 可视化播放队列面板（`PlayQueueBottomSheet`）：支持打开自动聚焦居中于当前播放条目、实时高亮播放中条目、播放模式快捷切换（播完暂停、顺序播放、列表循环、单曲循环、自动连播）、单项移除、清空待播与大会员权益守卫。
  - 播放器底栏控制与连播集成：底栏上一集与下一集按钮深度绑定队列可用状态（`hasPrevious` 与 `hasNext`），达到端点自动置灰禁用，列表循环与自动连播模式下保持可用；选集按钮升级为统一播放队列入口。
  - 稍后再看页面打通：顶部 AppBar 新增“播放全部”入口；单项卡片点击直接携带完整待播列表与当前起始索引无缝载入播放器。
  - 后台音频服务与系统通知栏打通：`AudioHandler` 实现 `skipToNext()` 与 `skipToPrevious()`，在 `systemActions` 中注册上一曲/下一曲控制，全面打通 Android 锁屏界面通知与蓝牙耳机 AVRCP 硬件切歌指令。
- 完善应用无障碍支持（Accessibility Hardening）：
  - 核心控件触控热区全面达标：播放器底栏控制项（上一集、下一集、选集、画面比例、字幕、倍速、全屏）、顶部控制按钮、视频互动操作项（点赞、投币、收藏、分享）与首页用户头像均满足 Android 48x48dp 与 iOS 44x44dp 触控热区规范要求。
  - 语义树与屏幕阅读器（TalkBack / VoiceOver）深度支持：补全各类控制按钮、视频卡片及互动组件的 `isButton` 标志、辅助标签及选中/长按提示状态；播放器控制层隐藏时自动通过 `ExcludeSemantics` 与 `ExcludeFocus` 剪枝，避免不可见组件干扰读屏焦点导航。
  - 消除 Flutter 废弃 API 警告：将 `SemanticsService.announce` 升级至 `SemanticsService.sendAnnouncement`，适配多视图树分发并平滑回退；将颜色透明度 `.withOpacity()` 迁移至高精度 `.withValues(alpha: ...)`。
  - 建立自动化无障碍基线测试套件：新增 `test/accessibility/accessibility_guidelines_test.dart`，涵盖触控热区（`androidTapTargetGuideline`、`iOSTapTargetGuideline`）、可访问语义标签（`labeledTapTargetGuideline`）、文字对比度（`textContrastGuideline`）与隐藏图层语义隔离测试。
- 优化 Android 16 大屏、平板与折叠屏适配：平板及大屏设备自动解除固定竖屏限制，解耦手机偏好并支持全方向自适应旋转与运行时多窗口尺寸调整。
- 升级 Android 挖孔展示策略至 `LAYOUT_IN_DISPLAY_CUTOUT_MODE_ALWAYS`（API 30+），消除平板大屏横向 letterbox 黑边，实现真正的边缘到边缘体验。
- 重构视频详情页响应式布局：平板横屏支持自适应双栏（左侧播放器与视频信息、右侧相关推荐与评论交流独立切换），折叠屏近正方形视口采用自适应分栏排布。

### 修复

- 修复真机离线播放时 `IntroDetail` 视频简介构建时 `descV2` 强制转换导致的 `type 'Null' is not a subtype of type 'List<dynamic>'` 运行时崩溃，加固离线视频元数据空安全回退。
- 修复真机离线播放时操作栏直接解包 `stat` 导致的 `Null check operator used on a null value` 运行时崩溃，健全 `_handleOfflineIntro` 完备默认元数据与视图层安全可空导航。
- 修复离线视频播放时后台持续向外网发起 `x/v2/dm/web/seg.so` 弹幕、`x/player/wbi/v2` 字幕与 `/x/click-interface/web/heartbeat` 心跳请求的网络泄漏问题，彻底闭环离线源短路拦截并消除 10Hz 空转拉取。
- 根治下载页面“下载中”卡片在窄屏下触发的 `RenderFlex overflowed by 44 pixels` 布局溢出，缩略图微调至 100x62，大小与速率文本行采用双端弹性比例约束，精简右侧控制按钮并将删除操作收拢至卡片长按确认。
- 修复离线缓存系统剩余存储容量假数据问题，新增 Android 原生平台通道 `DiskSpaceChannel` 通过 `StatFs` 安全查询沙盒真实剩余空间，并提供无头环境与跨平台安全回退。
- 修复离线缓存任务完成后弹幕与封面未持久化的问题，在双流下载完成后自动拉取多段 Protobuf 弹幕聚合为 `danmaku.bin` 并持久化 `cover.jpg`，保障无网环境离线媒体资源完整。
- 优化下载管理页面“下载中”卡片视觉与交互，重构为与“已完成”对齐的紧凑图文水平布局（110x68 封面、时长胶囊、进度条、实时速率与 48x48dp 无障碍操作按钮）。
- 修复无网环境下进入视频详情页评论加载失败陷入触底无限重试死循环的问题，健全 `VideoReplyPanel` 与 `VideoReplyController` 的四重状态守卫，离线播放模式下直接短路视频详情与评论网络请求并展示离线友好占位，网络失败展示显式重试卡片。
- 修复视频详情页在内嵌双栏与全屏相互切换时触发的 `RenderFlex` 布局溢出问题。
- 修复 PGC 影视番剧在平板大屏横屏模式下缺少 TabBar 导致的断言崩溃问题。
- 修复窄屏及多窗口分屏视口下视频统计信息溢出（`RenderFlex overflow`）的问题。
- 修复视频选集分 P 列表在匹配当前播放分 P 失败时的数组越界异常（`RangeError: -1`）。
- 修复 UP 主直播推荐卡片（`live_rcmd`）中直播间编号等整型字段反序列化为字符串导致的 `TypeError` 崩溃，解决原神等 UP 空间动态“响应字段类型不正确”的问题。
- 改造动态反序列化架构为条目级故障隔离，单张异常或试验性动态卡片解析失败仅单项跳过并输出调试日志，杜绝局部畸形导致整页动态空白。
- 规范化动态模型中 Map 与 List 复合结构的类型安全校验，防御后端空对象返回空数组 `[]` 导致的类型不匹配；修复点赞与评论计数在空值时错误展示为 `"null"` 文本的问题。
- 修复 UP 空间动态页面重试按钮无响应以及下拉刷新与数据源状态失步的问题，统一滚动物理属性并补全动态空状态提示。
- 修复 `HeaderControl` 与 `BottomControl` 实现 `PreferredSizeWidget` 时未重写 `preferredSize` 导致的 `UnimplementedError` 崩溃。
- 修复播放器在页面退出、切集或后台切换时因 `[Player] has been disposed` 导致的闪退，加固原生播放引擎释放与 Android 视频控制器的生命周期守卫。
- 统一收敛并彻底清理播放器内部长按快进、音量显示、亮度调节等定时器与事件流订阅，杜绝内存泄漏。
- 修复播放器视图挂载、画中画宽高比计算以及双击快进快退时的空指针解包隐患，提升极端网络与快速操作下的稳定性。
- 修复 Android 平台在初始展示宽高未就绪时视频渲染表面纹理无法正常分配的问题。
- 强化普通视频与影视详情在极端网络或异常响应下的数据空安全防御与容错恢复。

## [1.3.2-beta.3] - 2026-09-12

### 变更

- 登录令牌与会话 Cookie 改用系统安全存储；旧版本地登录态会在设备内验证迁移，退出登录会同步清理安全存储、旧缓存和 WebView 会话。
- 设置备份仅包含应用设置与视频设置，不导出或导入账户凭据。
- 收敛 Android 与 iOS 权限声明：保存图片仅在系统确有需要时请求最低权限，并移除未使用的媒体、网络、相机与后台能力声明。

## [1.3.2-beta.2] - 2026-09-08

### 新增

- 增加结构化 GitHub 缺陷报告与功能建议入口；本地诊断可在审阅后由用户主动复制并打开反馈表单，设备兼容信息默认不包含，所有内容均不会自动上传。

### 修复

- 修复视频搜索结果在黑名单过滤前被写入数据副本，导致正常结果全部被过滤为空的问题。

## [1.3.2-beta.1] - 2026-09-02

### 新增

- 增加零遥测的本地诊断机制：正常使用不落盘，仅在故障时保存经过白名单过滤和脱敏的最小必要信息；用户可关闭、清空、审阅并手动导出。

### 变更

- 移除 Catcher、Logger 及其传递引入的远程错误服务依赖；诊断记录不会自动上传，最多保留 7 天且合计不超过 1 MiB。
- 升级后会清除可能包含旧字段的 `.pili_logs` 与 `.pili_player_logs`，后续统一使用结构化本地诊断。
- 网络请求统一返回显式的成功或失败结果，不再把超时、断网、异常状态码或错误响应伪装成成功数据。

### 修复

- 修复播放器控件初始化空值、播放器释放后的异步回调、播放时长类型错误，以及弹幕响应类型错误引发的异常。
- 修复视频作者信息缺失和影视详情字段不完整时的空值或渲染异常，并为加载失败提供可重试提示。
- 修复头像、封面等网络图片加载失败时污染错误日志的问题，统一显示本地占位图。
- 修复用户主页、投稿、合集、推荐、热门、分区、相关视频、收藏夹与私信等页面仍按旧格式读取网络结果导致的运行时类型异常。

## [1.3.1] - 2026-09-01

### 新增

- 将首页“番剧”升级为统一影视中心，支持番剧、国创、电影、电视剧、纪录片和综艺分类，以及更新时间、播放量、追番/追剧数和评分排序，并记忆上次选择。
- 重做影视中心界面，以紧凑续看卡、吸顶分类导航和三列海报提升移动端浏览与续播效率。
- 搜索结果增加独立“影视”标签；最近订阅会按内容类型显示“最近追番”或“最近追剧”。
- PGC 内容使用专用播放接口，支持官方提供的试看片段，并在试看结束后提供前往哔哩哔哩官方页面的入口。

### 优化

- 优化“关于”页缓存大小统计与清除流程，避免进入页面时同步遍历缓存目录造成卡顿，并防止清除过程中显示过期的缓存大小。

### 修复

- 更换文章与更新说明的 HTML 渲染组件，修复 Flutter 3.38.7 下依赖不兼容导致 Android 无法构建的问题，并保留原有图片缓存与画质处理。
- 修复大会员试看片段初始化时的类型异常和空外置音轨错误、首次播放失败后切换免费剧集仍停留在错误界面，以及切集失败时重复提示的问题。
- 修复部分 Android 设备播放高位深视频时只有声音、没有画面，以及 HDR 被误作普通最高画质、HEVC 被误标为 DVH1、切集后编码菜单状态残留的问题；硬解失败时会优先切换兼容视频源，无可用源时再从当前进度回退到软件解码。
- 修复番剧和影视搜索的加载骨架沿用视频卡片宽高比，在手机窄屏加载阶段发生底部布局溢出的问题。
- 对调试网络日志中的登录令牌、会话 Cookie 和 CSRF 参数进行脱敏，避免敏感凭证以明文输出。
- 统一推荐、搜索、动态、深链、历史和收藏中的影视跳转，按“明确剧集、观看进度、首集”的顺序选择剧集，避免错误回退。
- 修复影视连播跳过最后一集、切集失败丢失当前播放以及电影被直接阻止播放的问题；会员、付费、地区和 DRM 限制现在显示明确提示。
- 修正影视中心共享续看内容的范围说明，并根据剧集实际权益核验“大会员”角标，避免可免费播放内容被错误标记。
- 修复影视详情页重新进入时追番/追剧状态短暂错误或未同步的问题，并在状态未知和提交期间显示明确的加载反馈。
- 修复播放器底部按钮和中央双击绕过统一播放控制，并确保视频播放完成后可从头重新播放。
- 移除 Android 构建配置不完整的屏幕方向插件，改用 Flutter 官方接口与应用内方向通道。
- 修复评论折叠预览在空行、自动换行和富文本布局等边界下，内容被截断但不显示省略号的问题，并统一原始文字测量与富文本绘制的换行结果。
- 修复较新 Flutter 版本中读取系统动态主题颜色失败时触发 RangeError 的问题。

## [1.3.0] - 2026-08-04

### 新增

- Android 更新支持应用内发起系统后台下载、熄屏与网络恢复、SHA-256 完整性校验，并在完成后唤起系统安装确认。
- 手动检查更新时可分别选择正式版或测试版；测试版每次下载前都会提示稳定性、兼容性与无法直接降级的风险。

### 变更

- 启动时自动检查只主动提醒正式版，关于页和其它设置统一使用新的更新中心。
- GitHub Release 随 Android 安装包发布 `SHA256SUMS` 校验清单。

### 优化

- 优化 Android VPN 环境下的视频与直播缓冲策略，减少 Clash 等 VPNService 软件开启时的播放卡顿。
- 优化视频评论图片预览体验，打开全屏图片时自动暂停播放，并在关闭后按原播放状态恢复。

### 修复

- 修复检查更新时版本说明未解析 Markdown、长内容被截断且无法滑动查看的问题。
- 修复 VPN 或共享代理出口触发 GitHub API 限流时检查更新失败的问题。
- 修复评论折叠边界为空行时省略号仍可能未实际显示的问题。
- 修复部分 Android 设备从最近任务划掉应用后，播放与媒体服务仍继续运行的问题。
- 修复评论折叠边界恰好为空行时，后续内容被截断但不显示省略号的问题。
- 修复新视频播放器首次显示时完整控制栏短暂闪现的问题。
- 修复打开相关视频时进度条短暂显示上一个视频进度的问题。
- 修复从相关视频返回后原视频播放器被退出页面误释放、无法继续播放的问题。
- 修复播放器在窄屏、横屏分栏等布局下顶部与底部控制栏溢出的问题，并将底部放不下的次要操作收纳至“更多播放控制”。

## [1.2.3] - 2026-07-25

### 新增

- 首页推荐开启“保留上次内容”时，在新旧推荐之间显示“上次看到这里”分隔提示。

### 修复

- 修复 Android 平板设备启动画面图标因 Android 12 专用素材分辨率不足而模糊的问题。
- 修复 Android 冷启动或长时间后台后打开视频时偶发退出的问题，并增强播放器资源生命周期管理。
- 修复播放中画面与进度偶发回退、音频短时不同步的问题，并增加脱敏播放器诊断日志。

## [1.2.2] - 2026-07-22

### 重要说明

- Android application ID 与 iOS bundle ID 已改为 `io.github.gxwane.pilipalaz`，新应用会与 PiliPalaX 独立安装，不迁移旧应用数据。

### 变更

- 项目品牌由 PiliPalaX 更名为 PiliPalaZ，并同步更新根 Dart 包名、应用内文案、平台工程名称、仓库链接与发行产物名称。
- 更新 Android 与 iOS 应用图标及启动画面，采用彩色 P+Z 标识。

## [1.2.1] - 2026-07-20

### 重要说明

- `v1.2.0` 及更早版本的应用内更新接口仍指向旧仓库，可能无法自动发现本版本；本次需要从当前仓库的 GitHub Releases 手动下载安装，升级后将从当前仓库检查后续更新。

### 新增

- 在“关于”页面增加版本记录入口和 OpenAI Codex 协作维护声明。
- 增加项目身份、语义化版本通道与 Android ABI 安装包选择的契约测试。
- 建立根目录统一更新日志，并让发行流程直接从对应版本章节生成中文发行说明。

### 修复

- 重写应用更新判断，正确处理 `v` 前缀、构建元数据以及 `alpha`、`beta`、`rc`、稳定版的语义化版本顺序。
- 稳定版只接收稳定版更新；预发布版可以升级到后续预发布版或稳定版。
- Android 下载按当前 ABI 精确匹配并回退到通用 APK；没有合适资产时安全打开发行页面，iOS 始终打开发行页面。
- GitHub API 返回异常、标签无效或发行资产缺失时不再因强制取值而崩溃。
- 修复干净 CI 环境下根项目静态分析误包含 `packages/fl_pip/example` 独立示例而失败的问题。

### 变更

- 项目仓库、问题反馈、发行页面和更新接口统一指向 `gxwane/PiliPalaX`。
- 重写 README 与中英文商店文案，补充当前构建基线、下载说明、项目来源、非官方声明和人机协作维护说明。
- 移除已失效的 QQ 群、Telegram 群和 123 云盘入口。
- 统一 GitHub Validation 与 Release 工作流，明确 Android 架构产物和未签名 iOS 产物的命名规则。

## [1.2.0] - 2026-07-18

### 变更

- 构建基线升级到 Flutter 3.38.7、Dart 3.10.7、JDK 17、Android Gradle Plugin 8.11.1、Kotlin Gradle Plugin 2.2.20、Gradle 8.14 和 Android SDK 36。
- 升级网络、数据、UI、平台和媒体播放依赖；媒体播放栈更新到 `media_kit 1.2.6`、`media_kit_video 2.0.1` 与 `media_kit_libs_video 1.0.7`。
- 迁移屏幕方向插件以兼容 AGP 8，并现代化内置 `fl_pip` 插件。
- 统一 CI 使用 Flutter 3.38.7，并将依赖锁文件下载源恢复为 `pub.dev`。

### 修复

- 清理升级后产生的 Android、iOS、Flutter API 与依赖兼容性警告。

### 测试

- 增加 Cookie、弹幕协议、依赖、存储和主题的升级兼容性契约测试。

## [1.1.5] - 2026-07-10

### 修复

- 修复订阅页面 `RenderFlex` 溢出。
- 修复短哈希导致的 Hero 标签冲突。
- 番剧动态绕过不适用的 Wbi 签名，并处理 `4101132` 风控错误。
- 修复 `TabBarView` 快速滑动时跨页的问题。

## [1.1.4] - 2026-07-06

### 修复

- 为 Release 工作流补充 `contents: write` 权限，修复创建发行时的 403 错误。

## [1.1.3] - 2026-07-06

### 修复

- 将 `fl_pip` 内置到项目中，修复 iOS 端 FlutterEngine 强制解包导致的崩溃。

## [1.1.2] - 2026-07-06

### 变更

- 移除废弃插件并清理相关平台依赖。

### 修复

- 加固动态数据解析，兼容接口字段变化。

## [1.1.1] - 2026-07-06

### 新增

- 支持取消追番，并加入乐观更新交互。

### 修复

- 适配 Flutter 3.38 编译环境，并处理 AOT 编译、依赖约束、AndroidX AAR 元数据、NDK 和 compileSdk 兼容问题。
- 修复动态页 Hero 标签冲突、布局溢出、Wbi 风控和模型解析问题。
- 适配直播推荐接口结构变化以及 Opus 页面新的 `INITIAL_STATE` 数据结构。

### 变更

- 重构发行工作流，统一使用 Flutter 3.38.7，并避免单个平台失败取消其他平台构建。

## [1.0.19] - 2024-01-31

### 修复

- 修复视频 404、评论加载错误和 BV/AV 号转换问题。

### 优化

- 降低视频详情页内存占用。

## [1.0.18] - 2024-01-30

### 其他

- 历史发布记录未列出具体变更。

## [1.0.17] - 2024-01-25

### 新增

- 增加全屏隐藏进度条、动态投稿跳转、点击封面播放、弹幕发送标识和定时关闭。
- 增加推荐卡片拉黑 UP 主、首页标签编辑排序。

### 修复

- 修复搜索页连续跳转与空结果异常、评论链接解析、全屏状态栏背景、私信气泡位置和关注分组样式。
- 修复推荐数据重复、iOS 代理网络、双击切换播放状态无声、自定义倍速白屏和免登录 1080P 播放问题。

### 优化

- 优化 Web 推荐接口与观看数展示、首页和搜索跳转、弹幕资源、部分图片内存占用、双击返回退出和 Scheme 支持。

## [1.0.16] - 2024-01-02

### 新增

- Toast 背景支持透明度调节。

### 修复

- 修复 Web 推荐未显示“已关注”、UP 主动态页异常和关闭自动播放时的视频详情页异常。
- 视频暂停时不再意外触发画中画。

## [1.0.15] - 2024-01-01

### 新增

- 支持展示转发动态评论，并在推荐、热门和收藏视频中显示日期。

### 修复

- 修复全屏播放、评论区 @ 用户、登录状态崩溃、画中画意外触发和动态页标签样式问题。

### 优化

- 首页默认使用 Web 推荐，取消 iOS 路由切换动画，并在视频分享内容中增加 UP 主信息。

## [1.0.14] - 2023-12-25

> 此版本大部分内容由 @orz12 提供，感谢贡献。

### 修复

- 修复全屏弹幕消失、iOS 全屏切换时视频暂停、个人主页关注状态和视频合集 UI 问题。
- 修复媒体库底栏、个人主页动态加载、未登录访问个人主页、搜索标题转义和 iOS 崩溃问题。
- 修复消息页夜间模式、撤回消息处理和弹幕速度问题。

### 优化

- 优化全屏播放、弹幕加载、点赞投币逻辑以及进度条和播放时间渲染。

## [1.0.13] - 2023-12-17

### 新增

- 视频详情页增加稍后再看。
- 支持发送弹幕，感谢 @orz12。
- 增加消息展示、UP 主页获赞数与合集展示，以及视频 AI 总结开关。

### 修复

- 修复首页推荐、长按倍速和视频详情页网络异常。

### 优化

- 优化设置面板样式，感谢 @GuMengYu、@KoolShow。

## [1.0.12] - 2023-11-14

### 修复

- 修复 iOS 视频播放无声、六分钟后弹幕不显示和视频详情页网络异常。

## [1.0.11] - 2023-11-12

### 新增

- 适配原生媒体通知栏并增加视频主题图标，感谢 @Daydreamer-riri。
- 增加退出应用后自动画中画、UP 主分组管理和 Material 2 风格底栏。

### 修复

- 修复历史记录播放记忆、部分视频连播、倍速选择框返回手势与倍速显示问题。
- 修复评论计数和退出视频后仍有声音的问题。

### 优化

- 优化视频加载速度。

## [1.0.10] - 2023-10-16

### 修复

- 修复长按倍速结束后未恢复默认倍速。

## [1.0.9] - 2023-10-15

### 新增

- 增加自定义与默认倍速、历史记录与收藏夹搜索、历史记录多选删除和视频循环播放。
- 增加免登录 1080P、评论区视频链接跳转、UP 主分组和 UP 主投稿搜索。

### 修复

- 修复搜索标题乱码、屏幕帧率和动态页渲染问题。

### 优化

- 优化快进手势、视频简介链接匹配和全屏安全区域。

## [1.0.8] - 2023-09-17

### 新增

- 增加用户拉黑、GIF 保存和删除已看历史记录。

### 修复

- 修复弹幕数量偏少、弹幕屏蔽设置记忆、动态渲染、用户主页数据错乱和搜索推荐空白。
- 修复默认自动全屏时顶部操作栏丢失。

### 优化

- 优化全屏状态栏区域，并将图片保存到 PiliPala 文件夹。

## [1.0.7] - 2023-09-08

### 新增

- 增加弹幕设置与屏蔽、后台播放和 Android 画中画。

### 修复

- 修复动态页加载、网络异常空白、竖屏全屏状态栏和 iOS 代理请求异常。

### 优化

- 优化图片预览、全屏自动旋转，并为转发内容增加视频标题。

## [1.0.6] - 2023-09-02

### 新增

- 增加首页单列布局、推荐播放量与弹幕数展示，以及基础弹幕功能。
- 增加评论关键词搜索开关、热搜榜隐藏、自动全屏、快速收藏、双击快进/快退开关。
- 增加评论链接跳转、单条稍后再看移除和应用 Scheme 外链跳转。

### 修复

- 修复杜比/无损音频切换、收藏夹展示和搜索建议词问题。

### 优化

- 优化倍速选择、沉浸式导航栏、视频锁定、登录、图片预览、评论用户点击范围和关注/粉丝页面。
- 优化关闭自动播放时的播放器初始化逻辑。

## [1.0.5] - 2023-08-26

> 感谢酷友“无力感*”“斤斤计较呀”“Pseudopamine”的反馈与贡献。

### 新增

- 增加高刷新率、默认评论排序、默认动态类别、动态合集、同时观看人数和 iOS 路由切换效果。

### 修复

- 修复收藏夹翻页、首页搜索框频繁点击消失、评论排序切换空白和快速返回首页。
- 修复个人中心数据刷新、动态商品数据、大会员番剧切换和高画质编码匹配。

### 优化

- 优化倍速选择、播放器亮度记忆和对应架构 APK 下载。

## [1.0.4] - 2023-08-22

### 新增

- 增加热搜刷新、视频搜索排序与筛选、字体大小和主题色自定义，以及“课堂”类动态渲染。

### 修复

- 修复搜索联想富文本、部分动态点赞、默认视频解码格式、搜索词清理和动态评论加载问题。
- 修复动态页下拉刷新数据异常。

### 优化

- 优化部分页面样式并取消热搜词缓存。

## [1.0.3] - 2023-08-21

### 新增

- 增加底部播放进度条设置和复制图片链接。

### 修复

- 调整用户数据格式，并修复视频适配、无音频资源视频、评论图片点击和进度条拖动问题。

### 优化

- 优化页面空状态、异常状态、部分页面和图片预览样式。

## [1.0.2] - 2023-08-19

### 新增

- 增加自动检查更新、封面保存、动态跳转番剧、番剧播放记忆和一键清空稍后再看。

### 修复

- 修复分 P 切换时 CID 未更新、Cookie 存储和登录/退出问题。

### 优化

- 优化页面空状态与异常状态、退出登录提示、请求节流和全屏播放。

## [1.0.1] - 2023-08-17

### 变更

- 升级播放器依赖，增加 Android AV1 视频支持和视频全屏功能。

## [1.0.0] - 2023-08-17

### 新增

- 首次公开版本，包含直播、推荐、动态、投稿、番剧和视频播放。
- 支持播放器手势、画质/音质/解码格式选择、点赞/投币/收藏、关注与用户主页、评论、历史记录和稍后再看。

[Unreleased]: https://github.com/gxwane/PiliPalaZ/compare/v1.5.0-beta.6...HEAD
[1.5.0-beta.6]: https://github.com/gxwane/PiliPalaZ/compare/v1.5.0-beta.5...v1.5.0-beta.6
[1.5.0-beta.5]: https://github.com/gxwane/PiliPalaZ/compare/v1.5.0-beta.4...v1.5.0-beta.5
[1.5.0-beta.4]: https://github.com/gxwane/PiliPalaZ/compare/v1.5.0-beta.3...v1.5.0-beta.4
[1.5.0-beta.3]: https://github.com/gxwane/PiliPalaZ/compare/v1.5.0-beta.2...v1.5.0-beta.3
[1.5.0-beta.2]: https://github.com/gxwane/PiliPalaZ/compare/v1.5.0-beta.1...v1.5.0-beta.2
[1.5.0-beta.1]: https://github.com/gxwane/PiliPalaZ/compare/v1.4.0-beta.5...v1.5.0-beta.1
[1.3.2-beta.2]: https://github.com/gxwane/PiliPalaZ/compare/v1.3.2-beta.1...v1.3.2-beta.2
[1.3.2-beta.1]: https://github.com/gxwane/PiliPalaZ/compare/v1.3.1...v1.3.2-beta.1
[1.3.1]: https://github.com/gxwane/PiliPalaZ/compare/v1.3.0...v1.3.1
[1.3.0]: https://github.com/gxwane/PiliPalaZ/compare/v1.2.3...v1.3.0
[1.2.3]: https://github.com/gxwane/PiliPalaZ/compare/v1.2.2...v1.2.3
[1.2.2]: https://github.com/gxwane/PiliPalaZ/compare/v1.2.1...v1.2.2
[1.2.1]: https://github.com/gxwane/PiliPalaZ/compare/v1.2.0...v1.2.1
[1.2.0]: https://github.com/gxwane/PiliPalaZ/compare/v1.1.5...v1.2.0
[1.1.5]: https://github.com/gxwane/PiliPalaZ/compare/v1.1.4...v1.1.5
[1.1.4]: https://github.com/gxwane/PiliPalaZ/compare/v1.1.3...v1.1.4
[1.1.3]: https://github.com/gxwane/PiliPalaZ/compare/v1.1.2...v1.1.3
[1.1.2]: https://github.com/gxwane/PiliPalaZ/compare/v1.1.1...v1.1.2
[1.1.1]: https://github.com/gxwane/PiliPalaZ/releases/tag/v1.1.1
