class BannerModel {
  final int? id;
  final String imageUrl;
  final String? title;
  final String? link;
  final bool active;

  BannerModel({
    this.id,
    required this.imageUrl,
    this.title,
    this.link,
    this.active = true,
  });

  factory BannerModel.fromJson(Map<String, dynamic> json) {
    return BannerModel(
      id: json['id'] as int?,
      imageUrl: json['image_url'] as String,
      title: json['title'] as String?,
      link: json['link'] as String?,
      active: json['active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'image_url': imageUrl,
      if (title != null) 'title': title,
      if (link != null) 'link': link,
      'active': active,
    };
  }

  BannerModel copyWith({
    int? id,
    String? imageUrl,
    String? title,
    String? link,
    bool? active,
  }) {
    return BannerModel(
      id: id ?? this.id,
      imageUrl: imageUrl ?? this.imageUrl,
      title: title ?? this.title,
      link: link ?? this.link,
      active: active ?? this.active,
    );
  }
}
