class LatestDataModel {
  const LatestDataModel({
    this.url,
    this.htmlUrl,
    this.tagName,
    this.createdAt,
    this.assets = const <AssetItem>[],
    this.body = '',
    this.bodyHtml = '',
    this.prerelease = false,
    this.draft = false,
  });

  final String? url;
  final String? htmlUrl;
  final String? tagName;
  final String? createdAt;
  final List<AssetItem> assets;
  final String body;
  final String bodyHtml;
  final bool prerelease;
  final bool draft;

  factory LatestDataModel.fromJson(Map<String, dynamic> json) {
    final rawAssets = json['assets'];
    return LatestDataModel(
      url: json['url'] as String?,
      htmlUrl: json['html_url'] as String?,
      tagName: json['tag_name'] as String?,
      createdAt: json['created_at'] as String?,
      assets: rawAssets is List
          ? rawAssets
                .whereType<Map<String, dynamic>>()
                .map(AssetItem.fromJson)
                .toList(growable: false)
          : const <AssetItem>[],
      body: json['body'] as String? ?? '',
      prerelease: json['prerelease'] as bool? ?? false,
      draft: json['draft'] as bool? ?? false,
    );
  }
}

class AssetItem {
  const AssetItem({
    this.url,
    this.name,
    this.size,
    this.downloadCount,
    this.downloadUrl,
  });

  final String? url;
  final String? name;
  final int? size;
  final int? downloadCount;
  final String? downloadUrl;

  factory AssetItem.fromJson(Map<String, dynamic> json) {
    return AssetItem(
      url: json['url'] as String?,
      name: json['name'] as String?,
      size: json['size'] as int?,
      downloadCount: json['download_count'] as int?,
      downloadUrl: json['browser_download_url'] as String?,
    );
  }
}
