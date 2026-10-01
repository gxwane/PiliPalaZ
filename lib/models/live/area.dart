class LiveAreaItemModel {
  final int id;
  final String name;
  final String? icon;

  const LiveAreaItemModel({required this.id, required this.name, this.icon});

  factory LiveAreaItemModel.fromJson(Map<String, dynamic> json) {
    final id = json['id'] is int
        ? json['id'] as int
        : (int.tryParse(json['id']?.toString() ?? '') ?? 0);
    return LiveAreaItemModel(
      id: id,
      name: json['name']?.toString() ?? '',
      icon: json['icon']?.toString() ?? json['pic']?.toString(),
    );
  }

  static List<LiveAreaItemModel> get defaultAreas => const [
    LiveAreaItemModel(id: 0, name: '推荐'),
    LiveAreaItemModel(id: 2, name: '网游'),
    LiveAreaItemModel(id: 3, name: '手游'),
    LiveAreaItemModel(id: 6, name: '单机'),
    LiveAreaItemModel(id: 9, name: '虚拟主播'),
    LiveAreaItemModel(id: 1, name: '娱乐'),
    LiveAreaItemModel(id: 5, name: '电台'),
    LiveAreaItemModel(id: 10, name: '生活'),
    LiveAreaItemModel(id: 11, name: '知识'),
  ];
}
