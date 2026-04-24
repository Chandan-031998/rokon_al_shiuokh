import 'product_image_model.dart';

class ProductRegionPriceModel {
  final String regionCode;
  final String currencyCode;
  final double price;
  final double? salePrice;
  final bool isVisible;

  const ProductRegionPriceModel({
    required this.regionCode,
    required this.currencyCode,
    required this.price,
    this.salePrice,
    this.isVisible = true,
  });

  factory ProductRegionPriceModel.fromJson(Map<String, dynamic> json) {
    return ProductRegionPriceModel(
      regionCode: (json['region_code'] as String? ?? '').trim().toLowerCase(),
      currencyCode:
          (json['currency_code'] as String? ?? '').trim().toUpperCase(),
      price: (json['price'] as num?)?.toDouble() ?? 0,
      salePrice: (json['sale_price'] as num?)?.toDouble(),
      isVisible: json['is_visible'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'region_code': regionCode,
      'currency_code': currencyCode,
      'price': price,
      'sale_price': salePrice,
      'is_visible': isVisible,
    };
  }
}

class ProductBranchAvailabilityModel {
  final int branchId;
  final String? branchName;
  final bool isAvailable;

  const ProductBranchAvailabilityModel({
    required this.branchId,
    this.branchName,
    this.isAvailable = true,
  });

  factory ProductBranchAvailabilityModel.fromJson(Map<String, dynamic> json) {
    return ProductBranchAvailabilityModel(
      branchId: (json['branch_id'] as num?)?.toInt() ?? 0,
      branchName: (json['branch_name'] as String?)?.trim(),
      isAvailable: json['is_available'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'branch_id': branchId,
      'branch_name': branchName,
      'is_available': isAvailable,
    };
  }
}

class ProductModel {
  final int id;
  final String name;
  final String? nameEn;
  final double price;
  final int categoryId;
  final int? branchId;
  final String? nameAr;
  final String? imageUrl;
  final String? primaryImageUrl;
  final List<ProductImageModel> images;
  final String? description;
  final String? shortDescription;
  final String? shortDescriptionEn;
  final String? shortDescriptionAr;
  final String? fullDescription;
  final String? fullDescriptionEn;
  final String? fullDescriptionAr;
  final String? sku;
  final int stockQty;
  final String? packSize;
  final double? salePrice;
  final String? tags;
  final String? searchKeywords;
  final String? searchSynonyms;
  final bool isFeatured;
  final bool isHiddenFromSearch;
  final bool isActive;
  final String? categoryName;
  final String? categoryNameEn;
  final String? categoryNameAr;
  final String? branchName;
  final List<ProductBranchAvailabilityModel> branchAvailability;
  final List<int> availableBranchIds;
  final List<ProductRegionPriceModel> regionPrices;
  final double averageRating;
  final int reviewCount;
  final Map<String, int> ratingDistribution;
  final DateTime? createdAt;

