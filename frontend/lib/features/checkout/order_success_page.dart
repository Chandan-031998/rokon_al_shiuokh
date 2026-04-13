import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../localization/app_localizations.dart';
import '../../models/order_model.dart';

class OrderSuccessPage extends StatelessWidget {
  final OrderModel order;

  const OrderSuccessPage({
    super.key,
    required this.order,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final orderMode = order.orderType == 'pickup'
        ? l10n.t('order_success_mode_pickup')
        : l10n.t('order_success_mode_delivery');
    final branchName = order.branch?.name ?? l10n.t('orders_selected_branch');

    return Scaffold(
      appBar: AppBar(title: Text(l10n.t('order_success_title'))),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.brownDeep, AppColors.brown],
                  ),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 82,
                      height: 82,
                      decoration: BoxDecoration(
                        color: AppColors.cream,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: const Icon(
                        Icons.check_circle_rounded,
                        color: AppColors.brownDeep,
                        size: 46,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      l10n.t('order_success_heading'),
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                color: AppColors.white,
                              ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      l10n.t(
                        'order_success_message',
                        {'order': order.orderNumber, 'mode': orderMode},
                      ),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.creamSoft,
                          ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              _SuccessCard(
                title: l10n.t('order_success_fulfilment'),
                description: order.orderType == 'pickup'
                    ? l10n.t(
                        'order_success_fulfilment_pickup',
                        {'branch': branchName},
                      )
                    : l10n.t(
                        'order_success_fulfilment_delivery',
                        {'branch': branchName},
                      ),
              ),
              _SuccessCard(
                title: l10n.t('order_success_total'),
                description:
                    '${l10n.t('currency_label')} ${order.totalAmount.toStringAsFixed(0)}',
              ),
              if (order.address != null)
                _SuccessCard(
                  title: l10n.t('order_success_delivery_address'),
                  description:
                      '${order.address!.city}, ${order.address!.neighborhood}\n${order.address!.addressLine}',
                ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () =>
                      Navigator.of(context).popUntil((route) => route.isFirst),
                  child: Text(l10n.t('order_success_back')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SuccessCard extends StatelessWidget {
  final String title;
  final String description;

  const _SuccessCard({
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: AppColors.goldMuted,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          Text(description, style: Theme.of(context).textTheme.bodyLarge),
        ],
      ),
    );
  }
}
