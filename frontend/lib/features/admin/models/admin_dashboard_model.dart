import '../../../models/order_model.dart';

class DeliveryStatusSummary {
  final String status;
  final int count;

  const DeliveryStatusSummary({
    required this.status,
    required this.count,
  });

  factory DeliveryStatusSummary.fromJson(Map<String, dynamic> json) {
    return DeliveryStatusSummary(
      status: (json['status'] as String? ?? '').trim(),
      count: (json['count'] as num?)?.toInt() ?? 0,
    );
  }
}

class AdminDashboardSummary {
  final int totalProducts;
  final int totalCategories;
  final int totalOrders;
  final int pendingOrders;
  final int totalCustomers;
  final int totalBranches;
  final List<DeliveryStatusSummary> deliveryStatusSummary;
  final List<OrderModel> recentOrders;

  const AdminDashboardSummary({
    required this.totalProducts,
    required this.totalCategories,
    required this.totalOrders,
    required this.pendingOrders,
    required this.totalCustomers,
    required this.totalBranches,
    required this.deliveryStatusSummary,
    required this.recentOrders,
  });

  factory AdminDashboardSummary.fromJson(Map<String, dynamic> json) {
    final rawStatuses = json['delivery_status_summary'];
    final rawOrders = json['recent_orders'];
    return AdminDashboardSummary(
      totalProducts: (json['total_products'] as num?)?.toInt() ?? 0,
      totalCategories: (json['total_categories'] as num?)?.toInt() ?? 0,
      totalOrders: (json['total_orders'] as num?)?.toInt() ?? 0,
      pendingOrders: (json['pending_orders'] as num?)?.toInt() ?? 0,
      totalCustomers: (json['total_customers'] as num?)?.toInt() ?? 0,
      totalBranches: (json['total_branches'] as num?)?.toInt() ?? 0,
      deliveryStatusSummary: rawStatuses is List
          ? rawStatuses
              .whereType<Map<String, dynamic>>()
              .map(DeliveryStatusSummary.fromJson)
              .toList()
          : const <DeliveryStatusSummary>[],
      recentOrders: rawOrders is List
          ? rawOrders
              .whereType<Map<String, dynamic>>()
              .map(OrderModel.fromJson)
              .toList()
          : const <OrderModel>[],
    );
  }
}
