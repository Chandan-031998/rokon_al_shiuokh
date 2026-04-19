import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../localization/app_localizations.dart';
import '../models/admin_dashboard_model.dart';
import '../services/admin_api_service.dart';
import '../widgets/admin_page_frame.dart';

class AdminDashboardPage extends StatefulWidget {
  final AdminApiService apiService;

  const AdminDashboardPage({
    super.key,
    required this.apiService,
  });

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  late Future<AdminDashboardSummary> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.apiService.fetchDashboardSummary();
  }

  Future<void> _reload() async {
    setState(() {
      _future = widget.apiService.fetchDashboardSummary();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isCompact = MediaQuery.sizeOf(context).width < 860;

    return AdminPageFrame(
      title: l10n.t('admin_dashboard_title'),
      subtitle: l10n.t('admin_dashboard_subtitle'),
      actions: [
        OutlinedButton.icon(
          onPressed: _reload,
          icon: const Icon(Icons.refresh),
          label: Text(l10n.t('common_retry')),
        ),
      ],
      child: FutureBuilder<AdminDashboardSummary>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: Padding(
              padding: EdgeInsets.all(64),
              child: CircularProgressIndicator(),
            ));
          }
          if (snapshot.hasError) {
            return _AdminErrorCard(
              message: snapshot.error.toString(),
              onRetry: _reload,
            );
          }
          final summary = snapshot.data!;
          return Column(
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final columns = width >= 1180
                      ? 3
                      : width >= 760
                          ? 2
                          : 1;
                  return GridView.count(
                    crossAxisCount: columns,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: width >= 760 ? 1.7 : 2.8,
                    children: [
                      _MetricCard(
                          label: l10n.t('admin_metric_products'),
                          value: '${summary.totalProducts}',
                          icon: Icons.inventory_2_outlined),
                      _MetricCard(
                          label: l10n.t('admin_metric_categories'),
                          value: '${summary.totalCategories}',
                          icon: Icons.category_outlined),
                      _MetricCard(
                          label: l10n.t('admin_metric_orders'),
                          value: '${summary.totalOrders}',
                          icon: Icons.receipt_long_outlined),
                      _MetricCard(
                          label: l10n.t('admin_metric_pending_orders'),
                          value: '${summary.pendingOrders}',
                          icon: Icons.timelapse_outlined),
                      _MetricCard(
                          label: l10n.t('admin_metric_customers'),
                          value: '${summary.totalCustomers}',
                          icon: Icons.people_outline),
                      _MetricCard(
                          label: l10n.t('admin_metric_branches'),
                          value: '${summary.totalBranches}',
                          icon: Icons.storefront_outlined),
                    ],
                  );
                },
              ),
              const SizedBox(height: 20),
              isCompact
                  ? Column(
                      children: [
                        _Panel(
                          title: l10n.t('admin_delivery_status_summary'),
                          child: Column(
                            children: summary.deliveryStatusSummary
                                .map(
                                  (row) => ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    title:
                                        Text(_statusLabel(context, row.status)),
                                    trailing: Text(
                                      '${row.count}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium,
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _Panel(
                          title: l10n.t('admin_quick_actions'),
                          child: Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              _QuickActionButton(
                                label: l10n.t('admin_quick_add_product'),
                                icon: Icons.add_box_outlined,
                                onPressed: () => context.go('/admin/products'),
                              ),
                              _QuickActionButton(
                                label: l10n.t('admin_quick_bulk_import'),
                                icon: Icons.upload_file_outlined,
                                onPressed: () => context.go('/admin/import'),
                              ),
                              _QuickActionButton(
                                label: l10n.t('admin_quick_review_orders'),
                                icon: Icons.visibility_outlined,
                                onPressed: () => context.go('/admin/orders'),
                              ),
                              _QuickActionButton(
                                label: l10n.t('admin_quick_manage_branches'),
                                icon: Icons.store_mall_directory_outlined,
                                onPressed: () => context.go('/admin/branches'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _Panel(
                            title: l10n.t('admin_delivery_status_summary'),
                            child: Column(
                              children: summary.deliveryStatusSummary
                                  .map(
                                    (row) => ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      title: Text(
                                          _statusLabel(context, row.status)),
                                      trailing: Text(
                                        '${row.count}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium,
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _Panel(
                            title: l10n.t('admin_quick_actions'),
                            child: Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                _QuickActionButton(
                                  label: l10n.t('admin_quick_add_product'),
                                  icon: Icons.add_box_outlined,
                                  onPressed: () =>
                                      context.go('/admin/products'),
                                ),
                                _QuickActionButton(
                                  label: l10n.t('admin_quick_bulk_import'),
                                  icon: Icons.upload_file_outlined,
                                  onPressed: () => context.go('/admin/import'),
                                ),
                                _QuickActionButton(
                                  label: l10n.t('admin_quick_review_orders'),
                                  icon: Icons.visibility_outlined,
                                  onPressed: () => context.go('/admin/orders'),
                                ),
                                _QuickActionButton(
                                  label: l10n.t('admin_quick_manage_branches'),
                                  icon: Icons.store_mall_directory_outlined,
                                  onPressed: () =>
                                      context.go('/admin/branches'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
              const SizedBox(height: 20),
              _Panel(
                title: l10n.t('admin_recent_orders'),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: [
                      DataColumn(label: Text(l10n.t('admin_table_order'))),
                      DataColumn(label: Text(l10n.t('admin_table_customer'))),
                      DataColumn(label: Text(l10n.t('admin_table_status'))),
                      DataColumn(label: Text(l10n.t('admin_table_type'))),
                      DataColumn(label: Text(l10n.t('admin_table_total'))),
                    ],
                    rows: summary.recentOrders
                        .map(
                          (order) => DataRow(
                            cells: [
                              DataCell(Text(order.orderNumber)),
                              DataCell(Text(order.customer?.fullName ??
                                  l10n.t('admin_guest'))),
                              DataCell(Text(
                                  _statusLabel(context, order.orderStatus))),
                              DataCell(Text(
                                  _orderTypeLabel(context, order.orderType))),
                              DataCell(Text(
                                  '${l10n.t('currency_label')} ${order.totalAmount.toStringAsFixed(2)}')),
                            ],
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.creamSoft,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: AppColors.brownDeep),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(value, style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 4),
                Text(label, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  const _QuickActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonalIcon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18, color: AppColors.brownDeep),
      label: Text(label),
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.creamSoft,
        foregroundColor: AppColors.brownDeep,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  final String title;
  final Widget child;

  const _Panel({
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
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
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _AdminErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _AdminErrorCard({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.l10n.t('admin_data_load_error'),
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(message.replaceFirst('Exception: ', '')),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: Text(context.l10n.t('common_retry')),
          ),
        ],
      ),
    );
  }
}

String _statusLabel(BuildContext context, String status) {
  switch (status) {
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
    case 'cancelled':
      return context.l10n.t('status_cancelled');
    default:
      return status;
  }
}

String _orderTypeLabel(BuildContext context, String orderType) {
  switch (orderType) {
    case 'delivery':
      return context.l10n.t('order_type_delivery');
    case 'pickup':
      return context.l10n.t('order_type_pickup');
    default:
      return orderType;
  }
}
