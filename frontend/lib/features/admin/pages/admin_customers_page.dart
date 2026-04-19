import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../localization/app_localizations.dart';
import '../../../../models/order_model.dart';
import '../../../../models/user_model.dart';
import '../services/admin_api_service.dart';
import '../widgets/admin_page_frame.dart';

class AdminCustomersPage extends StatefulWidget {
  final AdminApiService apiService;

  const AdminCustomersPage({
    super.key,
    required this.apiService,
  });

  @override
  State<AdminCustomersPage> createState() => _AdminCustomersPageState();
}

class _AdminCustomersPageState extends State<AdminCustomersPage> {
  final _searchController = TextEditingController();
  bool _loading = true;
  String? _error;
  List<UserModel> _customers = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final customers = await widget.apiService
          .fetchCustomers(search: _searchController.text);
      if (!mounted) {
        return;
      }
      setState(() {
        _customers = customers;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _openDetail(UserModel customer) async {
    await showDialog<void>(
      context: context,
      builder: (context) => _CustomerDetailDialog(
        apiService: widget.apiService,
        customerId: customer.id,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return AdminPageFrame(
      title: l10n.t('admin_customers_title'),
      subtitle: l10n.t('admin_customers_subtitle'),
      actions: [
        OutlinedButton.icon(
          onPressed: _load,
          icon: const Icon(Icons.refresh),
          label: Text(l10n.t('common_refresh')),
        ),
      ],
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.border),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 720;

                return Flex(
                  direction: compact ? Axis.vertical : Axis.horizontal,
                  crossAxisAlignment: compact
                      ? CrossAxisAlignment.stretch
                      : CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      flex: compact ? 0 : 1,
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          labelText: l10n.t('admin_customers_search'),
                          prefixIcon: const Icon(Icons.search),
                        ),
                        onSubmitted: (_) => _load(),
                      ),
                    ),
                    SizedBox(width: compact ? 0 : 12, height: compact ? 12 : 0),
                    ElevatedButton(
                      onPressed: _load,
                      child: Text(l10n.t('admin_customers_search_button')),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.border),
            ),
            child: _loading
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(48),
                      child: CircularProgressIndicator(),
                    ),
                  )
                : _error != null
                    ? _CustomersError(message: _error!, onRetry: _load)
                    : SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          dataRowMinHeight: 72,
                          dataRowMaxHeight: 84,
                          columns: [
                            DataColumn(
                              label:
                                  Text(l10n.t('admin_customers_col_customer')),
                            ),
                            DataColumn(
                              label: Text(l10n.t('admin_customers_col_phone')),
                            ),
                            const DataColumn(label: Text('Preferred Branch')),
                            DataColumn(
                              label: Text(l10n.t('admin_customers_col_orders')),
                            ),
                            DataColumn(
                              label: Text(
                                l10n.t('admin_customers_col_total_spent'),
                              ),
                            ),
                            DataColumn(
                              label:
                                  Text(l10n.t('admin_customers_col_actions')),
                            ),
                          ],
                          rows: _customers
                              .map(
                                (customer) => DataRow(
                                  cells: [
                                    DataCell(
                                      Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(customer.fullName),
                                          Text(
                                            customer.email,
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall,
                                          ),
                                        ],
                                      ),
                                    ),
                                    DataCell(Text(customer.phone ?? '-')),
                                    DataCell(
                                      Text(customer.preferredBranch?.name ?? '-'),
                                    ),
                                    DataCell(Text('${customer.orderCount}')),
                                    DataCell(
                                      Text(
                                        '${l10n.t('currency_label')} ${customer.totalSpent.toStringAsFixed(2)}',
                                      ),
                                    ),
                                    DataCell(
                                      TextButton(
                                        onPressed: () => _openDetail(customer),
                                        child: Text(
                                          l10n.t(
                                            'admin_customers_view_details',
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                              .toList(),
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

class _CustomerDetailDialog extends StatefulWidget {
  final AdminApiService apiService;
  final int customerId;

  const _CustomerDetailDialog({
    required this.apiService,
    required this.customerId,
  });

  @override
  State<_CustomerDetailDialog> createState() => _CustomerDetailDialogState();
}

class _CustomerDetailDialogState extends State<_CustomerDetailDialog> {
  UserModel? _customer;
  bool _loading = true;
  List<OrderModel> _orders = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final customer = await widget.apiService.fetchCustomer(widget.customerId);
      final orders =
          await widget.apiService.fetchOrders(search: customer.email);
      if (!mounted) {
        return;
      }
      setState(() {
        _customer = customer;
        _orders =
            orders.where((order) => order.customer?.id == customer.id).toList();
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return AlertDialog(
      title: Text(l10n.t('admin_customers_details_title')),
      content: SizedBox(
        width: 820,
        child: _loading
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(48),
                  child: CircularProgressIndicator(),
                ),
              )
            : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_customer!.fullName,
                        style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 8),
                    Text(_customer!.email),
                    if ((_customer!.phone ?? '').isNotEmpty)
                      Text(_customer!.phone!),
                    const SizedBox(height: 18),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _CustomerStatChip(
                          label: 'Orders',
                          value: '${_customer!.orderCount}',
                        ),
                        _CustomerStatChip(
                          label: 'Spent',
                          value:
                              '${l10n.t('currency_label')} ${_customer!.totalSpent.toStringAsFixed(2)}',
                        ),
                        _CustomerStatChip(
                          label: 'Status',
                          value: _customer!.isActive ? 'Active' : 'Inactive',
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    if (_customer!.preferredBranch != null) ...[
                      Text(
                        l10n.t('account_preferred_branch'),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 6),
                      Text(_customer!.preferredBranch!.name),
                      const SizedBox(height: 18),
                    ],
                    Text(
                      l10n.t('account_saved_addresses'),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    ..._customer!.addresses.map(
                      (address) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(address.label),
                        subtitle: Text(
                            '${address.city}, ${address.neighborhood}\n${address.addressLine}'),
                        isThreeLine: true,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      l10n.t('admin_customers_order_history'),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    ..._orders.map(
                      (order) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(order.orderNumber),
                        subtitle: Text(order.orderStatus),
                        trailing: Text(
                          '${l10n.t('currency_label')} ${order.totalAmount.toStringAsFixed(2)}',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.t('common_close')),
        ),
      ],
    );
  }
}

class _CustomerStatChip extends StatelessWidget {
  final String label;
  final String value;

  const _CustomerStatChip({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.creamSoft,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.border),
      ),
      child: Text('$label: $value'),
    );
  }
}

class _CustomersError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _CustomersError({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.t('admin_data_load_error'),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(l10n.t('admin_customers_error_desc')),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: Text(l10n.t('common_retry')),
        ),
      ],
    );
  }
}
