enum DiagnosticFailureKind {
  flutterFramework,
  platformUnhandled,
  videoPlaybackInitialization,
  playerSetDataSource,
  playerNativeFailure,
  hardwareDecodeSourceRecovery,
  hardwareDecodeFallback,
  nativePlayerRelease,
}

extension DiagnosticFailureKindLabel on DiagnosticFailureKind {
  String get label => switch (this) {
    DiagnosticFailureKind.flutterFramework => 'Flutter 界面异常',
    DiagnosticFailureKind.platformUnhandled => '未处理异步异常',
    DiagnosticFailureKind.videoPlaybackInitialization => '播放初始化失败',
    DiagnosticFailureKind.playerSetDataSource => '播放器载入失败',
    DiagnosticFailureKind.playerNativeFailure => '原生播放器失败',
    DiagnosticFailureKind.hardwareDecodeSourceRecovery => '硬解兼容源恢复失败',
    DiagnosticFailureKind.hardwareDecodeFallback => '软件解码回退失败',
    DiagnosticFailureKind.nativePlayerRelease => '播放器释放失败',
  };
}

class DiagnosticEnvironment {
  const DiagnosticEnvironment({
    required this.appVersion,
    required this.buildNumber,
    required this.platform,
    required this.osVersion,
    this.manufacturer,
    this.model,
    this.supportedAbis = const <String>[],
  });

  final String appVersion;
  final String buildNumber;
  final String platform;
  final String osVersion;
  final String? manufacturer;
  final String? model;
  final List<String> supportedAbis;

  Map<String, Object?> toJson() => <String, Object?>{
    'appVersion': appVersion,
    'buildNumber': buildNumber,
    'platform': platform,
    'osVersion': osVersion,
    if (manufacturer != null) 'manufacturer': manufacturer,
    if (model != null) 'model': model,
    if (supportedAbis.isNotEmpty) 'supportedAbis': supportedAbis,
  };

  factory DiagnosticEnvironment.fromJson(Map<String, dynamic> json) {
    return DiagnosticEnvironment(
      appVersion: json['appVersion']?.toString() ?? '',
      buildNumber: json['buildNumber']?.toString() ?? '',
      platform: json['platform']?.toString() ?? '',
      osVersion: json['osVersion']?.toString() ?? '',
      manufacturer: json['manufacturer']?.toString(),
      model: json['model']?.toString(),
      supportedAbis:
          (json['supportedAbis'] as List<dynamic>?)
              ?.map((item) => item.toString())
              .toList(growable: false) ??
          const <String>[],
    );
  }
}

class DiagnosticBreadcrumb {
  const DiagnosticBreadcrumb({
    required this.timestamp,
    required this.event,
    this.details = const <String, Object?>{},
  });

  final DateTime timestamp;
  final String event;
  final Map<String, Object?> details;

  Map<String, Object?> toJson() => <String, Object?>{
    'timestamp': timestamp.toUtc().toIso8601String(),
    'event': event,
    if (details.isNotEmpty) 'details': details,
  };

  factory DiagnosticBreadcrumb.fromJson(Map<String, dynamic> json) {
    final rawDetails = json['details'];
    return DiagnosticBreadcrumb(
      timestamp: DateTime.parse(json['timestamp'].toString()).toUtc(),
      event: json['event']?.toString() ?? '',
      details: rawDetails is Map
          ? rawDetails.map<String, Object?>(
              (key, value) => MapEntry(key.toString(), value),
            )
          : const <String, Object?>{},
    );
  }
}

class DiagnosticRecord {
  const DiagnosticRecord({
    required this.timestamp,
    required this.kind,
    required this.errorType,
    required this.message,
    required this.stackTrace,
    required this.environment,
    this.breadcrumbs = const <DiagnosticBreadcrumb>[],
  });

  static const int currentSchemaVersion = 1;

  final DateTime timestamp;
  final DiagnosticFailureKind kind;
  final String errorType;
  final String message;
  final String stackTrace;
  final DiagnosticEnvironment environment;
  final List<DiagnosticBreadcrumb> breadcrumbs;

  Map<String, Object?> toJson() => <String, Object?>{
    'schemaVersion': currentSchemaVersion,
    'timestamp': timestamp.toUtc().toIso8601String(),
    'kind': kind.name,
    'errorType': errorType,
    'message': message,
    'stackTrace': stackTrace,
    'environment': environment.toJson(),
    if (breadcrumbs.isNotEmpty)
      'breadcrumbs': breadcrumbs.map((item) => item.toJson()).toList(),
  };

  factory DiagnosticRecord.fromJson(Map<String, dynamic> json) {
    if (json['schemaVersion'] != currentSchemaVersion) {
      throw const FormatException('Unsupported diagnostic schema');
    }
    final environment = json['environment'];
    if (environment is! Map) {
      throw const FormatException('Missing diagnostic environment');
    }
    final kindName = json['kind']?.toString();
    final kind = DiagnosticFailureKind.values.where(
      (item) => item.name == kindName,
    );
    if (kind.isEmpty) throw const FormatException('Unknown diagnostic kind');
    final rawBreadcrumbs = json['breadcrumbs'];
    return DiagnosticRecord(
      timestamp: DateTime.parse(json['timestamp'].toString()).toUtc(),
      kind: kind.first,
      errorType: json['errorType']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      stackTrace: json['stackTrace']?.toString() ?? '',
      environment: DiagnosticEnvironment.fromJson(
        environment.map<String, dynamic>(
          (key, value) => MapEntry(key.toString(), value),
        ),
      ),
      breadcrumbs: rawBreadcrumbs is List
          ? rawBreadcrumbs
                .whereType<Map>()
                .map(
                  (item) => DiagnosticBreadcrumb.fromJson(
                    item.map<String, dynamic>(
                      (key, value) => MapEntry(key.toString(), value),
                    ),
                  ),
                )
                .toList(growable: false)
          : const <DiagnosticBreadcrumb>[],
    );
  }
}
