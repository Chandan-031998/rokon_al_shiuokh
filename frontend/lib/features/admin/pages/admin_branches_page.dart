import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../localization/app_localizations.dart';
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
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.t('admin_branches_delete_title')),
        content: Text(
            l10n.t('admin_branches_delete_message', {'name': branch.name})),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.t('common_cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.t('common_delete')),
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
        SnackBar(content: Text(l10n.t('admin_branches_delete_success'))),
      );
      await _load();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(error.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AdminPageFrame(
      title: l10n.t('admin_branches_title'),
      subtitle: l10n.t('admin_branches_subtitle'),
      actions: [
        OutlinedButton.icon(
          onPressed: _load,
          icon: const Icon(Icons.refresh),
          label: Text(l10n.t('common_refresh')),
        ),
        ElevatedButton.icon(
          onPressed: () => _openEditor(),
          icon: const Icon(Icons.add_business),
          label: Text(l10n.t('admin_branches_add')),
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
            ? const Center(
                child: Padding(
                padding: EdgeInsets.all(48),
                child: CircularProgressIndicator(),
              ))
            : _error != null
                ? _BranchError(message: _error!, onRetry: _load)
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columns: [
                        DataColumn(
                            label: Text(l10n.t('admin_branches_col_branch'))),
                        DataColumn(
                            label: Text(l10n.t('admin_branches_col_phone'))),
                        const DataColumn(label: Text('Map')),
                        DataColumn(
                            label: Text(l10n.t('admin_branches_col_pickup'))),
                        DataColumn(
                            label: Text(l10n.t('admin_branches_col_delivery'))),
                        const DataColumn(label: Text('Status')),
                        DataColumn(
                            label: Text(l10n.t('admin_branches_col_products'))),
                        DataColumn(
                            label: Text(l10n.t('admin_branches_col_orders'))),
                        DataColumn(
                            label: Text(l10n.t('admin_products_col_actions'))),
                      ],
                      rows: _branches
                          .map(
                            (branch) => DataRow(
                              cells: [
                                DataCell(
                                  Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(branch.name),
                                      if ((branch.city ?? '').isNotEmpty)
                                        Text(branch.city!,
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall),
                                    ],
                                  ),
                                ),
                                DataCell(Text(branch.phone ??
                                    l10n.t('common_not_available'))),
                                DataCell(
                                  Text(
                                    (branch.mapLink ?? '').isEmpty
                                        ? l10n.t('common_not_available')
                                        : 'Available',
                                  ),
                                ),
                                DataCell(Icon(
                                  branch.pickupAvailable
                                      ? Icons.check_circle
                                      : Icons.cancel_outlined,
                                  color: branch.pickupAvailable
                                      ? Colors.green
                                      : AppColors.textMuted,
                                )),
                                DataCell(Icon(
                                  branch.deliveryAvailable
                                      ? Icons.check_circle
                                      : Icons.cancel_outlined,
                                  color: branch.deliveryAvailable
                                      ? Colors.green
                                      : AppColors.textMuted,
                                )),
                                DataCell(Icon(
                                  branch.isActive
                                      ? Icons.check_circle
                                      : Icons.cancel_outlined,
                                  color: branch.isActive
                                      ? Colors.green
                                      : AppColors.textMuted,
                                )),
                                DataCell(Text('${branch.productCount}')),
                                DataCell(Text('${branch.orderCount}')),
                                DataCell(
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        tooltip: l10n.t('common_edit'),
                                        onPressed: () => _openEditor(branch),
                                        icon: const Icon(Icons.edit_outlined),
                                      ),
                                      IconButton(
                                        tooltip: l10n.t('common_delete'),
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
                    )),
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
  late final TextEditingController _mapLinkController;
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
    _mapLinkController = TextEditingController(text: branch?.mapLink ?? '');
    _coverageController =
        TextEditingController(text: branch?.deliveryCoverage ?? '');
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
    _mapLinkController.dispose();
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
        'map_link': _mapLinkController.text.trim(),
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
      title: Text(
        widget.branch == null
            ? l10n.t('admin_branches_add')
            : l10n.t('common_edit'),
      ),
      content: SizedBox(
        width: 620,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final stacked = constraints.maxWidth < 520;
                final cityField = TextFormField(
                  controller: _cityController,
                  decoration:
                      InputDecoration(labelText: l10n.t('checkout_city')),
                );
                final phoneField = TextFormField(
                  controller: _phoneController,
                  decoration:
                      InputDecoration(labelText: l10n.t('field_phone')),
                );
                final mapField = TextFormField(
                  controller: _mapLinkController,
                  decoration: const InputDecoration(
                    labelText: 'Map Link',
                    hintText: 'https://maps.google.com/...',
                  ),
                );

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(
                          labelText: l10n.t('admin_field_name')),
                      validator: (value) => (value ?? '').trim().isEmpty
                          ? l10n.t('admin_validation_name_required')
                          : null,
                    ),
                    const SizedBox(height: 14),
                    if (stacked) ...[
                      cityField,
                      const SizedBox(height: 12),
                      phoneField,
                      const SizedBox(height: 12),
                      mapField,
                    ] else
                      Row(
                        children: [
                          Expanded(child: cityField),
                          const SizedBox(width: 12),
                          Expanded(child: phoneField),
                          const SizedBox(width: 12),
                          Expanded(child: mapField),
                        ],
                      ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _addressController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: l10n.t('checkout_address_line'),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _coverageController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: l10n.t('admin_branches_field_coverage'),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.creamSoft,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        children: [
                          SwitchListTile(
                            value: _isActive,
                            contentPadding: EdgeInsets.zero,
                            title: Text(l10n.t('common_active')),
                            onChanged: (value) => setState(() => _isActive = value),
                          ),
                          SwitchListTile(
                            value: _pickupAvailable,
                            contentPadding: EdgeInsets.zero,
                            title: Text(l10n.t('admin_branches_col_pickup')),
                            onChanged: (value) =>
                                setState(() => _pickupAvailable = value),
                          ),
                          SwitchListTile(
                            value: _deliveryAvailable,
                            contentPadding: EdgeInsets.zero,
                            title: Text(l10n.t('admin_branches_col_delivery')),
                            onChanged: (value) =>
                                setState(() => _deliveryAvailable = value),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: Text(l10n.t('common_cancel')),
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
          label: Text(context.l10n.t('common_retry')),
        ),
      ],
    );
  }
}
