class AttractionPhoto {
  AttractionPhoto({
    required this.title,
    required this.imageUrl,
    required this.source,
    required this.poiName,
    required this.poiKinds,
  });

  final String title;
  final String imageUrl;
  final String source;
  final String poiName;
  final String poiKinds;

  factory AttractionPhoto.fromJson(Map<String, dynamic> json) {
    final poi = Map<String, dynamic>.from(json['poi'] ?? {});
    return AttractionPhoto(
      title: (json['title'] ?? '').toString(),
      imageUrl: (json['image'] ?? '').toString(),
      source: (json['source'] ?? '').toString(),
      poiName: (poi['name'] ?? '').toString(),
      poiKinds: (poi['kinds'] ?? '').toString(),
    );
  }
}
