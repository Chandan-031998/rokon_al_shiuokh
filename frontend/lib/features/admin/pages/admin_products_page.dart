import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/premium_network_image.dart';
import '../../../../models/branch_model.dart';
import '../../../../models/category_model.dart';
import '../../../../models/product_model.dart';
import '../services/admin_api_service.dart';
import '../widgets/admin_page_frame.dart';

class AdminProductsPage extends StatefulWidget {
  final AdminApiService apiService;

  const AdminProductsPage({
    super.key,
    required this.apiService,
  });

  @override
  State<AdminProductsPage> createState() => _AdminProductsPageState();
}

class _AdminProductsPageState extends State<AdminProductsPage> {
  final _searchController = TextEditingController();
  int? _categoryId;
  int? _branchId;
  bool _loading = true;
  String? _error;
  List<ProductModel> _products = const [];
  List<CategoryModel> _categories = const [];
  List<BranchModel> _branches = const [];

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
        widget.apiService.fetchProducts(
          search: _searchController.text,
          categoryId: _categoryId,
          branchId: _branchId,
        ),
        widget.apiService.fetchCategories(),
        widget.apiService.fetchBranches(),
      ]);
      if (!mounted) {
        return;
      }
      setState(() {
        _products = results[0] as List<ProductModel>;
        _categories = results[1] as List<CategoryModel>;
        _branches = results[2] as List<BranchModel>;
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

  Future<void> _openEditor([ProductModel? product]) async {
    final changed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _ProductEditorDialog(
        apiService: widget.apiService,
        categories: _categories,
        branches: _branches,
        product: product,
      ),
    );
    if (changed == true) {
      await _load();
    }
  }

  Future<void> _deleteProduct(ProductModel product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Product'),
        content: Text('Delete "${product.name}" permanently?'),
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
      await widget.apiService.deleteProduct(product.id);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Product deleted successfully.')),
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
      title: 'Products',
      subtitle: 'Manage catalog records, pricing, featured flags, branch assignment, stock, and product imagery.',
      actions: [
        OutlinedButton.icon(
          onPressed: _load,
          icon: const Icon(Icons.refresh),
          label: const Text('Refresh'),
        ),
        ElevatedButton.icon(
          onPressed: _categories.isEmpty || _branches.isEmpty ? null : () => _openEditor(),
          icon: const Icon(Icons.add),
          label: const Text('Add Product'),
        ),
      ],
      child: Column(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 1120;

              final searchField = TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  labelText: 'Search products',
                  prefixIcon: Icon(Icons.search),
                ),
                onSubmitted: (_) => _load(),
              );

              final categoryField = DropdownButtonFormField<int?>(
                initialValue: _categoryId,
                decoration: const InputDecoration(labelText: 'Category'),
                items: [
                  const DropdownMenuItem<int?>(value: null, child: Text('All categories')),
                  ..._categories.map(
                    (category) => DropdownMenuItem<int?>(
                      value: category.id,
                      child: Text(category.name),
                    ),
                  ),
                ],
                onChanged: (value) => setState(() => _categoryId = value),
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
                          searchField,
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(child: categoryField),
                              const SizedBox(width: 12),
                              Expanded(child: branchField),
                            ],
                          ),
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
                            flex: 6,
                            child: searchField,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            flex: 2,
                            child: categoryField,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            flex: 2,
                            child: branchField,
                          ),
                          const SizedBox(width: 14),
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
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(64),
              child: CircularProgressIndicator(),
            )
          else if (_error != null)
            _InlineError(message: _error!, onRetry: _load)
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.border),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  dataRowMinHeight: 82,
                  dataRowMaxHeight: 92,
                  columnSpacing: 18,
                  columns: const [
                    DataColumn(label: Text('Product')),
                    DataColumn(label: Text('Category')),
                    DataColumn(label: Text('Branch')),
                    DataColumn(label: Text('Price')),
                    DataColumn(label: Text('Stock')),
                    DataColumn(label: Text('Pack Size')),
                    DataColumn(label: Text('Featured')),
                    DataColumn(label: Text('Actions')),
                  ],
                  rows: _products
                      .map(
                        (product) => DataRow(
                          cells: [
                            DataCell(
                              SizedBox(
                                width: 320,
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Container(
                                      width: 56,
                                      height: 56,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(color: AppColors.border),
                                      ),
                                      clipBehavior: Clip.antiAlias,
                                      child: PremiumNetworkImage(
                                        imageUrl: product.imageUrl,
                                        width: 56,
                                        height: 56,
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            product.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: Theme.of(context)
                                                .textTheme
                                                .labelLarge
                                                ?.copyWith(fontWeight: FontWeight.w700),
                                          ),
                                          if ((product.sku ?? '').isNotEmpty)
                                            Text(
                                              product.sku!,
                                              style: Theme.of(context).textTheme.bodySmall,
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            DataCell(Text(product.categoryName ?? '-')),
                            DataCell(Text(product.branchName ?? '-')),
                            DataCell(Text('SAR ${product.price.toStringAsFixed(2)}')),
                            DataCell(Text('${product.stockQty}')),
                            DataCell(Text(product.packSize ?? '-')),
                            DataCell(
                              Icon(
                                product.isFeatured ? Icons.star_rounded : Icons.star_border_rounded,
                                color: product.isFeatured ? AppColors.goldMuted : AppColors.textMuted,
                              ),
                            ),
                            DataCell(
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _TableActionButton(
                                    tooltip: 'Edit',
                                    icon: Icons.edit_outlined,
                                    onPressed: () => _openEditor(product),
                                  ),
                                  const SizedBox(width: 8),
                                  _TableActionButton(
                                    tooltip: 'Delete',
                                    icon: Icons.delete_outline,
                                    onPressed: () => _deleteProduct(product),
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
            ),
        ],
      ),
    );
  }
}

class _ProductEditorDialog extends StatefulWidget {
  final AdminApiService apiService;
  final List<CategoryModel> categories;
  final List<BranchModel> branches;
  final ProductModel? product;

  const _ProductEditorDialog({
    required this.apiService,
    required this.categories,
    required this.branches,
    this.product,
  });

  @override
  State<_ProductEditorDialog> createState() => _ProductEditorDialogState();
}

class _ProductEditorDialogState extends State<_ProductEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _nameArController;
  late final TextEditingController _skuController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _priceController;
  late final TextEditingController _stockController;
  late final TextEditingController _packSizeController;
  int? _categoryId;
  int? _branchId;
  bool _isFeatured = false;
  bool _isActive = true;
  bool _saving = false;
  bool _uploadingImage = false;
  String? _imageUrl;

  @override
  void initState() {
    super.initState();
    final product = widget.product;
    _nameController = TextEditingController(text: product?.name ?? '');
    _nameArController = TextEditingController(text: product?.nameAr ?? '');
    _skuController = TextEditingController(text: product?.sku ?? '');
    _descriptionController = TextEditingController(text: product?.description ?? '');
    _priceController = TextEditingController(
      text: product == null ? '' : product.price.toStringAsFixed(2),
    );
    _stockController = TextEditingController(text: '${product?.stockQty ?? 0}');
    _packSizeController = TextEditingController(text: product?.packSize ?? '');
    _categoryId = product?.categoryId ?? (widget.categories.isNotEmpty ? widget.categories.first.id : null);
    _branchId = product?.branchId ?? (widget.branches.isNotEmpty ? widget.branches.first.id : null);
    _isFeatured = product?.isFeatured ?? false;
    _isActive = product?.isActive ?? true;
    _imageUrl = product?.imageUrl;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nameArController.dispose();
    _skuController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    _packSizeController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    if (_uploadingImage) {
      return;
    }
    final file = await FilePicker.platform.pickFiles(
      withData: true,
      type: FileType.image,
    );
    final selected = file?.files.single;
    final bytes = selected?.bytes;
    if (selected == null || bytes == null || bytes.isEmpty) {
      return;
    }

    setState(() => _uploadingImage = true);
    try {
      final uploadedUrl = await widget.apiService.uploadProductImage(
        bytes: bytes,
        filename: selected.name,
        contentType: _contentTypeForName(selected.name),
      );
      if (!mounted) {
        return;
      }
      setState(() => _imageUrl = uploadedUrl);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Image uploaded successfully.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) {
        setState(() => _uploadingImage = false);
      }
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _saving = true);
    try {
      final payload = {
        'name': _nameController.text.trim(),
        'name_ar': _nameArController.text.trim(),
        'sku': _skuController.text.trim(),
        'description': _descriptionController.text.trim(),
        'price': double.parse(_priceController.text.trim()),
        'stock_qty': int.parse(_stockController.text.trim()),
        'pack_size': _packSizeController.text.trim(),
        'image_url': _imageUrl,
        'category_id': _categoryId,
        'branch_id': _branchId,
        'is_featured': _isFeatured,
        'is_active': _isActive,
      };

      if (widget.product == null) {
        await widget.apiService.createProduct(payload);
      } else {
        await widget.apiService.updateProduct(widget.product!.id, payload);
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
    final media = MediaQuery.of(context);
    final uniqueCategories = <CategoryModel>[
      for (final category in widget.categories)
        if (widget.categories.indexWhere((item) => item.id == category.id) ==
            widget.categories.indexOf(category))
          category,
    ];
    final uniqueBranches = <BranchModel>[
      for (final branch in widget.branches)
        if (widget.branches.indexWhere((item) => item.id == branch.id) ==
            widget.branches.indexOf(branch))
          branch,
    ];
    final safeCategoryId = uniqueCategories.any((item) => item.id == _categoryId)
        ? _categoryId
        : null;
    final safeBranchId =
        uniqueBranches.any((item) => item.id == _branchId) ? _branchId : null;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 860,
          maxHeight: media.size.height * 0.88,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.product == null ? 'Add Product' : 'Edit Product',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                  IconButton(
                    onPressed: _saving ? null : () => Navigator.of(context).pop(false),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final stacked = constraints.maxWidth < 720;
                          final fields = Column(
                            children: [
                              TextFormField(
                                controller: _nameController,
                                decoration: const InputDecoration(labelText: 'Name'),
                                validator: (value) =>
                                    (value ?? '').trim().isEmpty ? 'Name is required.' : null,
                              ),
                              const SizedBox(height: 14),
                              TextFormField(
                                controller: _nameArController,
                                decoration: const InputDecoration(labelText: 'Arabic Name'),
                              ),
                              const SizedBox(height: 14),
                              TextFormField(
                                controller: _skuController,
                                decoration: const InputDecoration(labelText: 'SKU'),
                              ),
                              const SizedBox(height: 14),
                              TextFormField(
                                controller: _packSizeController,
                                decoration: const InputDecoration(labelText: 'Pack Size'),
                              ),
                            ],
                          );

                          final imagePanel = SizedBox(
                            width: stacked ? double.infinity : 180,
                            child: Column(
                              children: [
                                PremiumNetworkImage(
                                  imageUrl: _imageUrl,
                                  height: 160,
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                const SizedBox(height: 12),
                                OutlinedButton.icon(
                                  onPressed: _uploadingImage ? null : _pickImage,
                                  icon: _uploadingImage
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        )
                                      : const Icon(Icons.upload),
                                  label: Text(_uploadingImage ? 'Uploading...' : 'Upload Image'),
                                ),
                              ],
                            ),
                          );

                          if (stacked) {
                            return Column(
                              children: [
                                fields,
                                const SizedBox(height: 18),
                                imagePanel,
                              ],
                            );
                          }

                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: fields),
                              const SizedBox(width: 18),
                              imagePanel,
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _descriptionController,
                        maxLines: 3,
                        decoration: const InputDecoration(labelText: 'Description'),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _priceController,
                              decoration: const InputDecoration(labelText: 'Price'),
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              validator: (value) {
                                final parsed = double.tryParse((value ?? '').trim());
                                if (parsed == null || parsed < 0) {
                                  return 'Enter a valid price.';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _stockController,
                              decoration: const InputDecoration(labelText: 'Stock'),
                              keyboardType: TextInputType.number,
                              validator: (value) {
                                final parsed = int.tryParse((value ?? '').trim());
                                if (parsed == null || parsed < 0) {
                                  return 'Enter a valid stock value.';
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              initialValue: safeCategoryId,
                              decoration: const InputDecoration(labelText: 'Category'),
                              items: uniqueCategories
                                  .map(
                                    (category) => DropdownMenuItem<int>(
                                      value: category.id,
                                      child: Text(category.name),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) => setState(() => _categoryId = value),
                              validator: (value) => value == null ? 'Select a category.' : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              initialValue: safeBranchId,
                              decoration: const InputDecoration(labelText: 'Branch'),
                              items: uniqueBranches
                                  .map(
                                    (branch) => DropdownMenuItem<int>(
                                      value: branch.id,
                                      child: Text(branch.name),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) => setState(() => _branchId = value),
                              validator: (value) => value == null ? 'Select a branch.' : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: SwitchListTile(
                              value: _isFeatured,
                              title: const Text('Featured'),
                              contentPadding: EdgeInsets.zero,
                              onChanged: (value) => setState(() => _isFeatured = value),
                            ),
                          ),
                          Expanded(
                            child: SwitchListTile(
                              value: _isActive,
                              title: const Text('Active'),
                              contentPadding: EdgeInsets.zero,
                              onChanged: (value) => setState(() => _isActive = value),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _saving ? null : () => Navigator.of(context).pop(false),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _saving ? null : _save,
                    child: Text(_saving ? 'Saving...' : 'Save'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _contentTypeForName(String filename) {
  final lower = filename.toLowerCase();
  if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
    return 'image/jpeg';
  }
  if (lower.endsWith('.webp')) {
    return 'image/webp';
  }
  return 'image/png';
}

class _InlineError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _InlineError({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Unable to load products', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(message),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

class _TableActionButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  const _TableActionButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: AppColors.creamSoft,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onPressed,
          child: SizedBox(
            width: 40,
            height: 40,
            child: Icon(
              icon,
              size: 20,
              color: AppColors.brownDeep,
            ),
          ),
        ),
      ),
    );
  }
}
