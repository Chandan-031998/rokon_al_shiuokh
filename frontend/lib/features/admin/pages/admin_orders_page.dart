import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
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
    return AdminPageFrame(
      title: 'Orders',
      subtitle: 'Review orders, inspect customer and branch details, and update fulfillment status.',
      actions: [
        OutlinedButton.icon(
          onPressed: _load,
          icon: const Icon(Icons.refresh),
          label: const Text('Refresh'),
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
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      labelText: 'Search by order, customer, or email',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onSubmitted: (_) => _load(),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 220,
                  child: DropdownButtonFormField<String?>(
                    initialValue: _status,
                    decoration: const InputDecoration(labelText: 'Status'),
                    items: [
                      const DropdownMenuItem<String?>(value: null, child: Text('All statuses')),
                      ..._statuses.map(
                        (status) => DropdownMenuItem<String?>(
                          value: status,
                          child: Text(_statusLabel(status)),
                        ),
                      ),
                    ],
                    onChanged: (value) => setState(() => _status = value),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 220,
                  child: DropdownButtonFormField<int?>(
                    initialValue: _branchId,
                    decoration: const InputDecoration(labelText: 'Branch'),
                    items: [
                      const DropdownMenuItem<int?>(value: null, child: Text('All branches')),
                      ..._branches.map(
                        (branch) => DropdownMenuItem<int?>(
                          value: branch.id,
                          child: Text(branch.name),
                        ),
                      ),
                    ],
                    onChanged: (value) => setState(() => _branchId = value),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _load,
                  child: const Text('Apply'),
                ),
              ],
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
                ? const Center(child: Padding(
                    padding: EdgeInsets.all(48),
                    child: CircularProgressIndicator(),
                  ))
                : _error != null
                    ? _OrderError(message: _error!, onRetry: _load)
                    : SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          columns: const [
                            DataColumn(label: Text('Order')),
                            DataColumn(label: Text('Customer')),
                            DataColumn(label: Text('Status')),
                            DataColumn(label: Text('Type')),
                            DataColumn(label: Text('Branch')),
                            DataColumn(label: Text('Total')),
                            DataColumn(label: Text('Actions')),
                          ],
                          rows: _orders
                              .map(
                                (order) => DataRow(
                                  cells: [
                                    DataCell(Text(order.orderNumber)),
                                    DataCell(Text(order.customer?.fullName ?? 'Guest')),
                                    DataCell(Text(_statusLabel(order.orderStatus))),
                                    DataCell(Text(order.orderType)),
                                    DataCell(Text(order.branch?.name ?? '-')),
                                    DataCell(Text('SAR ${order.totalAmount.toStringAsFixed(2)}')),
                                    DataCell(
                                      TextButton(
                                        onPressed: () => _openOrderDetails(order),
                                        child: const Text('View / Update'),
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
        SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Order Details'),
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
                    Text(_order!.orderNumber, style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 8),
                    Text('${_order!.customer?.fullName ?? 'Guest'} • ${_order!.branch?.name ?? 'No branch'}'),
                    const SizedBox(height: 18),
                    DropdownButtonFormField<String>(
                      initialValue: _status,
                      decoration: const InputDecoration(labelText: 'Order Status'),
                      items: _AdminOrdersPageState._statuses
                          .map(
                            (status) => DropdownMenuItem<String>(
                              value: status,
                              child: Text(_statusLabel(status)),
                            ),
                          )
                          .toList(),
                      onChanged: (value) => setState(() => _status = value),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _notesController,
                      maxLines: 3,
                      decoration: const InputDecoration(labelText: 'Admin Notes'),
                    ),
                    const SizedBox(height: 18),
                    Text('Items', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 12),
                    ..._order!.items.map(
                      (item) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(item.productName),
                        subtitle: Text('Qty ${item.quantity}'),
                        trailing: Text('SAR ${item.lineTotal.toStringAsFixed(2)}'),
                      ),
                    ),
                  ],
                ),
              ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Close'),
        ),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Saving...' : 'Save'),
        ),
      ],
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
          label: const Text('Retry'),
        ),
      ],
    );
  }
}

String _statusLabel(String status) {
  switch (status) {
    case 'pending':
      return 'Pending';
    case 'confirmed':
      return 'Confirmed';
    case 'preparing':
      return 'Preparing';
    case 'out_for_delivery':
      return 'Out for Delivery';
    case 'ready_for_pickup':
      return 'Ready for Pickup';
    case 'delivered':
      return 'Delivered';
    case 'cancelled':
      return 'Cancelled';
    default:
      return status;
  }
}
