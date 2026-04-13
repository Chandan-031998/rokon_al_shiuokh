import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../localization/app_localizations.dart';
import '../../models/order_model.dart';
import '../../services/api_service.dart';

class OrderDetailsPage extends StatefulWidget {
  final int orderId;
  final ApiService apiService;

  const OrderDetailsPage({
    super.key,
    required this.orderId,
    required this.apiService,
  });

  @override
  State<OrderDetailsPage> createState() => _OrderDetailsPageState();
}

class _OrderDetailsPageState extends State<OrderDetailsPage> {
  late Future<OrderModel> _orderFuture;

  @override
  void initState() {
    super.initState();
    _orderFuture = widget.apiService.fetchOrderDetails(widget.orderId);
  }

  Future<void> _retry() async {
    setState(() {
      _orderFuture = widget.apiService.fetchOrderDetails(widget.orderId);
    });
    await _orderFuture;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.t('orders_detail_title'))),
      body: FutureBuilder<OrderModel>(
        future: _orderFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: _DetailCard(
                  title: l10n.t('orders_detail_error_title'),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.t('orders_detail_error_desc'),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _retry,
                        child: Text(l10n.t('common_retry')),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          final order = snapshot.data!;
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 980),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                children: [
                  _OrderHero(order: order),
                  const SizedBox(height: 18),
                  _DetailCard(
                    title: l10n.t('orders_status_timeline'),
                    child: _StatusTimeline(order: order),
                  ),
                  const SizedBox(height: 16),
                  _DetailCard(
                    title: l10n.t('orders_items'),
                    child: Column(
                      children: [
                        for (final item in order.items) ...[
                          _OrderItemRow(item: item),
                          if (item != order.items.last)
                            const Divider(color: AppColors.border, height: 24),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _DetailCard(
                    title: l10n.t('orders_fulfilment_details'),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _MetaRow(
                          label: l10n.t('orders_mode'),
                          value: _orderTypeLabel(context, order.orderType),
                        ),
                        const SizedBox(height: 10),
                        _MetaRow(
                          label: l10n.t('orders_branch'),
                          value: order.branch?.name ??
                              l10n.t('orders_not_assigned'),
                        ),
                        if (order.address != null) ...[
                          const SizedBox(height: 10),
                          _MetaRow(
                            label: l10n.t('orders_address'),
                            value:
                                '${order.address!.city}, ${order.address!.neighborhood}\n${order.address!.addressLine}',
                          ),
                        ],
                        if ((order.notes ?? '').isNotEmpty) ...[
                          const SizedBox(height: 10),
                          _MetaRow(
                            label: l10n.t('orders_notes'),
                            value: order.notes!,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _DetailCard(
                    title: l10n.t('orders_payment_summary'),
                    child: Column(
                      children: [
                        _SummaryRow(
                          label: l10n.t('cart_subtotal'),
                          value: 'SAR ${order.subtotal.toStringAsFixed(0)}',
                        ),
                        const SizedBox(height: 10),
                        _SummaryRow(
                          label: l10n.t('orders_delivery_fee'),
                          value: 'SAR ${order.deliveryFee.toStringAsFixed(0)}',
                        ),
                        const SizedBox(height: 10),
                        _SummaryRow(
                          label: l10n.t('cart_total'),
                          value: 'SAR ${order.totalAmount.toStringAsFixed(0)}',
                          emphasize: true,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _OrderHero extends StatelessWidget {
  final OrderModel order;

  const _OrderHero({required this.order});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.brownDeep, AppColors.brown],
        ),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        children: [
          Container(
            width: 74,
            height: 74,
            decoration: BoxDecoration(
              color: AppColors.cream,
              borderRadius: BorderRadius.circular(22),
            ),
            child: const Icon(
              Icons.receipt_long_rounded,
              color: AppColors.brownDeep,
              size: 36,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  order.orderNumber,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: AppColors.white,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${_orderStatusLabel(context, order.orderStatus)} · ${_orderTypeLabel(context, order.orderType)}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.creamSoft,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusTimeline extends StatelessWidget {
  final OrderModel order;

  const _StatusTimeline({required this.order});

  @override
  Widget build(BuildContext context) {
    final steps = _timelineSteps(order.orderType);
    final currentIndex = steps.indexOf(order.orderStatus);
    final safeIndex = currentIndex < 0 ? 0 : currentIndex;

    return Column(
      children: [
        for (var index = 0; index < steps.length; index++) ...[
          _StatusStep(
            label: _orderStatusLabel(context, steps[index]),
            isComplete: index <= safeIndex,
            isCurrent: index == safeIndex,
            isLast: index == steps.length - 1,
          ),
        ],
      ],
    );
  }
}

class _StatusStep extends StatelessWidget {
  final String label;
  final bool isComplete;
  final bool isCurrent;
  final bool isLast;

  const _StatusStep({
    required this.label,
    required this.isComplete,
    required this.isCurrent,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final color = isComplete ? AppColors.goldMuted : AppColors.border;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isComplete ? AppColors.goldMuted : AppColors.white,
                border: Border.all(color: color, width: 2),
              ),
              child: isCurrent
                  ? const Center(
                      child:
                          Icon(Icons.circle, size: 6, color: AppColors.white),
                    )
                  : null,
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 38,
                color: color,
              ),
          ],
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                    color:
                        isComplete ? AppColors.textDark : AppColors.textMuted,
                  ),
            ),
          ),
        ),
      ],
    );
  }
}

class _OrderItemRow extends StatelessWidget {
  final OrderLineModel item;

  const _OrderItemRow({required this.item});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.productName,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                context.l10n.t(
                  'orders_qty_each',
                  {
                    'quantity': '${item.quantity}',
                    'price': item.price.toStringAsFixed(0),
                  },
                ),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
        Text(
          'SAR ${item.lineTotal.toStringAsFixed(0)}',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppColors.brownDeep,
                fontWeight: FontWeight.w800,
              ),
        ),
      ],
    );
  }
}

class _MetaRow extends StatelessWidget {
  final String label;
  final String value;

  const _MetaRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 92,
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: AppColors.goldMuted,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(value, style: Theme.of(context).textTheme.bodyLarge),
        ),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool emphasize;

  const _SummaryRow({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  @override
  Widget build(BuildContext context) {
    final style = emphasize
        ? Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: AppColors.brownDeep,
            )
        : Theme.of(context).textTheme.bodyLarge;

    return Row(
      children: [
        Text(label, style: style),
        const Spacer(),
        Text(value, style: style),
      ],
    );
  }
}

class _DetailCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _DetailCard({
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

List<String> _timelineSteps(String orderType) {
  if (orderType == 'pickup') {
    return const [
      'pending',
      'confirmed',
      'preparing',
      'ready_for_pickup',
      'delivered',
    ];
  }

  return const [
    'pending',
    'confirmed',
    'preparing',
    'out_for_delivery',
    'delivered',
  ];
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
