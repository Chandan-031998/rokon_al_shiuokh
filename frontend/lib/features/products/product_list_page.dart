import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/extensions/localized_content.dart';
import '../../core/widgets/premium_network_image.dart';
import '../../localization/app_localizations.dart';
import '../../models/branch_model.dart';
import '../../models/category_model.dart';
import '../../models/product_model.dart';
import '../../services/api_service.dart';
import 'product_details_page.dart';

class ProductListPage extends StatefulWidget {
  final CategoryModel category;
  final ApiService apiService;

  const ProductListPage({
    super.key,
    required this.category,
    this.apiService = const ApiService(),
  });

  @override
  State<ProductListPage> createState() => _ProductListPageState();
}

class _ProductListPageState extends State<ProductListPage> {
  late final TextEditingController _searchController;
  late Future<List<CategoryModel>> _categoriesFuture;
  late Future<List<BranchModel>> _branchesFuture;
  late Future<List<ProductModel>> _productsFuture;

  int? _selectedCategoryId;
  int? _selectedBranchId;
  String _searchQuery = '';
  bool _isAddingToCart = false;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _selectedCategoryId = widget.category.id;
    _categoriesFuture = widget.apiService.fetchCategories();
    _branchesFuture = widget.apiService.fetchBranches();
    _productsFuture = _loadProducts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<List<ProductModel>> _loadProducts() {
    return widget.apiService.fetchProducts(
      categoryId: _selectedCategoryId,
      branchId: _selectedBranchId,
      query: _searchQuery,
    );
  }

  List<CategoryModel> _uniqueCategories(List<CategoryModel> categories) {
    final seenIds = <int>{};
    final uniqueCategories = <CategoryModel>[];
    for (final category in categories) {
      if (seenIds.add(category.id)) {
        uniqueCategories.add(category);
      }
    }
    return uniqueCategories;
  }

  List<BranchModel> _uniqueBranches(List<BranchModel> branches) {
    final seenIds = <int>{};
    final uniqueBranches = <BranchModel>[];
    for (final branch in branches) {
      if (seenIds.add(branch.id)) {
        uniqueBranches.add(branch);
      }
    }
    return uniqueBranches;
  }

  int? _safeSelectedValue({
    required int? selectedId,
    required Set<int> availableIds,
  }) {
    if (selectedId == null) {
      return null;
    }
    return availableIds.contains(selectedId) ? selectedId : null;
  }

