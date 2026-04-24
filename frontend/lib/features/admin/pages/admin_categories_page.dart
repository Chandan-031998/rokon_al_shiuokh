import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../models/category_model.dart';
import '../services/admin_api_service.dart';
import '../widgets/admin_page_frame.dart';

class AdminCategoriesPage extends StatefulWidget {
  final AdminApiService apiService;

  const AdminCategoriesPage({
    super.key,
    required this.apiService,
  });

  @override
  State<AdminCategoriesPage> createState() => _AdminCategoriesPageState();
}

class _AdminCategoriesPageState extends State<AdminCategoriesPage> {
  bool _loading = true;
  String? _error;
  List<CategoryModel> _categories = const [];

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
      final categories = await widget.apiService.fetchCategories();
      if (!mounted) {
        return;
      }
      setState(() {
        _categories = categories;
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

  Future<void> _openEditor([CategoryModel? category]) async {
    final changed = await showDialog<bool>(
      context: context,
      builder: (context) => _CategoryEditorDialog(
        apiService: widget.apiService,
        category: category,
      ),
    );
    if (changed == true) {
      await _load();
    }
  }

  Future<void> _deleteCategory(CategoryModel category) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Category'),
        content: Text('Delete "${category.name}"?'),
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
      await widget.apiService.deleteCategory(category.id);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Category deleted successfully.')),
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
    return AdminPageFrame(
      title: 'Categories',
      subtitle:
          'Maintain category names, Arabic labels, ordering, and active state.',
      actions: [
        OutlinedButton.icon(
          onPressed: _load,
          icon: const Icon(Icons.refresh),
          label: const Text('Refresh'),
        ),
        ElevatedButton.icon(
          onPressed: () => _openEditor(),
          icon: const Icon(Icons.add),
          label: const Text('Add Category'),
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
                ? _SimpleError(message: _error!, onRetry: _load)
                : DataTable(
                    columns: const [
                      DataColumn(label: Text('English Name')),
                      DataColumn(label: Text('Arabic Name')),
                      DataColumn(label: Text('Media / Icon')),
                      DataColumn(label: Text('Products')),
                      DataColumn(label: Text('Sort')),
                      DataColumn(label: Text('Active')),
                      DataColumn(label: Text('Actions')),
                    ],
                    rows: _categories
                        .map(
                          (category) => DataRow(
                            cells: [
                              DataCell(Text(category.nameEn ?? category.name)),
                              DataCell(Text(category.nameAr ?? '-')),
                              DataCell(
                                Text(
                                  (category.imageUrl ?? '').isNotEmpty
                                      ? 'Image'
                                      : (category.iconKey ?? '-'),
                                ),
                              ),
                              DataCell(Text('${category.productCount}')),
                              DataCell(Text('${category.sortOrder}')),
                              DataCell(Icon(
                                category.isActive
                                    ? Icons.check_circle
                                    : Icons.cancel_outlined,
                                color: category.isActive
                                    ? Colors.green
                                    : AppColors.textMuted,
                              )),
                              DataCell(
                                Wrap(
                                  spacing: 8,
                                  children: [
                                    IconButton(
                                      onPressed: () => _openEditor(category),
                                      icon: const Icon(Icons.edit_outlined),
                                    ),
                                    IconButton(
                                      onPressed: () =>
                                          _deleteCategory(category),
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

class _CategoryEditorDialog extends StatefulWidget {
  final AdminApiService apiService;
  final CategoryModel? category;

  const _CategoryEditorDialog({
    required this.apiService,
    this.category,
  });

  @override
  State<_CategoryEditorDialog> createState() => _CategoryEditorDialogState();
}

class _CategoryEditorDialogState extends State<_CategoryEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _nameEnController;
  late final TextEditingController _nameArController;
  late final TextEditingController _imageUrlController;
  late final TextEditingController _iconKeyController;
  late final TextEditingController _sortOrderController;
  bool _isActive = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final category = widget.category;
    _nameController = TextEditingController(text: category?.name ?? '');
    _nameEnController =
        TextEditingController(text: category?.nameEn ?? category?.name ?? '');
    _nameEnController.addListener(() {
      final nextValue = _nameEnController.text;
      if (_nameController.text != nextValue) {
        _nameController.value = TextEditingValue(
          text: nextValue,
          selection: TextSelection.collapsed(offset: nextValue.length),
        );
      }
    });
    _nameArController = TextEditingController(text: category?.nameAr ?? '');
    _imageUrlController = TextEditingController(text: category?.imageUrl ?? '');
    _iconKeyController = TextEditingController(text: category?.iconKey ?? '');
    _sortOrderController =
        TextEditingController(text: '${category?.sortOrder ?? 0}');
    _isActive = category?.isActive ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nameEnController.dispose();
    _nameArController.dispose();
    _imageUrlController.dispose();
    _iconKeyController.dispose();
    _sortOrderController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _saving = true);
    try {
      final payload = {
        'name': _nameEnController.text.trim(),
        'name_en': _nameEnController.text.trim(),
        'name_ar': _nameArController.text.trim(),
        'image_url': _imageUrlController.text.trim(),
        'icon_key': _iconKeyController.text.trim(),
        'sort_order': int.parse(_sortOrderController.text.trim()),
        'is_active': _isActive,
      };
      if (widget.category == null) {
        await widget.apiService.createCategory(payload);
      } else {
        await widget.apiService.updateCategory(widget.category!.id, payload);
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
    return AlertDialog(
      title: Text(widget.category == null ? 'Add Category' : 'Edit Category'),
      content: SizedBox(
        width: 520,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameEnController,
                decoration:
                    const InputDecoration(labelText: 'Category Name (English)'),
                validator: (value) => (value ?? '').trim().isEmpty
                    ? 'English name is required.'
                    : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Legacy Name Mirror',
                  hintText:
                      'Kept aligned with English label for existing screens',
                ),
                readOnly: true,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _nameArController,
                decoration:
                    const InputDecoration(labelText: 'Category Name (Arabic)'),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _imageUrlController,
                decoration: const InputDecoration(labelText: 'Image URL'),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _iconKeyController,
                decoration: const InputDecoration(
                  labelText: 'Icon Key',
                  hintText: 'coffee, spices, incense',
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _sortOrderController,
                decoration: const InputDecoration(labelText: 'Sort Order'),
                keyboardType: TextInputType.number,
                validator: (value) => int.tryParse((value ?? '').trim()) == null
                    ? 'Enter a valid sort order.'
                    : null,
              ),
              SwitchListTile(
                value: _isActive,
                contentPadding: EdgeInsets.zero,
                title: const Text('Active'),
                onChanged: (value) => setState(() => _isActive = value),
              ),
            ],
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

class _SimpleError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _SimpleError({
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
