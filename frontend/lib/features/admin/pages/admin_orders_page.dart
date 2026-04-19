import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../localization/app_localizations.dart';
import '../../../../models/branch_model.dart';
import '../../../../models/order_model.dart';
import '../services/admin_api_service.dart';
import '../widgets/admin_page_frame.dart';

class AdminOrdersPage extends StatefulWidget {
  final AdminApiService apiService;

  const AdminOrdersPage({
    super.key,
    required this.apiService,
  });

  @override
  State<AdminOrdersPage> createState() => _AdminOrdersPageState();
}

class _AdminOrdersPageState extends State<AdminOrdersPage> {
  final _searchController = TextEditingController();
  final _dateFromController = TextEditingController();
  final _dateToController = TextEditingController();
  String? _status;
  int? _branchId;
  bool _loading = true;
  String? _error;
  List<OrderModel> _orders = const [];
  List<BranchModel> _branches = const [];

  static const _statuses = <String>[
    'pending',
    'confirmed',
    'preparing',
    'out_for_delivery',
    'ready_for_pickup',
    'delivered',
    'cancelled',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _dateFromController.dispose();
    _dateToController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        widget.apiService.fetchOrders(
          search: _searchController.text,
          status: _status,
          branchId: _branchId,
          dateFrom: _dateFromController.text,
          dateTo: _dateToController.text,
        ),
        widget.apiService.fetchBranches(),
      ]);
      if (!mounted) {
        return;
      }
      setState(() {
        _orders = results[0] as List<OrderModel>;
        _branches = results[1] as List<BranchModel>;
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

  Future<void> _openOrderDetails(OrderModel order) async {
    final refreshed = await showDialog<bool>(
      context: context,
      builder: (context) => _OrderDetailsDialog(
        apiService: widget.apiService,
        orderId: order.id,
      ),
    );
    if (refreshed == true) {
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AdminPageFrame(
      title: l10n.t('admin_orders_title'),
      subtitle: l10n.t('admin_orders_subtitle'),
      actions: [
        OutlinedButton.icon(
          onPressed: _load,
          icon: const Icon(Icons.refresh),
          label: Text(l10n.t('common_refresh')),
        ),
      ],
      child: Column(
        children: [
          LayoutBuilder(
              builder: (context, constraints) => Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: constraints.maxWidth < 1180
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              TextField(
                                controller: _searchController,
                                decoration: InputDecoration(
                                  labelText: l10n.t('admin_orders_search'),
                                  prefixIcon: const Icon(Icons.search),
                                ),
                                onSubmitted: (_) => _load(),
                              ),
                              const SizedBox(height: 12),
                              DropdownButtonFormField<String?>(
                                initialValue: _status,
                                isExpanded: true,
                                decoration: InputDecoration(
                                  labelText: l10n.t('admin_table_status'),
                                ),
                                items: [
                                  DropdownMenuItem<String?>(
                                    value: null,
                                    child: Text(
                                        l10n.t('admin_orders_all_statuses')),
                                  ),
                                  ..._statuses.map(
                                    (status) => DropdownMenuItem<String?>(
                                      value: status,
                                      child:
                                          Text(_statusLabel(context, status)),
                                    ),
                                  ),
                                ],
                                onChanged: (value) =>
                                    setState(() => _status = value),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: _dateFromController,
                                decoration: const InputDecoration(
                                  labelText: 'Date From',
                                  hintText: '2026-04-18',
                                  prefixIcon: Icon(Icons.event_outlined),
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: _dateToController,
                                decoration: const InputDecoration(
                                  labelText: 'Date To',
                                  hintText: '2026-04-18',
                                  prefixIcon: Icon(Icons.event_available_outlined),
                                ),
                              ),
                              const SizedBox(height: 12),
                              DropdownButtonFormField<int?>(
                                initialValue: _branchId,
                                isExpanded: true,
                                decoration: InputDecoration(
                                  labelText: l10n.t('products_filter_branch'),
                                ),
                                items: [
                                  DropdownMenuItem<int?>(
                                    value: null,
                                    child: Text(
                                        l10n.t('products_filter_all_branches')),
                                  ),
                                  ..._branches.map(
                                    (branch) => DropdownMenuItem<int?>(
                                      value: branch.id,
                                      child: Text(branch.name),
                                    ),
                                  ),
                                ],
                                onChanged: (value) =>
                                    setState(() => _branchId = value),
                              ),
                              const SizedBox(height: 12),
                              ElevatedButton(
                                onPressed: _load,
                                child: Text(l10n.t('common_apply')),
                              ),
                            ],
                          )
                        : Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            crossAxisAlignment: WrapCrossAlignment.end,
                            children: [
                              SizedBox(
                                width: (constraints.maxWidth * 0.38)
                                    .clamp(260.0, 420.0)
                                    .toDouble(),
                                child: TextField(
                                  controller: _searchController,
                                  decoration: InputDecoration(
                                    labelText: l10n.t('admin_orders_search'),
                                    prefixIcon: const Icon(Icons.search),
                                  ),
                                  onSubmitted: (_) => _load(),
                                ),
                              ),
                              SizedBox(
                                width: 240,
                                child: DropdownButtonFormField<String?>(
                                  initialValue: _status,
                                  isExpanded: true,
                                  decoration: InputDecoration(
                                    labelText: l10n.t('admin_table_status'),
                                  ),
                                  items: [
                                    DropdownMenuItem<String?>(
                                      value: null,
                                      child: Text(
                                          l10n.t('admin_orders_all_statuses')),
                                    ),
                                    ..._statuses.map(
                                      (status) => DropdownMenuItem<String?>(
                                        value: status,
                                        child:
                                            Text(_statusLabel(context, status)),
                                      ),
                                    ),
                                  ],
                                  onChanged: (value) =>
                                      setState(() => _status = value),
                                ),
                              ),
                              SizedBox(
                                width: 240,
                                child: TextField(
                                  controller: _dateFromController,
                                  decoration: const InputDecoration(
                                    labelText: 'Date From',
                                    hintText: '2026-04-18',
                                    prefixIcon: Icon(Icons.event_outlined),
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: 240,
                                child: TextField(
                                  controller: _dateToController,
                                  decoration: const InputDecoration(
                                    labelText: 'Date To',
                                    hintText: '2026-04-18',
                                    prefixIcon:
                                        Icon(Icons.event_available_outlined),
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: 240,
                                child: DropdownButtonFormField<int?>(
                                  initialValue: _branchId,
                                  isExpanded: true,
                                  decoration: InputDecoration(
                                    labelText: l10n.t('products_filter_branch'),
                                  ),
                                  items: [
                                    DropdownMenuItem<int?>(
                                      value: null,
                                      child: Text(l10n
                                          .t('products_filter_all_branches')),
                                    ),
                                    ..._branches.map(
                                      (branch) => DropdownMenuItem<int?>(
                                        value: branch.id,
                                        child: Text(branch.name),
                                      ),
                                    ),
                                  ],
                                  onChanged: (value) =>
                                      setState(() => _branchId = value),
                                ),
                              ),
                              ElevatedButton(
                                onPressed: _load,
                                child: Text(l10n.t('common_apply')),
                              ),
                            ],
                          ),
                  )),
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
                  ))
                : _error != null
                    ? _OrderError(message: _error!, onRetry: _load)
                    : SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          columns: [
                            DataColumn(
                                label: Text(l10n.t('admin_table_order'))),
                            DataColumn(
                                label: Text(l10n.t('admin_table_customer'))),
                            DataColumn(
                                label: Text(l10n.t('admin_table_status'))),
                            DataColumn(label: Text(l10n.t('admin_table_type'))),
                            DataColumn(
                                label:
                                    Text(l10n.t('admin_branches_col_branch'))),
                            DataColumn(
                                label: Text(l10n.t('admin_table_total'))),
                            DataColumn(
                                label:
                                    Text(l10n.t('admin_products_col_actions'))),
                          ],
                          rows: _orders
                              .map(
                                (order) => DataRow(
                                  cells: [
                                    DataCell(Text(order.orderNumber)),
                                    DataCell(Text(order.customer?.fullName ??
                                        l10n.t('admin_guest'))),
                                    DataCell(Text(_statusLabel(
                                        context, order.orderStatus))),
                                    DataCell(Text(_orderTypeLabel(
                                        context, order.orderType))),
                                    DataCell(Text(order.branch?.name ??
                                        l10n.t('common_not_available'))),
                                    DataCell(Text(
                                        '${l10n.t('currency_label')} ${order.totalAmount.toStringAsFixed(2)}')),
                                    DataCell(
                                      TextButton(
                                        onPressed: () =>
                                            _openOrderDetails(order),
                                        child: Text(
                                            l10n.t('admin_orders_view_update')),
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

class _OrderDetailsDialog extends StatefulWidget {
  final AdminApiService apiService;
  final int orderId;

  const _OrderDetailsDialog({
    required this.apiService,
    required this.orderId,
  });

  @override
  State<_OrderDetailsDialog> createState() => _OrderDetailsDialogState();
}

class _OrderDetailsDialogState extends State<_OrderDetailsDialog> {
  OrderModel? _order;
  bool _loading = true;
  bool _saving = false;
  String? _status;
  final _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final order = await widget.apiService.fetchOrder(widget.orderId);
      if (!mounted) {
        return;
      }
      setState(() {
        _order = order;
        _status = order.orderStatus;
        _notesController.text = order.adminNotes ?? '';
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        Navigator.of(context).pop(false);
      }
    }
  }

  Future<void> _save() async {
    if (_status == null) {
      return;
    }
    setState(() => _saving = true);
    try {
      final order = await widget.apiService.updateOrder(widget.orderId, {
        'order_status': _status,
        'admin_notes': _notesController.text.trim(),
      });
      if (!mounted) {
        return;
      }
      setState(() => _order = order);
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(error.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.t('admin_orders_details_title')),
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
                    Text(_order!.orderNumber,
                        style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 8),
                    Text(
                      '${_order!.customer?.fullName ?? l10n.t('admin_guest')} • ${_order!.branch?.name ?? l10n.t('common_not_available')}',
                    ),
                    const SizedBox(height: 18),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _OrderInfoChip(
                          label: 'Mode',
                          value: _orderTypeLabel(context, _order!.orderType),
                        ),
                        _OrderInfoChip(
                          label: 'Payment',
                          value: _order!.paymentMethod,
                        ),
                        _OrderInfoChip(
                          label: 'Status',
                          value: _statusLabel(context, _order!.orderStatus),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    DropdownButtonFormField<String>(
                      initialValue: _status,
                      decoration: InputDecoration(
                        labelText: l10n.t('admin_orders_status'),
                      ),
                      items: _AdminOrdersPageState._statuses
                          .map(
                            (status) => DropdownMenuItem<String>(
                              value: status,
                              child: Text(_statusLabel(context, status)),
                            ),
                          )
                          .toList(),
                      onChanged: (value) => setState(() => _status = value),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _notesController,
                      maxLines: 3,
                      decoration: InputDecoration(
                          labelText: l10n.t('admin_orders_notes')),
                    ),
                    const SizedBox(height: 18),
                    if (_order!.address != null) ...[
                      Text(
                        'Customer Address',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${_order!.address!.label} • ${_order!.address!.city} • ${_order!.address!.neighborhood}',
                      ),
                      const SizedBox(height: 4),
                      Text(_order!.address!.addressLine),
                      const SizedBox(height: 18),
                    ],
                    Text(l10n.t('cart_items'),
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 12),
                    ..._order!.items.map(
                      (item) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(item.productName),
                        subtitle: Text(l10n.t(
                            'checkout_qty', {'quantity': '${item.quantity}'})),
                        trailing: Text(
                            '${l10n.t('currency_label')} ${item.lineTotal.toStringAsFixed(2)}'),
                      ),
                    ),
                    const Divider(height: 32),
                    Text(
                      'Order Totals',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    _TotalRow(
                      label: 'Subtotal',
                      value:
                          '${l10n.t('currency_label')} ${_order!.subtotal.toStringAsFixed(2)}',
                    ),
                    _TotalRow(
                      label: 'Delivery Fee',
                      value:
                          '${l10n.t('currency_label')} ${_order!.deliveryFee.toStringAsFixed(2)}',
                    ),
                    _TotalRow(
                      label: 'Discount',
                      value:
                          '${l10n.t('currency_label')} ${_order!.discountAmount.toStringAsFixed(2)}',
                    ),
                    _TotalRow(
                      label: 'Total',
                      value:
                          '${l10n.t('currency_label')} ${_order!.totalAmount.toStringAsFixed(2)}',
                      emphasize: true,
                    ),
                  ],
                ),
              ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: Text(l10n.t('common_close')),
        ),
        OutlinedButton.icon(
          onPressed: _saving
              ? null
              : () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Print summary will be connected next.'),
                    ),
                  );
                },
          icon: const Icon(Icons.print_outlined),
          label: const Text('Print Summary'),
        ),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          child:
              Text(_saving ? l10n.t('common_saving') : l10n.t('common_save')),
        ),
      ],
    );
  }
}

class _OrderInfoChip extends StatelessWidget {
  final String label;
  final String value;

  const _OrderInfoChip({
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

class _TotalRow extends StatelessWidget {
  final String label;
  final String value;
  final bool emphasize;

  const _TotalRow({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  @override
  Widget build(BuildContext context) {
    final style = emphasize
        ? Theme.of(context)
            .textTheme
            .titleMedium
            ?.copyWith(fontWeight: FontWeight.w800)
        : Theme.of(context).textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(value, style: style),
        ],
      ),
    );
  }
}

class _OrderError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _OrderError({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(message),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: Text(context.l10n.t('common_retry')),
        ),
      ],
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