  void _syncFilterSelections({
    required List<CategoryModel> categories,
    required List<BranchModel> branches,
  }) {
    final safeCategoryId = _safeSelectedValue(
      selectedId: _selectedCategoryId,
      availableIds: categories.map((category) => category.id).toSet(),
    );
    final safeBranchId = _safeSelectedValue(
      selectedId: _selectedBranchId,
      availableIds: branches.map((branch) => branch.id).toSet(),
    );

    if (safeCategoryId == _selectedCategoryId &&
        safeBranchId == _selectedBranchId) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _selectedCategoryId = safeCategoryId;
        _selectedBranchId = safeBranchId;
        _productsFuture = _loadProducts();
      });
    });
  }

  void _applyFilters() {
    setState(() {
      _searchQuery = _searchController.text.trim();
      _productsFuture = _loadProducts();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(title: Text(widget.category.localizedName(l10n))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          _ListingHeader(category: widget.category),
          const SizedBox(height: 18),
          _SearchBar(
            controller: _searchController,
            onSubmitted: (_) => _applyFilters(),
            onSearchPressed: _applyFilters,
          ),
          const SizedBox(height: 14),
          FutureBuilder<List<CategoryModel>>(
            future: _categoriesFuture,
            builder: (context, categorySnapshot) {
              return FutureBuilder<List<BranchModel>>(
                future: _branchesFuture,
                builder: (context, branchSnapshot) {
                  final categories = _uniqueCategories(
                    categorySnapshot.data ?? const <CategoryModel>[],
                  );
                  final branches = _uniqueBranches(
                    branchSnapshot.data ?? const <BranchModel>[],
                  );
                  _syncFilterSelections(
                    categories: categories,
                    branches: branches,
                  );

                  final safeCategoryId = _safeSelectedValue(
                    selectedId: _selectedCategoryId,
                    availableIds: categories.map((category) => category.id).toSet(),
                  );
                  final safeBranchId = _safeSelectedValue(
                    selectedId: _selectedBranchId,
                    availableIds: branches.map((branch) => branch.id).toSet(),
                  );

                  return _FilterRow(
                    categories: categories,
                    branches: branches,
                    selectedCategoryId: safeCategoryId,
                    selectedBranchId: safeBranchId,
                    onCategoryChanged: (value) {
                      setState(() {
                        _selectedCategoryId = value;
                        _productsFuture = _loadProducts();
                      });
                    },
                    onBranchChanged: (value) {
                      setState(() {
                        _selectedBranchId = value;
                        _productsFuture = _loadProducts();
                      });
                    },
                  );
                },
              );
            },
          ),
          const SizedBox(height: 18),
          FutureBuilder<List<ProductModel>>(
            future: _productsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              if (snapshot.hasError) {
                return _StateCard(
                  title: l10n.t('products_load_error_title'),
                  subtitle: l10n.t('products_load_error_desc'),
                  actionLabel: l10n.t('common_retry'),
                  onPressed: _applyFilters,
                );
              }

              final products = snapshot.data ?? const <ProductModel>[];
              if (products.isEmpty) {
                return _StateCard(
                  title: l10n.t('products_empty_title'),
                  subtitle: l10n.t('products_empty_desc'),
                  actionLabel: l10n.t('products_reset_filters'),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _searchQuery = '';
                      _selectedCategoryId = widget.category.id;
                      _selectedBranchId = null;
                      _productsFuture = _loadProducts();
                    });
                  },
                );
              }

              return LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final crossAxisCount = width >= 1180
                      ? 3
                      : width >= 760
                          ? 2
                          : 1;

                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: width >= 760 ? 1.12 : 1.36,
                    ),
                    itemCount: products.length,
                    itemBuilder: (context, index) {
                      return _ProductListCard(
                        product: products[index],
                        onAddToCart: () => _addToCart(products[index]),
                        onTap: () async {
                          final branches = await _branchesFuture;
                          if (!context.mounted) {
                            return;
                          }
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ProductDetailsPage(
                                product: products[index],
                                branches: branches,
                                apiService: widget.apiService,
                              ),
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _addToCart(ProductModel product) async {
    if (_isAddingToCart) {
      return;
    }

    setState(() => _isAddingToCart = true);
    try {
      await widget.apiService.addToCart(
        productId: product.id,
        branchId: product.branchId ?? _selectedBranchId,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.t(
              'product_add_success',
              {
                'quantity': '1',
                'name': product.localizedName(context.l10n),
                'branch': context.l10n.t('orders_selected_branch'),
              },
            ),
          ),
        ),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.t('product_add_error'))),
      );
    } finally {
      if (mounted) {
        setState(() => _isAddingToCart = false);
      }
    }
  }
}

class _ListingHeader extends StatelessWidget {
  final CategoryModel category;

  const _ListingHeader({required this.category});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.brownDeep, AppColors.brown],
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        children: [
          const Icon(Icons.storefront_outlined,
              color: AppColors.white, size: 32),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category.localizedName(context.l10n),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: AppColors.white,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  context.l10n.t('products_search_refine_desc'),
                  style: const TextStyle(
                    color: AppColors.creamSoft,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onSearchPressed;

  const _SearchBar({
    required this.controller,
    required this.onSubmitted,
    required this.onSearchPressed,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onSubmitted: onSubmitted,
      decoration: InputDecoration(
        hintText: 'Search products, Arabic names, or SKU',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: IconButton(
          onPressed: onSearchPressed,
          icon: const Icon(Icons.arrow_forward_rounded),
        ),
        filled: true,
        fillColor: AppColors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: const BorderSide(color: AppColors.border),
        ),
      ),
    );
  }
}

class _FilterRow extends StatelessWidget {
  final List<CategoryModel> categories;
  final List<BranchModel> branches;
  final int? selectedCategoryId;
  final int? selectedBranchId;
  final ValueChanged<int?> onCategoryChanged;
  final ValueChanged<int?> onBranchChanged;

