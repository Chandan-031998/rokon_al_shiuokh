class AdminCmsPageModel {
  final int id;
  final String slug;
  final String title;
  final String? titleEn;
  final String? titleAr;
  final String section;
  final String? excerpt;
  final String? excerptEn;
  final String? excerptAr;
  final String? body;
  final String? bodyEn;
  final String? bodyAr;
  final String? imageUrl;
  final String? ctaLabel;
  final String? ctaUrl;
  final String? regionCode;
  final Map<String, dynamic> metadataJson;
  final int sortOrder;
  final bool isActive;

  const AdminCmsPageModel({
    required this.id,
    required this.slug,
    required this.title,
    this.titleEn,
    this.titleAr,
    required this.section,
    this.excerpt,
    this.excerptEn,
    this.excerptAr,
    this.body,
    this.bodyEn,
    this.bodyAr,
    this.imageUrl,
    this.ctaLabel,
    this.ctaUrl,
    this.regionCode,
    this.metadataJson = const {},
    this.sortOrder = 0,
    this.isActive = true,
  });

  factory AdminCmsPageModel.fromJson(Map<String, dynamic> json) {
    return AdminCmsPageModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      slug: (json['slug'] as String? ?? '').trim(),
      title: (json['title'] as String? ?? '').trim(),
      titleEn: (json['title_en'] as String?)?.trim(),
      titleAr: (json['title_ar'] as String?)?.trim(),
      section: (json['section'] as String? ?? '').trim(),
      excerpt: (json['excerpt'] as String?)?.trim(),
      excerptEn: (json['excerpt_en'] as String?)?.trim(),
      excerptAr: (json['excerpt_ar'] as String?)?.trim(),
      body: (json['body'] as String?)?.trim(),
      bodyEn: (json['body_en'] as String?)?.trim(),
      bodyAr: (json['body_ar'] as String?)?.trim(),
      imageUrl: (json['image_url'] as String?)?.trim(),
      ctaLabel: (json['cta_label'] as String?)?.trim(),
      ctaUrl: (json['cta_url'] as String?)?.trim(),
      regionCode: (json['region_code'] as String?)?.trim(),
      metadataJson: (json['metadata_json'] as Map?)?.cast<String, dynamic>() ??
          const <String, dynamic>{},
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      isActive: json['is_active'] as bool? ?? true,
    );
  }
}
