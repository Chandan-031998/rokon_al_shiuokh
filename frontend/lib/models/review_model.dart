class ReviewModel {
  final int id;
  final int userId;
  final int productId;
  final int? orderId;
  final int rating;
  final String? title;
  final String? body;
  final String moderationStatus;
  final bool isVerifiedPurchase;
  final String? createdAt;

  const ReviewModel({
    required this.id,
    required this.userId,
    required this.productId,
    this.orderId,
    required this.rating,
    this.title,
    this.body,
    required this.moderationStatus,
    required this.isVerifiedPurchase,
    this.createdAt,
  });

  factory ReviewModel.fromJson(Map<String, dynamic> json) {
    return ReviewModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      userId: (json['user_id'] as num?)?.toInt() ?? 0,
      productId: (json['product_id'] as num?)?.toInt() ?? 0,
      orderId: (json['order_id'] as num?)?.toInt(),
      rating: (json['rating'] as num?)?.toInt() ?? 0,
      title: (json['title'] as String?)?.trim(),
      body: (json['body'] as String?)?.trim(),
      moderationStatus: (json['moderation_status'] as String? ?? '').trim(),
      isVerifiedPurchase: json['is_verified_purchase'] as bool? ?? false,
      createdAt: (json['created_at'] as String?)?.trim(),
    );
  }
}
