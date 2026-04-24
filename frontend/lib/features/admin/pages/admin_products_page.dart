import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../localization/app_localizations.dart';
import '../../../../core/widgets/premium_network_image.dart';
import '../../../../models/branch_model.dart';
import '../../../../models/category_model.dart';
import '../../../../models/product_image_model.dart';
import '../../../../models/product_model.dart';
import '../services/admin_api_service.dart';
import '../utils/admin_image_picker.dart';
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
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _ProductEditorDialog(
        apiService: widget.apiService,
        categories: _categories,
        branches: _branches,
        product: product,
      ),
    );
    if (result != null) {
      if (!mounted) {
        return;
      }
      final message = switch (result) {
        'created' => 'Product added successfully.',
        'updated' => 'Product updated successfully.',
        _ => 'Product saved successfully.',
      };
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
      await _load();
    }
  }

  Future<void> _deleteProduct(ProductModel product) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.t('admin_products_delete_title')),
        content: Text(
          l10n.t('admin_products_delete_message', {'name': product.name}),
        ),
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
      await widget.apiService.deleteProduct(product.id);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.t('admin_products_delete_success'))),
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

  Future<void> _toggleProductFlag(
    ProductModel product, {
    bool? featured,
    bool? active,
  }) async {
    try {
      await widget.apiService.updateProduct(
        product.id,
        {
          if (featured != null) 'is_featured': featured,
          if (active != null) 'is_active': active,
        },
      );
      if (!mounted) {
        return;
      }
      final statusMessage = featured != null
          ? (featured
              ? 'Product marked as featured.'
              : 'Product removed from featured products.')
          : (active == true
              ? 'Product activated successfully.'
              : 'Product deactivated successfully.');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(statusMessage)),
      );
      await _load();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AdminPageFrame(
      title: l10n.t('admin_products_title'),
      subtitle: l10n.t('admin_products_subtitle'),
      actions: [
        OutlinedButton.icon(
          onPressed: _load,
          icon: const Icon(Icons.refresh),
          label: Text(l10n.t('common_refresh')),
        ),
        ElevatedButton.icon(
          onPressed: _categories.isEmpty || _branches.isEmpty
              ? null
              : () => _openEditor(),
          icon: const Icon(Icons.add),
          label: Text(l10n.t('admin_quick_add_product')),
        ),
      ],
      child: Column(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final compact = width < 1120;
              final fieldWidth = compact
                  ? double.infinity
                  : ((width - 42) / 4).clamp(180.0, 340.0);

              final searchField = TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  labelText: l10n.t('admin_products_search'),
                  prefixIcon: const Icon(Icons.search),
                ),
                onSubmitted: (_) => _load(),
              );

              final categoryField = DropdownButtonFormField<int?>(
                initialValue: _categoryId,
                decoration: InputDecoration(
                    labelText: l10n.t('products_filter_category')),
                items: [
                  DropdownMenuItem<int?>(
                    value: null,
                    child: Text(l10n.t('products_filter_all_categories')),
                  ),
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
                decoration: InputDecoration(
                    labelText: l10n.t('products_filter_branch')),
                items: [
                  DropdownMenuItem<int?>(
                    value: null,
                    child: Text(l10n.t('products_filter_all_branches')),
                  ),
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
                          categoryField,
                          const SizedBox(height: 14),
                          branchField,
                          const SizedBox(height: 14),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _load,
                              child: Text(l10n.t('common_apply')),
                            ),
                          ),
                        ],
                      )
                    : Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        runSpacing: 14,
                        spacing: 14,
                        crossAxisAlignment: WrapCrossAlignment.end,
                        children: [
                          SizedBox(
                              width: fieldWidth * 1.55, child: searchField),
                          SizedBox(width: fieldWidth, child: categoryField),
                          SizedBox(width: fieldWidth, child: branchField),
                          SizedBox(
                            height: 52,
                            child: ElevatedButton(
                              onPressed: _load,
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 18),
                                child: Text(l10n.t('common_apply')),
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
                  columns: [
                    DataColumn(
                        label: Text(l10n.t('admin_products_col_product'))),
                    DataColumn(
                        label: Text(l10n.t('admin_products_col_category'))),
                    DataColumn(
                        label: Text(l10n.t('admin_products_col_branch'))),
                    DataColumn(label: Text(l10n.t('admin_products_col_price'))),
                    DataColumn(label: Text(l10n.t('admin_products_col_stock'))),
                    DataColumn(
                        label: Text(l10n.t('admin_products_col_pack_size'))),
                    DataColumn(
                        label: Text(l10n.t('admin_products_col_featured'))),
                    const DataColumn(label: Text('Status')),
                    DataColumn(
                        label: Text(l10n.t('admin_products_col_actions'))),
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
                                        border:
                                            Border.all(color: AppColors.border),
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
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            product.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: Theme.of(context)
                                                .textTheme
                                                .labelLarge
                                                ?.copyWith(
                                                    fontWeight:
                                                        FontWeight.w700),
                                          ),
                                          if ((product.sku ?? '').isNotEmpty)
                                            Text(
                                              product.sku!,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall,
                                            ),
                                          if ((product.shortDescription ?? '')
                                              .isNotEmpty)
                                            Text(
                                              product.shortDescription!,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall,
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            DataCell(Text(product.categoryName ??
                                l10n.t('common_not_available'))),
                            DataCell(Text(product.branchName ??
                                l10n.t('common_not_available'))),
                            DataCell(
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${l10n.t('currency_label')} ${product.price.toStringAsFixed(2)}',
                                  ),
                                  if (product.salePrice != null)
                                    Text(
                                      'Sale: ${l10n.t('currency_label')} ${product.salePrice!.toStringAsFixed(2)}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: AppColors.goldMuted,
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                ],
                              ),
                            ),
                            DataCell(Text('${product.stockQty}')),
                            DataCell(Text(product.packSize ??
                                l10n.t('common_not_available'))),
                            DataCell(
                              IconButton(
                                tooltip: product.isFeatured
                                    ? 'Remove from featured'
                                    : 'Mark as featured',
                                onPressed: () => _toggleProductFlag(
                                  product,
                                  featured: !product.isFeatured,
                                ),
                                icon: Icon(
                                  product.isFeatured
                                      ? Icons.star_rounded
                                      : Icons.star_border_rounded,
                                  color: product.isFeatured
                                      ? AppColors.goldMuted
                                      : AppColors.textMuted,
                                ),
                              ),
                            ),
                            DataCell(
                              Switch(
                                value: product.isActive,
                                onChanged: (value) => _toggleProductFlag(
                                  product,
                                  active: value,
                                ),
                              ),
                            ),
                            DataCell(
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _TableActionButton(
                                    tooltip: l10n.t('common_edit'),
                                    icon: Icons.edit_outlined,
                                    onPressed: () => _openEditor(product),
                                  ),
                                  const SizedBox(width: 8),
                                  _TableActionButton(
                                    tooltip: l10n.t('common_delete'),
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
  late final TextEditingController _shortDescriptionController;
  late final TextEditingController _shortDescriptionArController;
  late final TextEditingController _fullDescriptionController;
  late final TextEditingController _fullDescriptionArController;
  late final TextEditingController _priceController;
  late final TextEditingController _salePriceController;
  late final TextEditingController _saPriceController;
  late final TextEditingController _saSalePriceController;
  late final TextEditingController _aePriceController;
  late final TextEditingController _aeSalePriceController;
  late final TextEditingController _stockController;
  late final TextEditingController _packSizeController;
  late final TextEditingController _tagsController;
  int? _categoryId;
  bool _isFeatured = false;
  bool _isActive = true;
  bool _saVisible = true;
  bool _aeVisible = true;
  bool _mahayilAvailable = false;
  bool _abhaAvailable = false;
  bool _saving = false;
  bool _uploadingImage = false;
  List<ProductImageModel> _images = const <ProductImageModel>[];

  Future<void> _dismiss([String? result]) async {
    FocusManager.instance.primaryFocus?.unfocus();
    await Future<void>.delayed(Duration.zero);
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop(result);
  }

  @override
  void initState() {
    super.initState();
    final product = widget.product;
    _nameController = TextEditingController(text: product?.name ?? '');
    _nameArController = TextEditingController(text: product?.nameAr ?? '');
    _skuController = TextEditingController(text: product?.sku ?? '');
    final saPricing = _regionPriceFor(product, 'sa');
    final aePricing = _regionPriceFor(product, 'ae');
    _shortDescriptionController = TextEditingController(
        text: product?.shortDescriptionEn ?? product?.shortDescription ?? '');
    _shortDescriptionArController =
        TextEditingController(text: product?.shortDescriptionAr ?? '');
    _fullDescriptionController = TextEditingController(
        text: product?.fullDescriptionEn ?? product?.fullDescription ?? '');
    _fullDescriptionArController =
        TextEditingController(text: product?.fullDescriptionAr ?? '');
    _priceController = TextEditingController(
      text: product == null ? '' : product.price.toStringAsFixed(2),
    );
    _salePriceController = TextEditingController(
      text: product?.salePrice == null
          ? ''
          : product!.salePrice!.toStringAsFixed(2),
    );
    _saPriceController = TextEditingController(
      text: saPricing?.price.toStringAsFixed(2) ??
          (product == null ? '' : product.price.toStringAsFixed(2)),
    );
    _saSalePriceController = TextEditingController(
      text: saPricing?.salePrice?.toStringAsFixed(2) ??
          (product?.salePrice == null
              ? ''
              : product!.salePrice!.toStringAsFixed(2)),
    );
    _aePriceController = TextEditingController(
      text: aePricing?.price.toStringAsFixed(2) ?? '',
    );
    _aeSalePriceController = TextEditingController(
      text: aePricing?.salePrice?.toStringAsFixed(2) ?? '',
    );
    _stockController = TextEditingController(text: '${product?.stockQty ?? 0}');
    _packSizeController = TextEditingController(text: product?.packSize ?? '');
    _tagsController = TextEditingController(text: product?.tags ?? '');
    _categoryId = product?.categoryId ??
        (widget.categories.isNotEmpty ? widget.categories.first.id : null);
    final mahayilBranch = _namedBranch(widget.branches, 'mahayil');
    final abhaBranch = _namedBranch(widget.branches, 'abha');
    _isFeatured = product?.isFeatured ?? false;
    _isActive = product?.isActive ?? true;
    _saVisible = saPricing?.isVisible ?? true;
    _aeVisible = aePricing?.isVisible ?? false;
    _mahayilAvailable = _branchAvailabilityFor(product, mahayilBranch);
    _abhaAvailable = _branchAvailabilityFor(product, abhaBranch);
    _images = product?.images.isNotEmpty == true
        ? List<ProductImageModel>.from(product!.images)
        : [
            if ((product?.imageUrl ?? '').trim().isNotEmpty)
              ProductImageModel(
                id: 0,
                productId: product?.id,
                imageUrl: product!.imageUrl!,
                sortOrder: 0,
                isPrimary: true,
              ),
          ];
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nameArController.dispose();
    _skuController.dispose();
    _shortDescriptionController.dispose();
    _shortDescriptionArController.dispose();
    _fullDescriptionController.dispose();
    _fullDescriptionArController.dispose();
    _priceController.dispose();
    _salePriceController.dispose();
    _saPriceController.dispose();
    _saSalePriceController.dispose();
    _aePriceController.dispose();
    _aeSalePriceController.dispose();
    _stockController.dispose();
    _packSizeController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    if (_uploadingImage) {
      return;
    }
    final selected = await pickAdminImage();
    if (selected == null) {
      return;
    }

    setState(() => _uploadingImage = true);
    try {
      final uploadedUrl = await widget.apiService.uploadProductImage(
        bytes: selected.bytes,
        filename: selected.filename,
        contentType: selected.contentType,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        final nextImages = List<ProductImageModel>.from(_images);
        final hasPrimary = nextImages.any((image) => image.isPrimary);
        nextImages.add(
          ProductImageModel(
            id: 0,
            productId: widget.product?.id,
            imageUrl: uploadedUrl,
            sortOrder: nextImages.length,
            isPrimary: !hasPrimary,
          ),
        );
        _images = _normalizeImages(nextImages);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Image uploaded successfully.')),
      );
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
        setState(() => _uploadingImage = false);
      }
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_images.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one product image.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final normalizedImages = _normalizeImages(_images);
      final payload = {
        'name': _nameController.text.trim(),
        'name_en': _nameController.text.trim(),
        'name_ar': _nameArController.text.trim(),
        'sku': _skuController.text.trim(),
        'short_description': _shortDescriptionController.text.trim(),
        'short_description_en': _shortDescriptionController.text.trim(),
        'short_description_ar': _shortDescriptionArController.text.trim(),
        'description': _shortDescriptionController.text.trim(),
        'full_description': _fullDescriptionController.text.trim(),
        'full_description_en': _fullDescriptionController.text.trim(),
        'full_description_ar': _fullDescriptionArController.text.trim(),
        'price': double.parse(_priceController.text.trim()),
        'sale_price': _salePriceController.text.trim().isEmpty
            ? null
            : double.parse(_salePriceController.text.trim()),
        'stock_qty': int.parse(_stockController.text.trim()),
        'pack_size': _packSizeController.text.trim(),
        'tags': _tagsController.text.trim(),
        'image_url': normalizedImages.first.imageUrl,
        'images': normalizedImages
            .asMap()
            .entries
            .map(
              (entry) => entry.value.copyWith(sortOrder: entry.key).toJson(),
            )
            .toList(),
        'category_id': _categoryId,
        'branch_id': _primaryAvailableBranchId(
          _namedBranch(widget.branches, 'mahayil'),
          _namedBranch(widget.branches, 'abha'),
          mahayilAvailable: _mahayilAvailable,
          abhaAvailable: _abhaAvailable,
        ),
        'branch_availability': _branchAvailabilityPayloads(
          _namedBranch(widget.branches, 'mahayil'),
          _namedBranch(widget.branches, 'abha'),
        ),
        'region_prices': _regionPricePayloads(),
        'is_featured': _isFeatured,
        'is_active': _isActive,
      };

      if (widget.product == null) {
        await widget.apiService.createProduct(payload);
      } else {
        await widget.apiService.updateProduct(widget.product!.id, payload);
      }
      await _dismiss(widget.product == null ? 'created' : 'updated');
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
    final mahayilBranch = _namedBranch(uniqueBranches, 'mahayil');
    final abhaBranch = _namedBranch(uniqueBranches, 'abha');
    final safeCategoryId =
        uniqueCategories.any((item) => item.id == _categoryId)
            ? _categoryId
            : null;

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
                      widget.product == null
                          ? l10n.t('admin_products_add_title')
                          : l10n.t('admin_products_edit_title'),
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                    ),
                  ),
                  IconButton(
                    onPressed: _saving ? null : () => _dismiss(),
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
                                decoration: InputDecoration(
                                    labelText: l10n.t('admin_field_name')),
                                validator: (value) => (value ?? '')
                                        .trim()
                                        .isEmpty
                                    ? l10n.t('admin_validation_name_required')
                                    : null,
                              ),
                              const SizedBox(height: 14),
                              TextFormField(
                                controller: _nameArController,
                                decoration: InputDecoration(
                                  labelText: l10n.t('admin_field_name_ar'),
                                ),
                              ),
                              const SizedBox(height: 14),
                              TextFormField(
                                controller: _skuController,
                                decoration: InputDecoration(
                                    labelText: l10n.t('admin_field_sku')),
                              ),
                              const SizedBox(height: 14),
                              TextFormField(
                                controller: _shortDescriptionController,
                                maxLines: 2,
                                decoration: const InputDecoration(
                                  labelText: 'Short Description (English)',
                                  hintText:
                                      'Short card summary shown in product listings',
                                ),
                              ),
                              const SizedBox(height: 14),
                              TextFormField(
                                controller: _shortDescriptionArController,
                                maxLines: 2,
                                decoration: const InputDecoration(
                                  labelText: 'Short Description (Arabic)',
                                  hintText:
                                      'Localized summary for Arabic storefront views',
                                ),
                              ),
                              const SizedBox(height: 14),
                              TextFormField(
                                controller: _packSizeController,
                                decoration: InputDecoration(
                                  labelText:
                                      l10n.t('admin_products_col_pack_size'),
                                ),
                              ),
                            ],
                          );

                          final imagePanel = SizedBox(
                            width: stacked ? double.infinity : 280,
                            child: _ProductImagesEditor(
                              images: _images,
                              uploadingImage: _uploadingImage,
                              onUpload: _pickImage,
                              onRemove: (index) {
                                setState(() {
                                  final nextImages =
                                      List<ProductImageModel>.from(_images)
                                        ..removeAt(index);
                                  _images = _normalizeImages(nextImages);
                                });
                              },
                              onMove: (index, direction) {
                                final target = index + direction;
                                if (target < 0 || target >= _images.length) {
                                  return;
                                }
                                setState(() {
                                  final nextImages =
                                      List<ProductImageModel>.from(_images);
                                  final item = nextImages.removeAt(index);
                                  nextImages.insert(target, item);
                                  _images = _normalizeImages(nextImages);
                                });
                              },
                              onMakePrimary: (index) {
                                setState(() {
                                  final nextImages =
                                      List<ProductImageModel>.from(_images);
                                  _images = _normalizeImages(
                                    nextImages
                                        .asMap()
                                        .entries
                                        .map(
                                          (entry) => entry.value.copyWith(
                                            isPrimary: entry.key == index,
                                          ),
                                        )
                                        .toList(),
                                  );
                                });
                              },
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
                        controller: _fullDescriptionController,
                        maxLines: 5,
                        decoration: const InputDecoration(
                          labelText: 'Long Description (English)',
                          hintText:
                              'Detailed product description for product details page',
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _fullDescriptionArController,
                        maxLines: 5,
                        decoration: const InputDecoration(
                          labelText: 'Long Description (Arabic)',
                          hintText:
                              'Localized long-form product content for Arabic storefront views',
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _tagsController,
                        decoration: const InputDecoration(
                          labelText: 'Tags / Search Keywords',
                          hintText: 'coffee, arabic, premium, saffron',
                        ),
                      ),
                      const SizedBox(height: 14),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final stacked = constraints.maxWidth < 720;
                          final priceField = TextFormField(
                            controller: _priceController,
                            decoration: InputDecoration(
                              labelText: l10n.t('admin_products_col_price'),
                            ),
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            validator: (value) {
                              final parsed =
                                  double.tryParse((value ?? '').trim());
                              if (parsed == null || parsed < 0) {
                                return l10n.t('admin_validation_price');
                              }
                              return null;
                            },
                          );
                          final salePriceField = TextFormField(
                            controller: _salePriceController,
                            decoration: const InputDecoration(
                              labelText: 'Sale Price',
                            ),
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            validator: (value) {
                              final raw = (value ?? '').trim();
                              if (raw.isEmpty) {
                                return null;
                              }
                              final parsed = double.tryParse(raw);
                              final basePrice =
                                  double.tryParse(_priceController.text.trim());
                              if (parsed == null || parsed < 0) {
                                return 'Enter a valid sale price.';
                              }
                              if (basePrice != null && parsed > basePrice) {
                                return 'Sale price must be less than or equal to price.';
                              }
                              return null;
                            },
                          );
                          final stockField = TextFormField(
                            controller: _stockController,
                            decoration: InputDecoration(
                              labelText: l10n.t('admin_products_col_stock'),
                            ),
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              final parsed = int.tryParse((value ?? '').trim());
                              if (parsed == null || parsed < 0) {
                                return l10n.t('admin_validation_stock');
                              }
                              return null;
                            },
                          );
                          if (stacked) {
                            return Column(
                              children: [
                                priceField,
                                const SizedBox(height: 12),
                                salePriceField,
                                const SizedBox(height: 12),
                                stockField,
                              ],
                            );
                          }
                          return Row(
                            children: [
                              Expanded(child: priceField),
                              const SizedBox(width: 12),
                              Expanded(child: salePriceField),
                              const SizedBox(width: 12),
                              Expanded(child: stockField),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 14),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceRaised,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Regional Storefront Pricing',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Base price remains available for existing customer pages. Use these storefront rows to prepare SA and AE pricing for the locale switcher.',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: AppColors.textMuted,
                                    height: 1.5,
                                  ),
                            ),
                            const SizedBox(height: 16),
                            _RegionPriceEditorCard(
                              title: 'Saudi Arabia storefront',
                              currencyCode: 'SAR',
                              visible: _saVisible,
                              priceController: _saPriceController,
                              salePriceController: _saSalePriceController,
                              onVisibleChanged: (value) =>
                                  setState(() => _saVisible = value),
                            ),
                            const SizedBox(height: 14),
                            _RegionPriceEditorCard(
                              title: 'UAE storefront',
                              currencyCode: 'AED',
                              visible: _aeVisible,
                              priceController: _aePriceController,
                              salePriceController: _aeSalePriceController,
                              onVisibleChanged: (value) =>
                                  setState(() => _aeVisible = value),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceRaised,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Branch Availability',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Control where this product can be sold. These toggles manage branch-level availability while preserving the existing admin layout.',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: AppColors.textMuted,
                                    height: 1.5,
                                  ),
                            ),
                            const SizedBox(height: 14),
                            if (mahayilBranch != null)
                              SwitchListTile(
                                value: _mahayilAvailable,
                                contentPadding: EdgeInsets.zero,
                                title: const Text(
                                  'Available in Mahayil Aseer',
                                ),
                                subtitle: Text(mahayilBranch.name),
                                onChanged: (value) => setState(
                                  () => _mahayilAvailable = value,
                                ),
                              ),
                            if (abhaBranch != null)
                              SwitchListTile(
                                value: _abhaAvailable,
                                contentPadding: EdgeInsets.zero,
                                title: const Text('Available in Abha'),
                                subtitle: Text(abhaBranch.name),
                                onChanged: (value) => setState(
                                  () => _abhaAvailable = value,
                                ),
                              ),
                            if (mahayilBranch == null && abhaBranch == null)
                              const Text(
                                'Mahayil Aseer and Abha branches are not available yet in branch management.',
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final categoryField = DropdownButtonFormField<int>(
                            initialValue: safeCategoryId,
                            decoration: InputDecoration(
                              labelText: l10n.t('products_filter_category'),
                            ),
                            items: uniqueCategories
                                .map(
                                  (category) => DropdownMenuItem<int>(
                                    value: category.id,
                                    child: Text(category.name),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) =>
                                setState(() => _categoryId = value),
                            validator: (value) => value == null
                                ? l10n.t('admin_validation_category_required')
                                : null,
                          );
                          return categoryField;
                        },
                      ),
                      const SizedBox(height: 14),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final stacked = constraints.maxWidth < 540;
                          final featuredTile = SwitchListTile(
                            value: _isFeatured,
                            title: Text(l10n.t('admin_products_col_featured')),
                            contentPadding: EdgeInsets.zero,
                            onChanged: (value) =>
                                setState(() => _isFeatured = value),
                          );
                          final activeTile = SwitchListTile(
                            value: _isActive,
                            title: Text(l10n.t('common_active')),
                            contentPadding: EdgeInsets.zero,
                            onChanged: (value) =>
                                setState(() => _isActive = value),
                          );
                          if (stacked) {
                            return Column(
                              children: [featuredTile, activeTile],
                            );
                          }
                          return Row(
                            children: [
                              Expanded(child: featuredTile),
                              Expanded(child: activeTile),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final stacked = constraints.maxWidth < 440;
                  final cancelButton = TextButton(
                    onPressed: _saving ? null : () => _dismiss(),
                    child: Text(l10n.t('common_cancel')),
                  );
                  final saveButton = ElevatedButton(
                    onPressed: _saving ? null : _save,
                    child: Text(
                      _saving ? l10n.t('common_saving') : l10n.t('common_save'),
                    ),
                  );
                  if (stacked) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        cancelButton,
                        const SizedBox(height: 10),
                        saveButton,
                      ],
                    );
                  }
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      cancelButton,
                      const SizedBox(width: 12),
                      saveButton,
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