  const ProductModel({
    required this.id,
    required this.name,
    this.nameEn,
    required this.price,
    required this.categoryId,
    this.branchId,
    this.nameAr,
    this.imageUrl,
    this.primaryImageUrl,
    this.images = const <ProductImageModel>[],
    this.description,
    this.shortDescription,
    this.shortDescriptionEn,
    this.shortDescriptionAr,
    this.fullDescription,
    this.fullDescriptionEn,
    this.fullDescriptionAr,
    this.sku,
    this.stockQty = 0,
    this.packSize,
    this.salePrice,
    this.tags,
    this.searchKeywords,
    this.searchSynonyms,
    this.isFeatured = false,
    this.isHiddenFromSearch = false,
    this.isActive = true,
    this.categoryName,
    this.categoryNameEn,
    this.categoryNameAr,
    this.branchName,
    this.branchAvailability = const <ProductBranchAvailabilityModel>[],
    this.availableBranchIds = const <int>[],
    this.regionPrices = const <ProductRegionPriceModel>[],
    this.averageRating = 0,
    this.reviewCount = 0,
    this.ratingDistribution = const <String, int>{},
    this.createdAt,
  });

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    final rawImages = (json['images'] as List? ?? const <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(ProductImageModel.fromJson)
        .where((image) => image.imageUrl.isNotEmpty)
        .toList()
      ..sort((left, right) {
        final orderCompare = left.sortOrder.compareTo(right.sortOrder);
        if (orderCompare != 0) {
          return orderCompare;
        }
        return left.id.compareTo(right.id);
      });
    final normalizedPrimaryImageUrl =
        _normalizeImageUrl(json['primary_image_url'] as String?) ??
            _normalizeImageUrl(json['image_url'] as String?) ??
            (rawImages.isNotEmpty ? rawImages.first.imageUrl : null);

    return ProductModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: (json['name'] as String? ?? '').trim(),
      nameEn: (json['name_en'] as String?)?.trim(),
      price: (json['price'] as num?)?.toDouble() ?? 0,
      categoryId: (json['category_id'] as num?)?.toInt() ?? 0,
      branchId: (json['branch_id'] as num?)?.toInt(),
      nameAr: json['name_ar'] as String?,
      imageUrl: normalizedPrimaryImageUrl,
      primaryImageUrl: normalizedPrimaryImageUrl,
      images: rawImages,
      description: json['description'] as String?,
      shortDescription: (json['short_description'] as String?)?.trim(),
      shortDescriptionEn: (json['short_description_en'] as String?)?.trim(),
      shortDescriptionAr: (json['short_description_ar'] as String?)?.trim(),
      fullDescription: (json['full_description'] as String?)?.trim(),
      fullDescriptionEn: (json['full_description_en'] as String?)?.trim(),
      fullDescriptionAr: (json['full_description_ar'] as String?)?.trim(),
      sku: json['sku'] as String?,
      stockQty: (json['stock_qty'] as num?)?.toInt() ?? 0,
      packSize: (json['pack_size'] as String?)?.trim(),
      salePrice: (json['sale_price'] as num?)?.toDouble(),
      tags: (json['tags'] as String?)?.trim(),
      searchKeywords: (json['search_keywords'] as String?)?.trim(),
      searchSynonyms: (json['search_synonyms'] as String?)?.trim(),
      isFeatured: json['is_featured'] as bool? ?? false,
      isHiddenFromSearch: json['is_hidden_from_search'] as bool? ?? false,
      isActive: json['is_active'] as bool? ?? true,
      categoryName: (json['category_name'] as String?)?.trim(),
      categoryNameEn: (json['category_name_en'] as String?)?.trim(),
      categoryNameAr: (json['category_name_ar'] as String?)?.trim(),
      branchName: (json['branch_name'] as String?)?.trim(),
      branchAvailability:
          (json['branch_availability'] as List? ?? const <dynamic>[])
              .whereType<Map<String, dynamic>>()
              .map(ProductBranchAvailabilityModel.fromJson)
              .toList(),
      availableBranchIds:
          (json['available_branch_ids'] as List? ?? const <dynamic>[])
              .map((value) =>
                  value is num ? value.toInt() : int.tryParse('$value') ?? 0)
              .where((value) => value > 0)
              .toList(),
      regionPrices: (json['region_prices'] as List? ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(ProductRegionPriceModel.fromJson)
          .toList(),
      averageRating: (json['average_rating'] as num?)?.toDouble() ?? 0,
      reviewCount: (json['review_count'] as num?)?.toInt() ?? 0,
      ratingDistribution:
          (json['rating_distribution'] as Map?)?.cast<String, dynamic>().map(
                    (key, value) => MapEntry(
                      key,
                      (value as num?)?.toInt() ?? 0,
                    ),
                  ) ??
              const <String, int>{},
      createdAt:
          DateTime.tryParse((json['created_at'] as String? ?? '').trim()),
    );
  }
}

String? _normalizeImageUrl(String? rawUrl) {
  final value = rawUrl?.trim();
  if (value == null || value.isEmpty) {
    return null;
  }

  return value;
}
