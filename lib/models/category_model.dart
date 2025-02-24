class CategoryModel {
  final int id;
  final String name;
  final int order;
  final bool active;
  final int allowedLevel;
  final String? iconUrl;

  CategoryModel({
    required this.id,
    required this.name,
    required this.order,
    required this.active,
    required this.allowedLevel,
    this.iconUrl,
  });

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    return CategoryModel(
      id: json['id'] as int,
      name: json['name'] as String,
      order: json['order'] as int,
      active: json['active'] as bool,
      allowedLevel: json['allowed_level'] as int? ?? 10,
      iconUrl: json['icon_url'] as String?,
    );
  }
}
