class CmsPageModel {
  final int id;
  final String slug;
  final String title;
  final String? titleEn;
  final String section;
  final String? excerpt;
  final String? excerptEn;
  final String? body;
  final String? bodyEn;
  final String? titleAr;
  final String? excerptAr;
  final String? bodyAr;
  final String? ctaLabelAr;
  final String? imageUrl;
  final String? ctaLabel;
  final String? ctaUrl;
  final String? regionCode;
  final Map<String, dynamic> metadataJson;
  final int sortOrder;
  final bool isActive;

  const CmsPageModel({
    required this.id,
    required this.slug,
    required this.title,
    this.titleEn,
    required this.section,
    this.excerpt,
    this.excerptEn,
    this.body,
    this.bodyEn,
    this.titleAr,
    this.excerptAr,
    this.bodyAr,
    this.ctaLabelAr,
    this.imageUrl,
    this.ctaLabel,
    this.ctaUrl,
    this.regionCode,
    this.metadataJson = const {},
    this.sortOrder = 0,
    this.isActive = true,
  });

  factory CmsPageModel.fromJson(Map<String, dynamic> json) {
    return CmsPageModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      slug: (json['slug'] as String? ?? '').trim(),
      title: (json['title'] as String? ?? '').trim(),
      titleEn: (json['title_en'] as String?)?.trim(),
      section: (json['section'] as String? ?? '').trim(),
      excerpt: (json['excerpt'] as String?)?.trim(),
      excerptEn: (json['excerpt_en'] as String?)?.trim(),
      body: (json['body'] as String?)?.trim(),
      bodyEn: (json['body_en'] as String?)?.trim(),
      titleAr: (json['title_ar'] as String?)?.trim() ??
          _metadataText(json, 'title_ar'),
      excerptAr: (json['excerpt_ar'] as String?)?.trim() ??
          _metadataText(json, 'excerpt_ar'),
      bodyAr: (json['body_ar'] as String?)?.trim() ??
          _metadataText(json, 'body_ar'),
      ctaLabelAr: _metadataText(json, 'cta_label_ar'),
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

  static String? _metadataText(Map<String, dynamic> json, String key) {
    final metadata = (json['metadata_json'] as Map?)?.cast<String, dynamic>();
    final value = metadata?[key];
    final normalized = value?.toString().trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }
}