ProductRegionPriceModel? _regionPriceFor(
    ProductModel? product, String regionCode) {
  if (product == null) {
    return null;
  }
  for (final row in product.regionPrices) {
    if (row.regionCode == regionCode) {
      return row;
    }
  }
  return null;
}

extension on _ProductEditorDialogState {
  List<Map<String, dynamic>> _regionPricePayloads() {
    final rows = <Map<String, dynamic>>[];
    void addRow({
      required String regionCode,
      required String currencyCode,
      required TextEditingController priceController,
      required TextEditingController salePriceController,
      required bool visible,
    }) {
      final rawPrice = priceController.text.trim();
      if (rawPrice.isEmpty) {
        return;
      }
      rows.add({
        'region_code': regionCode,
        'currency_code': currencyCode,
        'price': double.parse(rawPrice),
        'sale_price': salePriceController.text.trim().isEmpty
            ? null
            : double.parse(salePriceController.text.trim()),
        'is_visible': visible,
      });
    }

    addRow(
      regionCode: 'sa',
      currencyCode: 'SAR',
      priceController: _saPriceController,
      salePriceController: _saSalePriceController,
      visible: _saVisible,
    );
    addRow(
      regionCode: 'ae',
      currencyCode: 'AED',
      priceController: _aePriceController,
      salePriceController: _aeSalePriceController,
      visible: _aeVisible,
    );
    return rows;
  }

