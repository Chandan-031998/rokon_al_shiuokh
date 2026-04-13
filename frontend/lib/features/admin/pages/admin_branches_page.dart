import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../models/branch_model.dart';
import '../services/admin_api_service.dart';
import '../widgets/admin_page_frame.dart';

class AdminBranchesPage extends StatefulWidget {
  final AdminApiService apiService;

  const AdminBranchesPage({
    super.key,
    required this.apiService,
  });

  @override
  State<AdminBranchesPage> createState() => _AdminBranchesPageState();
}

class _AdminBranchesPageState extends State<AdminBranchesPage> {
  bool _loading = true;
  String? _error;
  List<BranchModel> _branches = const [];

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
      final branches = await widget.apiService.fetchBranches();
      if (!mounted) {
        return;
      }
      setState(() {
        _branches = branches;
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

  Future<void> _openEditor([BranchModel? branch]) async {
    final changed = await showDialog<bool>(
      context: context,
      builder: (context) => _BranchEditorDialog(
        apiService: widget.apiService,
        branch: branch,
      ),
    );
    if (changed == true) {
      await _load();
    }
  }

  Future<void> _deleteBranch(BranchModel branch) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Branch'),
        content: Text('Delete "${branch.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    try {
      await widget.apiService.deleteBranch(branch.id);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Branch deleted successfully.')),
      );
      await _load();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminPageFrame(
      title: 'Branches',
      subtitle: 'Control pickup and delivery availability, branch contact details, and branch-level operations.',
      actions: [
        OutlinedButton.icon(
          onPressed: _load,
          icon: const Icon(Icons.refresh),
          label: const Text('Refresh'),
        ),
        ElevatedButton.icon(
          onPressed: () => _openEditor(),
          icon: const Icon(Icons.add_business),
          label: const Text('Add Branch'),
        ),
      ],
      child: Container(
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
                ? _BranchError(message: _error!, onRetry: _load)
                : DataTable(
                    columns: const [
                      DataColumn(label: Text('Branch')),
                      DataColumn(label: Text('Phone')),
                      DataColumn(label: Text('Pickup')),
                      DataColumn(label: Text('Delivery')),
                      DataColumn(label: Text('Products')),
                      DataColumn(label: Text('Orders')),
                      DataColumn(label: Text('Actions')),
                    ],
                    rows: _branches
                        .map(
                          (branch) => DataRow(
                            cells: [
                              DataCell(
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(branch.name),
                                    if ((branch.city ?? '').isNotEmpty)
                                      Text(branch.city!, style: Theme.of(context).textTheme.bodySmall),
                                  ],
                                ),
                              ),
                              DataCell(Text(branch.phone ?? '-')),
                              DataCell(Icon(
                                branch.pickupAvailable ? Icons.check_circle : Icons.cancel_outlined,
                                color: branch.pickupAvailable ? Colors.green : AppColors.textMuted,
                              )),
                              DataCell(Icon(
                                branch.deliveryAvailable ? Icons.check_circle : Icons.cancel_outlined,
                                color: branch.deliveryAvailable ? Colors.green : AppColors.textMuted,
                              )),
                              DataCell(Text('${branch.productCount}')),
                              DataCell(Text('${branch.orderCount}')),
                              DataCell(
                                Wrap(
                                  spacing: 8,
                                  children: [
                                    IconButton(
                                      onPressed: () => _openEditor(branch),
                                      icon: const Icon(Icons.edit_outlined),
                                    ),
                                    IconButton(
                                      onPressed: () => _deleteBranch(branch),
                                      icon: const Icon(Icons.delete_outline),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        )
                        .toList(),
                  ),
      ),
    );
  }
}

class _BranchEditorDialog extends StatefulWidget {
  final AdminApiService apiService;
  final BranchModel? branch;

  const _BranchEditorDialog({
    required this.apiService,
    this.branch,
  });

  @override
  State<_BranchEditorDialog> createState() => _BranchEditorDialogState();
}

class _BranchEditorDialogState extends State<_BranchEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _cityController;
  late final TextEditingController _addressController;
  late final TextEditingController _phoneController;
  late final TextEditingController _coverageController;
  bool _isActive = true;
  bool _pickupAvailable = true;
  bool _deliveryAvailable = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final branch = widget.branch;
    _nameController = TextEditingController(text: branch?.name ?? '');
    _cityController = TextEditingController(text: branch?.city ?? '');
    _addressController = TextEditingController(text: branch?.address ?? '');
    _phoneController = TextEditingController(text: branch?.phone ?? '');
    _coverageController = TextEditingController(text: branch?.deliveryCoverage ?? '');
    _isActive = branch?.isActive ?? true;
    _pickupAvailable = branch?.pickupAvailable ?? true;
    _deliveryAvailable = branch?.deliveryAvailable ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _cityController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _coverageController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _saving = true);
    try {
      final payload = {
        'name': _nameController.text.trim(),
        'city': _cityController.text.trim(),
        'address': _addressController.text.trim(),
        'phone': _phoneController.text.trim(),
        'delivery_coverage': _coverageController.text.trim(),
        'is_active': _isActive,
        'pickup_available': _pickupAvailable,
        'delivery_available': _deliveryAvailable,
      };
      if (widget.branch == null) {
        await widget.apiService.createBranch(payload);
      } else {
        await widget.apiService.updateBranch(widget.branch!.id, payload);
      }
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
      title: Text(widget.branch == null ? 'Add Branch' : 'Edit Branch'),
      content: SizedBox(
        width: 620,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Name'),
                  validator: (value) => (value ?? '').trim().isEmpty ? 'Name is required.' : null,
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _cityController,
                        decoration: const InputDecoration(labelText: 'City'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _phoneController,
                        decoration: const InputDecoration(labelText: 'Phone'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _addressController,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Address'),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _coverageController,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Delivery Coverage'),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  value: _isActive,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Active'),
                  onChanged: (value) => setState(() => _isActive = value),
                ),
                SwitchListTile(
                  value: _pickupAvailable,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Pickup Available'),
                  onChanged: (value) => setState(() => _pickupAvailable = value),
                ),
                SwitchListTile(
                  value: _deliveryAvailable,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Delivery Available'),
                  onChanged: (value) => setState(() => _deliveryAvailable = value),
                ),
              ],
            ),
          ),
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

class _BranchError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _BranchError({
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
