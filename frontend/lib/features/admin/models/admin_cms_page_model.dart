class AdminCmsPageModel {
  final int id;
  final String slug;
  final String title;
  final String section;
  final String? excerpt;
  final String? body;
  final String? imageUrl;
  final String? ctaLabel;
  final String? ctaUrl;
  final Map<String, dynamic> metadataJson;
  final int sortOrder;
  final bool isActive;

  const AdminCmsPageModel({
    required this.id,
    required this.slug,
    required this.title,
    required this.section,
    this.excerpt,
    this.body,
    this.imageUrl,
    this.ctaLabel,
    this.ctaUrl,
    this.metadataJson = const {},
    this.sortOrder = 0,
    this.isActive = true,
  });

  factory AdminCmsPageModel.fromJson(Map<String, dynamic> json) {
    return AdminCmsPageModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      slug: (json['slug'] as String? ?? '').trim(),
      title: (json['title'] as String? ?? '').trim(),
      section: (json['section'] as String? ?? '').trim(),
      excerpt: (json['excerpt'] as String?)?.trim(),
      body: (json['body'] as String?)?.trim(),
      imageUrl: (json['image_url'] as String?)?.trim(),
      ctaLabel: (json['cta_label'] as String?)?.trim(),
      ctaUrl: (json['cta_url'] as String?)?.trim(),
      metadataJson: (json['metadata_json'] as Map?)?.cast<String, dynamic>() ??
          const <String, dynamic>{},
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      isActive: json['is_active'] as bool? ?? true,
    );
  }
}