  List<Map<String, dynamic>> _branchAvailabilityPayloads(
    BranchModel? mahayilBranch,
    BranchModel? abhaBranch,
  ) {
    final rows = <Map<String, dynamic>>[];
    void addBranch(BranchModel? branch, bool isAvailable) {
      if (branch == null) {
        return;
      }
      rows.add({
        'branch_id': branch.id,
        'is_available': isAvailable,
      });
    }

    addBranch(mahayilBranch, _mahayilAvailable);
    addBranch(abhaBranch, _abhaAvailable);
    return rows;
  }
}

BranchModel? _namedBranch(List<BranchModel> branches, String token) {
  final normalizedToken = token.trim().toLowerCase();
  for (final branch in branches) {
    final haystack = '${branch.name} ${branch.city ?? ''}'.toLowerCase();
    if (haystack.contains(normalizedToken)) {
      return branch;
    }
  }
  return null;
}

bool _branchAvailabilityFor(ProductModel? product, BranchModel? branch) {
  if (product == null || branch == null) {
    return false;
  }
  for (final row in product.branchAvailability) {
    if (row.branchId == branch.id) {
      return row.isAvailable;
    }
  }
  if (product.availableBranchIds.contains(branch.id)) {
    return true;
  }
  return product.branchId == branch.id;
}

