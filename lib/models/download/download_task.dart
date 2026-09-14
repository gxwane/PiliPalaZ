/// 离线缓存下载任务模型。
///
/// 纯 Dart 领域模型，严禁引入 Flutter UI 依赖。
/// 通过 [toMap] / [DownloadTask.fromMap] 序列化到 Hive Box<Map>。
library;

/// 下载任务状态枚举。
enum DownloadTaskStatus {
  /// 排队等待中。
  pending,

  /// 正在下载（包含视频/音频/弹幕）。
  downloading,

  /// 用户手动暂停。
  paused,

  /// 全部完成已就绪。
  completed,

  /// 下载异常失败。
  failed;

  /// 从持久化字符串还原枚举值，未知值回退为 [pending]。
  static DownloadTaskStatus fromString(String? value) {
    if (value == null) return pending;
    return DownloadTaskStatus.values.asNameMap()[value] ?? pending;
  }
}

/// 离线缓存下载任务实体。
///
/// 主键 [id] = `${bvid}_$cid`，唯一标识一个分 P 的下载。
class DownloadTask {
  DownloadTask({
    required this.id,
    required this.bvid,
    required this.cid,
    this.aid,
    required this.title,
    required this.partTitle,
    required this.cover,
    required this.ownerName,
    required this.duration,
    required this.videoQuality,
    required this.videoQualityDesc,
    required this.videoCodec,
    required this.audioQuality,
    this.videoRelativePath,
    this.audioRelativePath,
    this.danmakuRelativePath,
    this.coverRelativePath,
    this.status = DownloadTaskStatus.pending,
    this.totalBytes = 0,
    this.downloadedBytes = 0,
    this.downloadSpeed = 0,
    this.errorMessage,
    DateTime? createdAt,
    this.completedAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// 工厂构造：从视频元数据快速创建待下载任务。
  factory DownloadTask.create({
    required String bvid,
    required int cid,
    int? aid,
    required String title,
    String partTitle = '',
    required String cover,
    required String ownerName,
    required int duration,
    required int videoQuality,
    required String videoQualityDesc,
    required String videoCodec,
    required int audioQuality,
  }) {
    return DownloadTask(
      id: '${bvid}_$cid',
      bvid: bvid,
      cid: cid,
      aid: aid,
      title: title,
      partTitle: partTitle,
      cover: cover,
      ownerName: ownerName,
      duration: duration,
      videoQuality: videoQuality,
      videoQualityDesc: videoQualityDesc,
      videoCodec: videoCodec,
      audioQuality: audioQuality,
    );
  }

  // ── 唯一标识 ──

  /// 主键：`${bvid}_$cid`。
  final String id;

  // ── 视频元数据 ──

  final String bvid;
  final int cid;
  final int? aid;

  /// 视频标题。
  final String title;

  /// 分 P / 剧集标题。
  final String partTitle;

  /// 封面网络图 URL。
  final String cover;

  /// UP 主名称。
  final String ownerName;

  /// 时长（秒）。
  final int duration;

  // ── 流规格 ──

  /// 视频画质编号（如 80 → 1080P）。
  final int videoQuality;

  /// 画质文案（如 "1080P 高清"）。
  final String videoQualityDesc;

  /// 编码格式（如 "avc1.640032"）。
  final String videoCodec;

  /// 音频音质编号（如 30280 → 192K）。
  final int audioQuality;

  // ── 本地存储相对路径 ──

  /// 视频文件相对路径，如 `bvid_cid/video.m4s`。
  String? videoRelativePath;

  /// 音频文件相对路径，如 `bvid_cid/audio.m4s`。
  String? audioRelativePath;

  /// 弹幕文件相对路径，如 `bvid_cid/danmaku.bin`。
  String? danmakuRelativePath;

  /// 封面缓存相对路径。
  String? coverRelativePath;

  // ── 实时下载状态 ──

  DownloadTaskStatus status;

  /// 总字节大小。
  int totalBytes;

  /// 已下载字节大小。
  int downloadedBytes;

  /// 瞬时下载速率（bytes/s），仅内存态，不持久化。
  int downloadSpeed;

  /// 失败原因。
  String? errorMessage;

  /// 创建时间。
  final DateTime createdAt;

  /// 完成时间。
  DateTime? completedAt;

  // ── 派生属性 ──

  /// 下载进度 0.0 ~ 1.0。
  double get progress =>
      totalBytes > 0 ? (downloadedBytes / totalBytes).clamp(0.0, 1.0) : 0.0;

  /// 任务是否已终态（完成或失败）。
  bool get isTerminal =>
      status == DownloadTaskStatus.completed ||
      status == DownloadTaskStatus.failed;

  /// 任务是否可恢复（暂停或失败）。
  bool get isResumable =>
      status == DownloadTaskStatus.paused ||
      status == DownloadTaskStatus.failed;

  // ── 序列化 ──

  /// 序列化为 Map 用于 Hive 持久化。
  ///
  /// [downloadSpeed] 为瞬态字段，不写入持久层。
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'bvid': bvid,
      'cid': cid,
      'aid': aid,
      'title': title,
      'partTitle': partTitle,
      'cover': cover,
      'ownerName': ownerName,
      'duration': duration,
      'videoQuality': videoQuality,
      'videoQualityDesc': videoQualityDesc,
      'videoCodec': videoCodec,
      'audioQuality': audioQuality,
      'videoRelativePath': videoRelativePath,
      'audioRelativePath': audioRelativePath,
      'danmakuRelativePath': danmakuRelativePath,
      'coverRelativePath': coverRelativePath,
      'status': status.name,
      'totalBytes': totalBytes,
      'downloadedBytes': downloadedBytes,
      'errorMessage': errorMessage,
      'createdAt': createdAt.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
    };
  }

