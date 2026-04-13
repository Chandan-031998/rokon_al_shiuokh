import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../models/branch_model.dart';
import '../../../../models/order_model.dart';
import '../services/admin_api_service.dart';
import '../widgets/admin_page_frame.dart';

class AdminDeliveriesPage extends StatefulWidget {
  final AdminApiService apiService;

  const AdminDeliveriesPage({
    super.key,
    required this.apiService,
  });

  @override
  State<AdminDeliveriesPage> createState() => _AdminDeliveriesPageState();
}

class _AdminDeliveriesPageState extends State<AdminDeliveriesPage> {
  String? _status;
  int? _branchId;
  bool _loading = true;
  String? _error;
  List<OrderModel> _deliveries = const [];
  List<BranchModel> _branches = const [];

  static const _statuses = <String>[
    'preparing',
    'out_for_delivery',
    'delivered',
    'cancelled',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        widget.apiService.fetchDeliveries(status: _status, branchId: _branchId),
        widget.apiService.fetchBranches(),
      ]);
      if (!mounted) {
        return;
      }
      setState(() {
        _deliveries = results[0] as List<OrderModel>;
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

  Future<void> _updateDelivery(OrderModel order) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => _DeliveryUpdateDialog(
        apiService: widget.apiService,
        order: order,
      ),
    );
    if (result == true) {
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminPageFrame(
      title: 'Deliveries',
      subtitle: 'Track delivery fulfillment, dispatch flow, and branch-level operational notes.',
      actions: [
        OutlinedButton.icon(
          onPressed: _load,
          icon: const Icon(Icons.refresh),
          label: const Text('Refresh'),
        ),
      ],
      child: Column(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 960;

              final statusField = DropdownButtonFormField<String?>(
                initialValue: _status,
                decoration: const InputDecoration(labelText: 'Status'),
                items: [
                  const DropdownMenuItem<String?>(value: null, child: Text('All statuses')),
                  ..._statuses.map(
                    (status) => DropdownMenuItem<String?>(
                      value: status,
                      child: Text(_deliveryStatusLabel(status)),
                    ),
                  ),
                ],
                onChanged: (value) => setState(() => _status = value),
              );

              final branchField = DropdownButtonFormField<int?>(
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
              );

              return Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.border),
                ),
                child: compact
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          statusField,
                          const SizedBox(height: 14),
                          branchField,
                          const SizedBox(height: 14),
                          Align(
                            alignment: Alignment.centerRight,
                            child: ElevatedButton(
                              onPressed: _load,
                              child: const Text('Apply'),
                            ),
                          ),
                        ],
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: statusField,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: branchField,
                          ),
                          const SizedBox(width: 16),
                          SizedBox(
                            height: 52,
                            child: ElevatedButton(
                              onPressed: _load,
                              child: const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 18),
                                child: Text('Apply'),
                              ),
                            ),
                          ),
                        ],
                      ),
              );
            },
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
                    ? _DeliveriesError(message: _error!, onRetry: _load)
                    : SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          dataRowMinHeight: 70,
                          dataRowMaxHeight: 78,
                          columnSpacing: 28,
                          columns: const [
                            DataColumn(label: Text('Order')),
                            DataColumn(label: Text('Customer')),
                            DataColumn(label: Text('Branch')),
                            DataColumn(label: Text('Status')),
                            DataColumn(label: Text('Actions')),
                          ],
                          rows: _deliveries
                              .map(
                                (delivery) => DataRow(
                                  cells: [
                                    DataCell(
                                      SizedBox(
                                        width: 220,
                                        child: Text(
                                          delivery.orderNumber,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      SizedBox(
                                        width: 180,
                                        child: Text(
                                          delivery.customer?.fullName ?? 'Guest customer',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      SizedBox(
                                        width: 240,
                                        child: Text(
                                          delivery.branch?.name ?? '-',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      _DeliveryStatusChip(
                                        label: _deliveryStatusLabel(delivery.orderStatus),
                                      ),
                                    ),
                                    DataCell(
                                      OutlinedButton(
                                        onPressed: () => _updateDelivery(delivery),
                                        child: const Text('Update'),
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

class _DeliveryStatusChip extends StatelessWidget {
  final String label;

  const _DeliveryStatusChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.creamSoft,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _DeliveryUpdateDialog extends StatefulWidget {
  final AdminApiService apiService;
  final OrderModel order;

  const _DeliveryUpdateDialog({
    required this.apiService,
    required this.order,
  });

  @override
  State<_DeliveryUpdateDialog> createState() => _DeliveryUpdateDialogState();
}

class _DeliveryUpdateDialogState extends State<_DeliveryUpdateDialog> {
  late String _status;
  late final TextEditingController _notesController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _status = widget.order.orderStatus;
    _notesController = TextEditingController(text: widget.order.adminNotes ?? '');
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await widget.apiService.updateDelivery(widget.order.id, {
        'order_status': _status,
        'admin_notes': _notesController.text.trim(),
      });
      if (!mounted) {
        return;
      }
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
      title: Text(widget.order.orderNumber),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _status,
              decoration: const InputDecoration(labelText: 'Delivery Status'),
              items: _AdminDeliveriesPageState._statuses
                  .map(
                    (status) => DropdownMenuItem<String>(
                      value: status,
                      child: Text(_deliveryStatusLabel(status)),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _status = value ?? _status),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _notesController,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Admin Notes'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Saving...' : 'Save'),
        ),
      ],
    );
  }
}

class _DeliveriesError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _DeliveriesError({
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

String _deliveryStatusLabel(String status) {
  switch (status) {
    case 'preparing':
      return 'Preparing';
    case 'out_for_delivery':
      return 'Out for Delivery';
    case 'delivered':
      return 'Delivered';
    case 'cancelled':
      return 'Cancelled';
    default:
      return status;
  }
}