int? _primaryAvailableBranchId(
  BranchModel? mahayilBranch,
  BranchModel? abhaBranch, {
  required bool mahayilAvailable,
  required bool abhaAvailable,
}) {
  if (mahayilBranch != null && mahayilAvailable) {
    return mahayilBranch.id;
  }
  if (abhaBranch != null && abhaAvailable) {
    return abhaBranch.id;
  }
  return null;
}

List<ProductImageModel> _normalizeImages(List<ProductImageModel> images) {
  if (images.isEmpty) {
    return const <ProductImageModel>[];
  }
  final primaryIndex = images.indexWhere((image) => image.isPrimary);
  return images.asMap().entries.map((entry) {
    final index = entry.key;
    final image = entry.value;
    return image.copyWith(
      sortOrder: index,
      isPrimary: primaryIndex == -1 ? index == 0 : index == primaryIndex,
    );
  }).toList();
}

class _RegionPriceEditorCard extends StatelessWidget {
  final String title;
  final String currencyCode;
  final bool visible;
  final TextEditingController priceController;
  final TextEditingController salePriceController;
  final ValueChanged<bool> onVisibleChanged;

  const _RegionPriceEditorCard({
    required this.title,
    required this.currencyCode,
    required this.visible,
    required this.priceController,
    required this.salePriceController,
    required this.onVisibleChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$title ($currencyCode)',
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          SwitchListTile(
            value: visible,
            contentPadding: EdgeInsets.zero,
            title: const Text('Visible on storefront'),
            onChanged: onVisibleChanged,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: priceController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration:
                      const InputDecoration(labelText: 'Regional Price'),
                  validator: (value) {
                    final raw = (value ?? '').trim();
                    if (raw.isEmpty) {
                      return null;
                    }
                    final parsed = double.tryParse(raw);
                    if (parsed == null || parsed < 0) {
                      return 'Enter a valid regional price.';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: salePriceController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration:
                      const InputDecoration(labelText: 'Regional Sale Price'),
                  validator: (value) {
                    final raw = (value ?? '').trim();
                    if (raw.isEmpty) {
                      return null;
                    }
                    final parsed = double.tryParse(raw);
                    final basePrice =
                        double.tryParse(priceController.text.trim());
                    if (parsed == null || parsed < 0) {
                      return 'Enter a valid sale price.';
                    }
                    if (basePrice != null && parsed > basePrice) {
                      return 'Sale price must not exceed regional price.';
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProductImagesEditor extends StatelessWidget {
  final List<ProductImageModel> images;
  final bool uploadingImage;
  final VoidCallback onUpload;
  final ValueChanged<int> onRemove;
  final void Function(int index, int direction) onMove;
  final ValueChanged<int> onMakePrimary;

  const _ProductImagesEditor({
    required this.images,
    required this.uploadingImage,
    required this.onUpload,
    required this.onRemove,
    required this.onMove,
    required this.onMakePrimary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Product Images',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            'Upload multiple images, choose the cover image, and control the gallery order customers will see.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textMuted,
                  height: 1.5,
                ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: uploadingImage ? null : onUpload,
              icon: uploadingImage
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add_photo_alternate_outlined),
              label: Text(uploadingImage ? 'Uploading...' : 'Upload Image'),
            ),
          ),
          const SizedBox(height: 14),
          if (images.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.border),
              ),
              child: const Text(
                'No product images uploaded yet. The first uploaded image becomes the cover image automatically.',
              ),
            )
          else
            Column(
              children: [
                for (final entry in images.asMap().entries) ...[
                  _ProductImageRow(
                    image: entry.value,
                    index: entry.key,
                    onRemove: () => onRemove(entry.key),
                    onMoveUp:
                        entry.key > 0 ? () => onMove(entry.key, -1) : null,
                    onMoveDown: entry.key < images.length - 1
                        ? () => onMove(entry.key, 1)
                        : null,
                    onMakePrimary: entry.value.isPrimary
                        ? null
                        : () => onMakePrimary(entry.key),
                  ),
                  if (entry.key < images.length - 1) const SizedBox(height: 12),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

class _ProductImageRow extends StatelessWidget {
  final ProductImageModel image;
  final int index;
  final VoidCallback onRemove;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;
  final VoidCallback? onMakePrimary;

  const _ProductImageRow({
    required this.image,
    required this.index,
    required this.onRemove,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onMakePrimary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            clipBehavior: Clip.antiAlias,
            child: PremiumNetworkImage(
              imageUrl: image.imageUrl,
              width: 84,
              height: 84,
              borderRadius: BorderRadius.circular(16),
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Image ${index + 1}',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(width: 8),
                    if (image.isPrimary)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.accentLightGold,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'Cover',
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: AppColors.primaryDark,
                                    fontWeight: FontWeight.w900,
                                  ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  image.imageUrl,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textMuted,
                        height: 1.4,
                      ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    TextButton.icon(
                      onPressed: onMakePrimary,
                      icon: const Icon(Icons.star_outline_rounded, size: 18),
                      label:
                          Text(image.isPrimary ? 'Primary image' : 'Set cover'),
                    ),
                    TextButton.icon(
                      onPressed: onMoveUp,
                      icon: const Icon(Icons.arrow_upward_rounded, size: 18),
                      label: const Text('Up'),
                    ),
                    TextButton.icon(
                      onPressed: onMoveDown,
                      icon: const Icon(Icons.arrow_downward_rounded, size: 18),
                      label: const Text('Down'),
                    ),
                    TextButton.icon(
                      onPressed: onRemove,
                      icon: const Icon(Icons.delete_outline_rounded, size: 18),
                      label: const Text('Delete'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
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
    final l10n = context.l10n;
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
          Text(l10n.t('products_load_error_title'),
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(message),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: Text(l10n.t('common_retry')),
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