  /// 从持久化 Map 反序列化。
  factory DownloadTask.fromMap(Map<dynamic, dynamic> map) {
    return DownloadTask(
      id: map['id'] as String,
      bvid: map['bvid'] as String,
      cid: map['cid'] as int,
      aid: map['aid'] as int?,
      title: (map['title'] as String?) ?? '',
      partTitle: (map['partTitle'] as String?) ?? '',
      cover: (map['cover'] as String?) ?? '',
      ownerName: (map['ownerName'] as String?) ?? '',
      duration: (map['duration'] as int?) ?? 0,
      videoQuality: map['videoQuality'] as int,
      videoQualityDesc: (map['videoQualityDesc'] as String?) ?? '',
      videoCodec: (map['videoCodec'] as String?) ?? '',
      audioQuality: (map['audioQuality'] as int?) ?? 30280,
      videoRelativePath: map['videoRelativePath'] as String?,
      audioRelativePath: map['audioRelativePath'] as String?,
      danmakuRelativePath: map['danmakuRelativePath'] as String?,
      coverRelativePath: map['coverRelativePath'] as String?,
      status: DownloadTaskStatus.fromString(map['status'] as String?),
      totalBytes: (map['totalBytes'] as int?) ?? 0,
      downloadedBytes: (map['downloadedBytes'] as int?) ?? 0,
      errorMessage: map['errorMessage'] as String?,
      createdAt: DateTime.tryParse(map['createdAt'] as String? ?? ''),
      completedAt: map['completedAt'] != null
          ? DateTime.tryParse(map['completedAt'] as String)
          : null,
    );
  }

  /// 不可变拷贝，用于安全状态变迁。
  DownloadTask copyWith({
    String? videoRelativePath,
    String? audioRelativePath,
    String? danmakuRelativePath,
    String? coverRelativePath,
    DownloadTaskStatus? status,
    int? totalBytes,
    int? downloadedBytes,
    int? downloadSpeed,
    String? errorMessage,
    DateTime? completedAt,
  }) {
    return DownloadTask(
      id: id,
      bvid: bvid,
      cid: cid,
      aid: aid,
      title: title,
      partTitle: partTitle,
      cover: cover,
      ownerName: ownerName,
      duration: duration,
      videoQuality: videoQuality,
      videoQualityDesc: videoQualityDesc,
      videoCodec: videoCodec,
      audioQuality: audioQuality,
      videoRelativePath: videoRelativePath ?? this.videoRelativePath,
      audioRelativePath: audioRelativePath ?? this.audioRelativePath,
      danmakuRelativePath: danmakuRelativePath ?? this.danmakuRelativePath,
      coverRelativePath: coverRelativePath ?? this.coverRelativePath,
      status: status ?? this.status,
      totalBytes: totalBytes ?? this.totalBytes,
      downloadedBytes: downloadedBytes ?? this.downloadedBytes,
      downloadSpeed: downloadSpeed ?? this.downloadSpeed,
      errorMessage: errorMessage,
      createdAt: createdAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is DownloadTask && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'DownloadTask($id, ${status.name}, $progress, $videoQualityDesc)';
}