  const _FilterRow({
    required this.categories,
    required this.branches,
    required this.selectedCategoryId,
    required this.selectedBranchId,
    required this.onCategoryChanged,
    required this.onBranchChanged,
  });

  @override
  Widget build(BuildContext context) {
    final uniqueCategories = <CategoryModel>[
      for (final category in categories)
        if (categories.indexWhere((item) => item.id == category.id) ==
            categories.indexOf(category))
          category,
    ];
    final uniqueBranches = <BranchModel>[
      for (final branch in branches)
        if (branches.indexWhere((item) => item.id == branch.id) ==
            branches.indexOf(branch))
          branch,
    ];
    final safeCategoryId = selectedCategoryId != null &&
            uniqueCategories.any((category) => category.id == selectedCategoryId)
        ? selectedCategoryId
        : null;
    final safeBranchId = selectedBranchId != null &&
            uniqueBranches.any((branch) => branch.id == selectedBranchId)
        ? selectedBranchId
        : null;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 760;
        final categoryFilter = _FilterDropdown<int?>(
          label: context.l10n.t('products_filter_category'),
          value: safeCategoryId,
          items: [
            DropdownMenuItem<int?>(
              value: null,
              child: Text(context.l10n.t('products_filter_all_categories')),
            ),
            ...uniqueCategories.map(
              (category) => DropdownMenuItem<int?>(
                value: category.id,
                child: Text(category.localizedName(context.l10n)),
              ),
            ),
          ],
          onChanged: onCategoryChanged,
        );
        final branchFilter = _FilterDropdown<int?>(
          label: context.l10n.t('products_filter_branch'),
          value: safeBranchId,
          items: [
            DropdownMenuItem<int?>(
              value: null,
              child: Text(context.l10n.t('products_filter_all_branches')),
            ),
            ...uniqueBranches.map(
              (branch) => DropdownMenuItem<int?>(
                value: branch.id,
                child: Text(branch.name),
              ),
            ),
          ],
          onChanged: onBranchChanged,
        );

        if (isWide) {
          return Row(
            children: [
              Expanded(child: categoryFilter),
              const SizedBox(width: 12),
              Expanded(child: branchFilter),
            ],
          );
        }

        return Column(
          children: [
            categoryFilter,
            const SizedBox(height: 12),
            branchFilter,
          ],
        );
      },
    );
  }
}

class _FilterDropdown<T> extends StatelessWidget {
  final String label;
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  const _FilterDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      items: items,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: AppColors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppColors.border),
        ),
      ),
    );
  }
}

class _ProductListCard extends StatelessWidget {
  final ProductModel product;
  final VoidCallback onTap;
  final VoidCallback onAddToCart;

  const _ProductListCard({
    required this.product,
    required this.onTap,
    required this.onAddToCart,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ProductVisual(imageUrl: product.imageUrl),
              const SizedBox(height: 16),
              Text(
                product.localizedName(context.l10n),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                _packSizeLabel(product),
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: AppColors.textMuted,
                    ),
              ),
              const Spacer(),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text(
                    'SAR ${product.price.toStringAsFixed(0)}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AppColors.brownDeep,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: onAddToCart,
                        child: Text(context.l10n.t('products_add_short')),
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    color: AppColors.brown,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProductVisual extends StatelessWidget {
  final String? imageUrl;

  const _ProductVisual({this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return PremiumNetworkImage(
      imageUrl: imageUrl,
      height: 110,
      borderRadius: BorderRadius.circular(18),
      fallbackIcon: Icons.inventory_2_outlined,
      fallbackIconSize: 30,
    );
  }
}

class _StateCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onPressed;

  const _StateCard({
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 10),
          Text(subtitle, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: onPressed, child: Text(actionLabel)),
        ],
      ),
    );
  }
}

String _packSizeLabel(ProductModel product) {
  final source =
      '${product.name} ${product.description ?? ''} ${product.sku ?? ''}';
  final match = RegExp(r'(\d+\s?(?:g|kg|ml|l|pack))', caseSensitive: false)
      .firstMatch(source);
  return match?.group(1) ?? 'Standard pack';
}
