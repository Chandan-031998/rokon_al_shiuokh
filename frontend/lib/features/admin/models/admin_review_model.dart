class AdminReviewModel {
  final int id;
  final int productId;
  final String? productName;
  final int userId;
  final String? customerName;
  final String? customerEmail;
  final int? orderId;
  final int rating;
  final String? title;
  final String? body;
  final String moderationStatus;
  final String? moderationNotes;
  final bool isVerifiedPurchase;
  final String? createdAt;

  const AdminReviewModel({
    required this.id,
    required this.productId,
    this.productName,
    required this.userId,
    this.customerName,
    this.customerEmail,
    this.orderId,
    required this.rating,
    this.title,
    this.body,
    required this.moderationStatus,
    this.moderationNotes,
    required this.isVerifiedPurchase,
    this.createdAt,
  });

  factory AdminReviewModel.fromJson(Map<String, dynamic> json) {
    return AdminReviewModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      productId: (json['product_id'] as num?)?.toInt() ?? 0,
      productName: (json['product_name'] as String?)?.trim(),
      userId: (json['user_id'] as num?)?.toInt() ?? 0,
      customerName: (json['customer_name'] as String?)?.trim(),
      customerEmail: (json['customer_email'] as String?)?.trim(),
      orderId: (json['order_id'] as num?)?.toInt(),
      rating: (json['rating'] as num?)?.toInt() ?? 0,
      title: (json['title'] as String?)?.trim(),
      body: (json['body'] as String?)?.trim(),
      moderationStatus: (json['moderation_status'] as String? ?? '').trim(),
      moderationNotes: (json['moderation_notes'] as String?)?.trim(),
      isVerifiedPurchase: json['is_verified_purchase'] as bool? ?? false,
      createdAt: (json['created_at'] as String?)?.trim(),
    );
  }
}
