import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../localization/app_locale_controller.dart';
import '../../localization/app_localizations.dart';
import '../../models/order_model.dart';
import '../../services/api_service.dart';
import '../navigation/app_shell.dart';
import 'order_details_page.dart';

class OrdersPage extends StatefulWidget {
  final ApiService apiService;
  final AppLocaleController localeController;
  final bool isActive;
  final VoidCallback onBrowseProducts;
  final VoidCallback onOpenAccount;
  final bool showAppBar;

  const OrdersPage({
    super.key,
    required this.apiService,
    required this.localeController,
    required this.isActive,
    required this.onBrowseProducts,
    required this.onOpenAccount,
    this.showAppBar = true,
  });

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  late Future<List<OrderModel>> _ordersFuture;

  @override
  void initState() {
    super.initState();
    _ordersFuture = widget.apiService.fetchOrders();
  }

  @override
  void didUpdateWidget(covariant OrdersPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isActive && widget.isActive) {
      _refresh();
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _ordersFuture = widget.apiService.fetchOrders();
    });
    try {
      await _ordersFuture;
    } catch (_) {
      // FutureBuilder handles the visible error state.
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return TabScreenTemplate(
      eyebrow: l10n.t('orders_eyebrow'),
      title: l10n.t('orders_title'),
      subtitle: l10n.t('orders_subtitle'),
      icon: Icons.receipt_long_rounded,
      showAppBar: widget.showAppBar,
      localeController: widget.localeController,
      body: FutureBuilder<List<OrderModel>>(
        future: _ordersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            );
          }

          if (snapshot.hasError) {
            return ActionPanel(
              title: l10n.t('orders_load_error_title'),
              description: l10n.t('orders_load_error_desc'),
              actionLabel: l10n.t('common_retry'),
              onPressed: _refresh,
              icon: Icons.refresh_rounded,
            );
          }

          final orders = snapshot.data ?? const <OrderModel>[];
          if (orders.isEmpty) {
            return Column(
              children: [
                ActionPanel(
                  title: l10n.t('orders_empty_title'),
                  description: l10n.t('orders_empty_desc'),
                  actionLabel: l10n.t('common_browse_categories'),
                  onPressed: widget.onBrowseProducts,
                  icon: Icons.storefront_outlined,
                ),
                ActionPanel(
                  title: l10n.t('account_title'),
                  description: l10n.t('orders_account_desc'),
                  actionLabel: l10n.t('common_open_account'),
                  onPressed: widget.onOpenAccount,
                  icon: Icons.person_outline,
                ),
              ],
            );
          }

          return Column(
            children: [
              for (final order in orders)
                _OrderListCard(
                  order: order,
                  onTap: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => OrderDetailsPage(
                          orderId: order.id,
                          apiService: widget.apiService,
                        ),
                      ),
                    );
                    if (!context.mounted) {
                      return;
                    }
                    await _refresh();
                  },
                  onReorder: widget.onBrowseProducts,
                ),
            ],
          );
        },
      ),
    );
  }
}

class _OrderListCard extends StatelessWidget {
  final OrderModel order;
  final VoidCallback onTap;
  final VoidCallback onReorder;

  const _OrderListCard({
    required this.order,
    required this.onTap,
    required this.onReorder,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.white, Color(0xFFFFFBF7)],
        ),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x122D1A12),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(26),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            order.orderNumber,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${_orderStatusLabel(context, order.orderStatus)} · ${_orderTypeLabel(context, order.orderType)}',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(color: AppColors.goldMuted),
                          ),
                        ],
                      ),
                    ),
                    _StatusBadge(status: order.orderStatus),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: AppColors.creamSoft,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    _orderSummary(context, order),
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: AppColors.brown,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.brownDeep,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        'SAR ${order.totalAmount.toStringAsFixed(0)}',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: AppColors.white,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: onReorder,
                      child: Text(context.l10n.t('orders_reorder')),
                    ),
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.arrow_forward_rounded,
                      color: AppColors.brown,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final isDelivered = status == 'delivered';
    final background =
        isDelivered ? AppColors.creamSoft : const Color(0xFFF9F1E2);
    final foreground = isDelivered ? AppColors.brown : AppColors.goldMuted;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _orderStatusLabel(context, status),
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

String _orderSummary(BuildContext context, OrderModel order) {
  final itemsText = order.items.isEmpty
      ? context.l10n.t('orders_summary_fallback')
      : order.items
          .take(2)
          .map((item) => '${item.quantity}x ${item.productName}')
          .join(' · ');
  final branchText =
      order.branch?.name ?? context.l10n.t('orders_selected_branch');
  return '$itemsText\n$branchText';
}

String _orderTypeLabel(BuildContext context, String value) {
  switch (value) {
    case 'pickup':
      return context.l10n.t('type_pickup');
    case 'delivery':
    default:
      return context.l10n.t('type_delivery');
  }
}

String _orderStatusLabel(BuildContext context, String value) {
  switch (value) {
    case 'pending':
      return context.l10n.t('status_pending');
    case 'confirmed':
      return context.l10n.t('status_confirmed');
    case 'preparing':
      return context.l10n.t('status_preparing');
    case 'out_for_delivery':
      return context.l10n.t('status_out_for_delivery');
    case 'ready_for_pickup':
      return context.l10n.t('status_ready_for_pickup');
    case 'delivered':
      return context.l10n.t('status_delivered');
    default:
      return value.replaceAll('_', ' ').trim();
  }
}
