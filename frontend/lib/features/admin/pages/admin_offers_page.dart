import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../models/branch_model.dart';
import '../../../models/category_model.dart';
import '../../../models/product_model.dart';
import '../models/admin_offer_model.dart';
import '../services/admin_api_service.dart';
import '../widgets/admin_page_frame.dart';

class AdminOffersPage extends StatefulWidget {
  final AdminApiService apiService;

  const AdminOffersPage({
    super.key,
    required this.apiService,
  });

  @override
  State<AdminOffersPage> createState() => _AdminOffersPageState();
}

class _AdminOffersPageState extends State<AdminOffersPage> {
  bool _loading = true;
  String? _error;
  List<AdminOfferModel> _offers = const [];
  List<ProductModel> _products = const [];
  List<CategoryModel> _categories = const [];
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
      final results = await Future.wait([
        widget.apiService.fetchOffers(),
        widget.apiService.fetchProducts(),
        widget.apiService.fetchCategories(),
        widget.apiService.fetchBranches(),
      ]);
      if (!mounted) {
        return;
      }
      setState(() {
        _offers = results[0] as List<AdminOfferModel>;
        _products = results[1] as List<ProductModel>;
        _categories = results[2] as List<CategoryModel>;
        _branches = results[3] as List<BranchModel>;
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

  Future<void> _openEditor([AdminOfferModel? offer]) async {
    final changed = await showDialog<bool>(
      context: context,
      builder: (context) => _OfferEditorDialog(
        apiService: widget.apiService,
        offer: offer,
        products: _products,
        categories: _categories,
        branches: _branches,
      ),
    );
    if (changed == true) {
      await _load();
    }
  }

  Future<void> _deleteOffer(AdminOfferModel offer) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Offer'),
        content: Text('Delete "${offer.title}"?'),
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
      await widget.apiService.deleteOffer(offer.id);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Offer deleted successfully.')),
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

  Future<void> _toggleOffer(AdminOfferModel offer, bool active) async {
    try {
      await widget.apiService.updateOffer(
        offer.id,
        {'is_active': active},
      );
      if (!mounted) {
        return;
      }
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
    return AdminPageFrame(
      title: 'Offers',
      subtitle:
          'Manage promotional banners, discount metadata, and active customer-facing offers.',
      actions: [
        OutlinedButton.icon(
          onPressed: _load,
          icon: const Icon(Icons.refresh),
          label: const Text('Refresh'),
        ),
        ElevatedButton.icon(
          onPressed: () => _openEditor(),
          icon: const Icon(Icons.add),
          label: const Text('Add Offer'),
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
                ? _OffersError(message: _error!, onRetry: _load)
                : DataTable(
                    columns: const [
                      DataColumn(label: Text('Offer Copy')),
                      DataColumn(label: Text('Discount')),
                      DataColumn(label: Text('Region')),
                      DataColumn(label: Text('Linked')),
                      DataColumn(label: Text('Schedule')),
                      DataColumn(label: Text('Active')),
                      DataColumn(label: Text('Actions')),
                    ],
                    rows: _offers
                        .map(
                          (offer) => DataRow(
                            cells: [
                              DataCell(
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(offer.title),
                                    if ((offer.titleAr ?? '').isNotEmpty)
                                      Text(
                                        offer.titleAr!,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall,
                                      ),
                                    if ((offer.subtitle ?? '').isNotEmpty)
                                      Text(offer.subtitle!,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall),
                                  ],
                                ),
                              ),
                              DataCell(Text(
                                  '${offer.discountType ?? 'none'} ${offer.discountValue.toStringAsFixed(2)}')),
                              DataCell(
                                Text(
                                  '${(offer.regionCode ?? 'all').toUpperCase()}${(offer.currencyCode ?? '').isEmpty ? '' : ' / ${offer.currencyCode}'}',
                                ),
                              ),
                              DataCell(Text(_linkLabel(offer))),
                              DataCell(Text(_scheduleLabel(offer))),
                              DataCell(Switch(
                                value: offer.isActive,
                                onChanged: (value) =>
                                    _toggleOffer(offer, value),
                              )),
                              DataCell(
                                Wrap(
                                  spacing: 8,
                                  children: [
                                    IconButton(
                                      onPressed: () => _openEditor(offer),
                                      icon: const Icon(Icons.edit_outlined),
                                    ),
                                    IconButton(
                                      onPressed: () => _deleteOffer(offer),
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

  String _linkLabel(AdminOfferModel offer) {
    if (offer.productId != null) {
      return _products
              .where((item) => item.id == offer.productId)
              .firstOrNull
              ?.name ??
          'Product';
    }
    if (offer.categoryId != null) {
      return _categories
              .where((item) => item.id == offer.categoryId)
              .firstOrNull
              ?.name ??
          'Category';
    }
    if (offer.branchId != null) {
      return _branches
              .where((item) => item.id == offer.branchId)
              .firstOrNull
              ?.name ??
          'Branch';
    }
    return 'General';
  }

  String _scheduleLabel(AdminOfferModel offer) {
    final start = offer.startsAt?.split('T').first;
    final end = offer.endsAt?.split('T').first;
    if (start == null && end == null) {
      return 'Always on';
    }
    return '${start ?? 'Now'} -> ${end ?? 'Open'}';
  }
}

class _OfferEditorDialog extends StatefulWidget {
  final AdminApiService apiService;
  final AdminOfferModel? offer;
  final List<ProductModel> products;
  final List<CategoryModel> categories;
  final List<BranchModel> branches;

  const _OfferEditorDialog({
    required this.apiService,
    required this.offer,
    required this.products,
    required this.categories,
    required this.branches,
  });

  @override
  State<_OfferEditorDialog> createState() => _OfferEditorDialogState();
}

class _OfferEditorDialogState extends State<_OfferEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _titleArController;
  late final TextEditingController _subtitleController;
  late final TextEditingController _subtitleArController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _descriptionArController;
  late final TextEditingController _bannerUrlController;
  late final TextEditingController _discountValueController;
  late final TextEditingController _startsAtController;
  late final TextEditingController _endsAtController;
  String? _discountType;
  String? _regionCode;
  String? _currencyCode;
  int? _productId;
  int? _categoryId;
  int? _branchId;
  bool _isActive = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final offer = widget.offer;
    _titleController = TextEditingController(
      text: offer?.titleEn ?? offer?.title ?? '',
    );
    _titleArController = TextEditingController(text: offer?.titleAr ?? '');
    _subtitleController = TextEditingController(
      text: offer?.subtitleEn ?? offer?.subtitle ?? '',
    );
    _subtitleArController =
        TextEditingController(text: offer?.subtitleAr ?? '');
    _descriptionController = TextEditingController(
      text: offer?.descriptionEn ?? offer?.description ?? '',
    );
    _descriptionArController =
        TextEditingController(text: offer?.descriptionAr ?? '');
    _bannerUrlController = TextEditingController(text: offer?.bannerUrl ?? '');
    _discountValueController = TextEditingController(
      text: offer == null ? '0' : offer.discountValue.toStringAsFixed(2),
    );
    _startsAtController = TextEditingController(
      text: offer?.startsAt?.split('.').first ?? '',
    );
    _endsAtController = TextEditingController(
      text: offer?.endsAt?.split('.').first ?? '',
    );
    _discountType = offer?.discountType;
    _regionCode = offer?.regionCode;
    _currencyCode =
        offer?.currencyCode ?? _defaultCurrencyForRegion(_regionCode);
    _productId = offer?.productId;
    _categoryId = offer?.categoryId;
    _branchId = offer?.branchId;
    _isActive = offer?.isActive ?? true;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _titleArController.dispose();
    _subtitleController.dispose();
    _subtitleArController.dispose();
    _descriptionController.dispose();
    _descriptionArController.dispose();
    _bannerUrlController.dispose();
    _discountValueController.dispose();
    _startsAtController.dispose();
    _endsAtController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _saving = true);
    try {
      final payload = {
        'title': _titleController.text.trim(),
        'title_en': _titleController.text.trim(),
        'title_ar': _titleArController.text.trim(),
        'subtitle': _subtitleController.text.trim(),
        'subtitle_en': _subtitleController.text.trim(),
        'subtitle_ar': _subtitleArController.text.trim(),
        'description': _descriptionController.text.trim(),
        'description_en': _descriptionController.text.trim(),
        'description_ar': _descriptionArController.text.trim(),
        'banner_url': _bannerUrlController.text.trim(),
        'region_code': _regionCode,
        'currency_code': _currencyCode,
        'discount_type': _discountType,
        'discount_value': double.parse(_discountValueController.text.trim()),
        'product_id': _productId,
        'category_id': _categoryId,
        'branch_id': _branchId,
        'starts_at': _startsAtController.text.trim().isEmpty
            ? null
            : _startsAtController.text.trim(),
        'ends_at': _endsAtController.text.trim().isEmpty
            ? null
            : _endsAtController.text.trim(),
        'is_active': _isActive,
      };
      if (widget.offer == null) {
        await widget.apiService.createOffer(payload);
      } else {
        await widget.apiService.updateOffer(widget.offer!.id, payload);
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
      title: Text(widget.offer == null ? 'Add Offer' : 'Edit Offer'),
      content: SizedBox(
        width: 720,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              children: [
                TextFormField(
                  controller: _titleController,
                  decoration:
                      const InputDecoration(labelText: 'Offer Title (English)'),
                  validator: (value) => (value ?? '').trim().isEmpty
                      ? 'English title is required.'
                      : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _titleArController,
                  decoration:
                      const InputDecoration(labelText: 'Offer Title (Arabic)'),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _subtitleController,
                  decoration: const InputDecoration(
                      labelText: 'Offer Subtitle (English)'),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _subtitleArController,
                  decoration: const InputDecoration(
                    labelText: 'Offer Subtitle (Arabic)',
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 3,
                  decoration:
                      const InputDecoration(labelText: 'Offer Copy (English)'),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _descriptionArController,
                  maxLines: 3,
                  decoration:
                      const InputDecoration(labelText: 'Offer Copy (Arabic)'),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _bannerUrlController,
                  decoration: const InputDecoration(labelText: 'Banner URL'),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String?>(
                        initialValue: _regionCode,
                        decoration: const InputDecoration(
                            labelText: 'Storefront Region'),
                        items: const [
                          DropdownMenuItem<String?>(
                            value: null,
                            child: Text('All regions'),
                          ),
                          DropdownMenuItem<String?>(
                            value: 'sa',
                            child: Text('Saudi Arabia (SA)'),
                          ),
                          DropdownMenuItem<String?>(
                            value: 'ae',
                            child: Text('United Arab Emirates (AE)'),
                          ),
                        ],
                        onChanged: (value) => setState(() {
                          _regionCode = value;
                          _currencyCode = _defaultCurrencyForRegion(value);
                        }),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String?>(
                        initialValue: _currencyCode,
                        decoration:
                            const InputDecoration(labelText: 'Currency Code'),
                        items: const [
                          DropdownMenuItem<String?>(
                            value: null,
                            child: Text('Auto by region'),
                          ),
                          DropdownMenuItem<String?>(
                            value: 'SAR',
                            child: Text('SAR'),
                          ),
                          DropdownMenuItem<String?>(
                            value: 'AED',
                            child: Text('AED'),
                          ),
                        ],
                        onChanged: (value) =>
                            setState(() => _currencyCode = value),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _startsAtController,
                        decoration: const InputDecoration(
                          labelText: 'Start Date/Time',
                          hintText: '2026-04-18T10:00:00',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _endsAtController,
                        decoration: const InputDecoration(
                          labelText: 'End Date/Time',
                          hintText: '2026-04-25T23:59:59',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String?>(
                        initialValue: _discountType,
                        decoration:
                            const InputDecoration(labelText: 'Discount Type'),
                        items: const [
                          DropdownMenuItem<String?>(
                              value: null, child: Text('None')),
                          DropdownMenuItem<String?>(
                              value: 'percentage', child: Text('Percentage')),
                          DropdownMenuItem<String?>(
                              value: 'fixed_amount',
                              child: Text('Fixed Amount')),
                        ],
                        onChanged: (value) =>
                            setState(() => _discountType = value),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _discountValueController,
                        decoration:
                            const InputDecoration(labelText: 'Discount Value'),
                        validator: (value) =>
                            double.tryParse((value ?? '').trim()) == null
                                ? 'Enter a valid number.'
                                : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<int?>(
                  initialValue: _productId,
                  decoration:
                      const InputDecoration(labelText: 'Linked Product'),
                  items: [
                    const DropdownMenuItem<int?>(
                        value: null, child: Text('None')),
                    ...widget.products.map(
                      (product) => DropdownMenuItem<int?>(
                        value: product.id,
                        child: Text(product.name),
                      ),
                    ),
                  ],
                  onChanged: (value) => setState(() => _productId = value),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<int?>(
                  initialValue: _categoryId,
                  decoration:
                      const InputDecoration(labelText: 'Linked Category'),
                  items: [
                    const DropdownMenuItem<int?>(
                        value: null, child: Text('None')),
                    ...widget.categories.map(
                      (category) => DropdownMenuItem<int?>(
                        value: category.id,
                        child: Text(category.name),
                      ),
                    ),
                  ],
                  onChanged: (value) => setState(() => _categoryId = value),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<int?>(
                  initialValue: _branchId,
                  decoration: const InputDecoration(labelText: 'Linked Branch'),
                  items: [
                    const DropdownMenuItem<int?>(
                        value: null, child: Text('None')),
                    ...widget.branches.map(
                      (branch) => DropdownMenuItem<int?>(
                        value: branch.id,
                        child: Text(branch.name),
                      ),
                    ),
                  ],
                  onChanged: (value) => setState(() => _branchId = value),
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

String? _defaultCurrencyForRegion(String? regionCode) {
  switch (regionCode) {
    case 'sa':
      return 'SAR';
    case 'ae':
      return 'AED';
    default:
      return null;
  }
}

class _OffersError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _OffersError({
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
