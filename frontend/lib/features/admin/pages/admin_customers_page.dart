import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
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
      final customers = await widget.apiService.fetchCustomers(search: _searchController.text);
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
    return AdminPageFrame(
      title: 'Customers',
      subtitle: 'Inspect customer profiles, saved addresses, preferred branch, and order history.',
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
                      labelText: 'Search customers',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onSubmitted: (_) => _load(),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _load,
                  child: const Text('Search'),
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
                    ? _CustomersError(message: _error!, onRetry: _load)
                    : DataTable(
                        columns: const [
                          DataColumn(label: Text('Customer')),
                          DataColumn(label: Text('Phone')),
                          DataColumn(label: Text('Orders')),
                          DataColumn(label: Text('Total Spent')),
                          DataColumn(label: Text('Actions')),
                        ],
                        rows: _customers
                            .map(
                              (customer) => DataRow(
                                cells: [
                                  DataCell(
                                    Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(customer.fullName),
                                        Text(customer.email, style: Theme.of(context).textTheme.bodySmall),
                                      ],
                                    ),
                                  ),
                                  DataCell(Text(customer.phone ?? '-')),
                                  DataCell(Text('${customer.orderCount}')),
                                  DataCell(Text('SAR ${customer.totalSpent.toStringAsFixed(2)}')),
                                  DataCell(
                                    TextButton(
                                      onPressed: () => _openDetail(customer),
                                      child: const Text('View Details'),
                                    ),
                                  ),
                                ],
                              ),
                            )
                            .toList(),
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
      final orders = await widget.apiService.fetchOrders(search: customer.email);
      if (!mounted) {
        return;
      }
      setState(() {
        _customer = customer;
        _orders = orders.where((order) => order.customer?.id == customer.id).toList();
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
    return AlertDialog(
      title: const Text('Customer Details'),
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
                    Text(_customer!.fullName, style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 8),
                    Text(_customer!.email),
                    if ((_customer!.phone ?? '').isNotEmpty) Text(_customer!.phone!),
                    const SizedBox(height: 18),
                    if (_customer!.preferredBranch != null) ...[
                      Text('Preferred Branch', style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 6),
                      Text(_customer!.preferredBranch!.name),
                      const SizedBox(height: 18),
                    ],
                    Text('Saved Addresses', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 8),
                    ..._customer!.addresses.map(
                      (address) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(address.label),
                        subtitle: Text('${address.city}, ${address.neighborhood}\n${address.addressLine}'),
                        isThreeLine: true,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text('Order History', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 8),
                    ..._orders.map(
                      (order) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(order.orderNumber),
                        subtitle: Text(order.orderStatus),
                        trailing: Text('SAR ${order.totalAmount.toStringAsFixed(2)}'),
                      ),
                    ),
                  ],
                ),
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
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
