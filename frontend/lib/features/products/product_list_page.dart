import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/extensions/localized_content.dart';
import '../../core/widgets/premium_network_image.dart';
import '../../localization/app_localizations.dart';
import '../../models/branch_model.dart';
import '../../models/category_model.dart';
import '../../models/discovery_filter_models.dart';
import '../../models/product_model.dart';
import '../../models/search_term_model.dart';
import '../../services/api_service.dart';
import '../auth/login_page.dart';
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
  late Future<List<SearchTermModel>> _popularSearchTermsFuture;
  late Future<_DiscoveryViewData> _discoveryFuture;

  int? _selectedCategoryId;
  int? _selectedBranchId;
  String _searchQuery = '';
  String _sortKey = _SortOption.featured;
  final Set<int> _selectedFilterValueIds = <int>{};
  bool _isAddingToCart = false;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _selectedCategoryId = widget.category.id;
    _categoriesFuture = widget.apiService.fetchCategories();
    _branchesFuture = widget.apiService.fetchBranches();
    _popularSearchTermsFuture = widget.apiService.fetchPopularSearchTerms();
    _discoveryFuture = _loadDiscovery();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<_DiscoveryViewData> _loadDiscovery() async {
    final categoryId = _selectedCategoryId ?? widget.category.id;
    final responses = await Future.wait([
      widget.apiService.fetchCategoryDiscoveryProducts(
        categoryId,
        branchId: _selectedBranchId,
        query: _searchQuery,
        filterValueIds: _selectedFilterValueIds.toList(),
      ),
      widget.apiService.fetchDiscoveryFilters(
        categoryId: categoryId,
        branchId: _selectedBranchId,
        query: _searchQuery,
      ),
    ]);
    final results = responses[0] as List<ProductModel>;
    final filters = responses[1] as List<DiscoveryFilterGroupModel>;
    return _DiscoveryViewData(
      products: _sortProducts(results),
      filters: filters,
    );
  }

  List<ProductModel> _sortProducts(List<ProductModel> products) {
    final sorted = List<ProductModel>.from(products);
    sorted.sort((left, right) {
      switch (_sortKey) {
        case _SortOption.priceLow:
          return left.effectivePrice.compareTo(right.effectivePrice);
        case _SortOption.priceHigh:
          return right.effectivePrice.compareTo(left.effectivePrice);
        case _SortOption.rating:
          final ratingCompare = right.averageRating.compareTo(left.averageRating);
          if (ratingCompare != 0) {
            return ratingCompare;
          }
          return right.reviewCount.compareTo(left.reviewCount);
        case _SortOption.newest:
          return right.id.compareTo(left.id);
        case _SortOption.featured:
        default:
          final featuredCompare =
              (right.isFeatured ? 1 : 0).compareTo(left.isFeatured ? 1 : 0);
          if (featuredCompare != 0) {
            return featuredCompare;
          }
          final stockCompare = right.stockQty.compareTo(left.stockQty);
          if (stockCompare != 0) {
            return stockCompare;
          }
          return right.id.compareTo(left.id);
      }
    });
    return sorted;
  }

  void _reloadDiscovery() {
    setState(() {
      _discoveryFuture = _loadDiscovery();
    });
  }

  void _applyFilters() {
    setState(() {
      _searchQuery = _searchController.text.trim();
      _discoveryFuture = _loadDiscovery();
    });
  }

  Future<void> _openProductDetails(ProductModel product) async {
    final branches = await _branchesFuture;
    if (!mounted) {
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProductDetailsPage(
          product: product,
          branches: branches,
          apiService: widget.apiService,
        ),
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
            'Added ${product.localizedName(context.l10n)} to cart.',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to add this item to cart right now.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isAddingToCart = false);
      }
    }
  }

  Future<bool> _ensureSignedInForWishlist() async {
    if (await widget.apiService.hasAuthSession()) {
      return true;
    }

    if (!mounted) {
      return false;
    }
    final didLogin = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => LoginPage(apiService: widget.apiService),
      ),
    );
    if (didLogin == true) {
      await widget.apiService.refreshWishlistIds();
      return true;
    }
    return false;
  }

  Future<void> _toggleWishlist(ProductModel product) async {
    final isFavorite =
        ApiService.wishlistIdsListenable.value.contains(product.id);

    if (!isFavorite && !await _ensureSignedInForWishlist()) {
      return;
    }

    try {
      if (isFavorite) {
        await widget.apiService.removeWishlistItem(product.id);
      } else {
        await widget.apiService.addWishlistItem(product.id);
      }
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isFavorite
                ? 'Removed ${product.localizedName(context.l10n)} from wishlist.'
                : 'Saved ${product.localizedName(context.l10n)} to wishlist.',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to update wishlist right now.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(title: Text(widget.category.localizedName(l10n))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          _ListingHeader(
            title: 'Discover ${widget.category.localizedName(l10n)}',
            subtitle:
                'Search, filter, and sort the live catalog while staying aware of branch availability.',
          ),
          const SizedBox(height: 18),
          _SearchBar(
            controller: _searchController,
            onSubmitted: (_) => _applyFilters(),
            onSearchPressed: _applyFilters,
          ),
          const SizedBox(height: 14),
          FutureBuilder<List<SearchTermModel>>(
            future: _popularSearchTermsFuture,
            builder: (context, snapshot) {
              final terms = snapshot.data ?? const <SearchTermModel>[];
              if (terms.isEmpty) {
                return const SizedBox.shrink();
              }
              return _PopularSearchTermsRow(
                terms: terms.take(6).toList(),
                onSelected: (term) {
                  _searchController.text = term;
                  _applyFilters();
                },
              );
            },
          ),
          const SizedBox(height: 14),
          FutureBuilder<List<CategoryModel>>(
            future: _categoriesFuture,
            builder: (context, categorySnapshot) {
              return FutureBuilder<List<BranchModel>>(
                future: _branchesFuture,
                builder: (context, branchSnapshot) {
                  final categories = categorySnapshot.data ?? const <CategoryModel>[];
                  final branches = branchSnapshot.data ?? const <BranchModel>[];
                  final safeCategoryId = categories.any(
                    (category) => category.id == _selectedCategoryId,
                  )
                      ? _selectedCategoryId
                      : (categories.isNotEmpty ? categories.first.id : null);
                  final safeBranchId = branches.any(
                    (branch) => branch.id == _selectedBranchId,
                  )
                      ? _selectedBranchId
                      : null;
                  return _ControlsPanel(
                    categories: categories,
                    branches: branches,
                    selectedCategoryId: safeCategoryId,
                    selectedBranchId: safeBranchId,
                    selectedSortKey: _sortKey,
                    onCategoryChanged: (value) {
                      setState(() {
                        _selectedCategoryId = value;
                        _selectedFilterValueIds.clear();
                        _discoveryFuture = _loadDiscovery();
                      });
                    },
                    onBranchChanged: (value) {
                      setState(() {
                        _selectedBranchId = value;
                        _discoveryFuture = _loadDiscovery();
                      });
                    },
                    onSortChanged: (value) {
                      if (value == null) {
                        return;
                      }
                      setState(() {
                        _sortKey = value;
                        _discoveryFuture = _loadDiscovery();
                      });
                    },
                  );
                },
              );
            },
          ),
          const SizedBox(height: 18),
          FutureBuilder<_DiscoveryViewData>(
            future: _discoveryFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              if (snapshot.hasError) {
                return _StateCard(
                  title: 'Unable to load products',
                  subtitle:
                      'The live category listing could not be loaded. Retry to refresh the current search.',
                  actionLabel: 'Retry',
                  onPressed: _reloadDiscovery,
                );
              }

              final discovery = snapshot.data ?? const _DiscoveryViewData();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (discovery.filters.isNotEmpty)
                    _FilterGroupsSection(
                      groups: discovery.filters,
                      selectedValueIds: _selectedFilterValueIds,
                      onFilterToggle: (valueId) {
                        setState(() {
                          if (_selectedFilterValueIds.contains(valueId)) {
                            _selectedFilterValueIds.remove(valueId);
                          } else {
                            _selectedFilterValueIds.add(valueId);
                          }
                          _discoveryFuture = _loadDiscovery();
                        });
                      },
                    ),
                  const SizedBox(height: 16),
                  _ResultSummaryBar(
                    productCount: discovery.products.length,
                    branchName:
                        _branchNameFromProducts(discovery.products, _selectedBranchId),
                    hasActiveFilters: _selectedFilterValueIds.isNotEmpty ||
                        _searchQuery.isNotEmpty ||
                        _selectedBranchId != null,
                    onReset: () {
                      _searchController.clear();
                      setState(() {
                        _searchQuery = '';
                        _selectedBranchId = null;
                        _selectedFilterValueIds.clear();
                        _sortKey = _SortOption.featured;
                        _discoveryFuture = _loadDiscovery();
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  if (discovery.products.isEmpty)
                    _StateCard(
                      title: 'No products matched this view',
                      subtitle:
                          'Try another branch, clear a few filters, or broaden the search terms.',
                      actionLabel: 'Reset filters',
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _searchQuery = '';
                          _selectedBranchId = null;
                          _selectedFilterValueIds.clear();
                          _sortKey = _SortOption.featured;
                          _discoveryFuture = _loadDiscovery();
                        });
                      },
                    )
                  else
                    LayoutBuilder(
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
                            mainAxisExtent: 360,
                          ),
                          itemCount: discovery.products.length,
                          itemBuilder: (context, index) {
                            final product = discovery.products[index];
                            return ValueListenableBuilder<Set<int>>(
                              valueListenable: ApiService.wishlistIdsListenable,
                              builder: (context, wishlistIds, _) {
                                return _ProductDiscoveryCard(
                                  product: product,
                                  selectedBranchId: _selectedBranchId,
                                  isFavorite: wishlistIds.contains(product.id),
                                  onTap: () => _openProductDetails(product),
                                  onAddToCart: () => _addToCart(product),
                                  onToggleWishlist: () =>
                                      _toggleWishlist(product),
                                );
                              },
                            );
                          },
                        );
                      },
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  String? _branchNameFromProducts(List<ProductModel> products, int? selectedBranchId) {
    if (selectedBranchId == null) {
      return null;
    }
    for (final product in products) {
      if (product.branchId == selectedBranchId &&
          (product.branchName ?? '').trim().isNotEmpty) {
        return product.branchName;
      }
    }
    return 'selected branch';
  }
}

class _DiscoveryViewData {
  final List<ProductModel> products;
  final List<DiscoveryFilterGroupModel> filters;

  const _DiscoveryViewData({
    this.products = const <ProductModel>[],
    this.filters = const <DiscoveryFilterGroupModel>[],
  });
}

class _SortOption {
  static const featured = 'featured';
  static const newest = 'newest';
  static const priceLow = 'price_low';
  static const priceHigh = 'price_high';
  static const rating = 'rating';
}

class _ListingHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const _ListingHeader({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.surfaceGradient,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 10),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  height: 1.5,
                  color: AppColors.textMuted,
                ),
          ),
        ],
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback onSearchPressed;

  const _SearchBar({
    required this.controller,
    this.onSubmitted,
    required this.onSearchPressed,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onSubmitted: onSubmitted,
      decoration: InputDecoration(
        hintText: 'Search products, keywords, or tags',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: IconButton(
          onPressed: onSearchPressed,
          icon: const Icon(Icons.arrow_forward_rounded),
        ),
      ),
    );
  }
}

class _PopularSearchTermsRow extends StatelessWidget {
  final List<SearchTermModel> terms;
  final ValueChanged<String> onSelected;

  const _PopularSearchTermsRow({
    required this.terms,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final term in terms)
          ActionChip(
            label: Text(term.term),
            onPressed: () => onSelected(term.term),
            backgroundColor: AppColors.creamSoft,
            side: const BorderSide(color: AppColors.border),
          ),
      ],
    );
  }
}

class _ControlsPanel extends StatelessWidget {
  final List<CategoryModel> categories;
  final List<BranchModel> branches;
  final int? selectedCategoryId;
  final int? selectedBranchId;
  final String selectedSortKey;
  final ValueChanged<int?> onCategoryChanged;
  final ValueChanged<int?> onBranchChanged;
  final ValueChanged<String?> onSortChanged;

  const _ControlsPanel({
    required this.categories,
    required this.branches,
    required this.selectedCategoryId,
    required this.selectedBranchId,
    required this.selectedSortKey,
    required this.onCategoryChanged,
    required this.onBranchChanged,
    required this.onSortChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Wrap(
        spacing: 14,
        runSpacing: 14,
        children: [
          SizedBox(
            width: 240,
            child: DropdownButtonFormField<int?>(
              initialValue: selectedCategoryId,
              decoration: const InputDecoration(labelText: 'Category'),
              items: categories
                  .map(
                    (category) => DropdownMenuItem<int?>(
                      value: category.id,
                      child: Text(category.name),
                    ),
                  )
                  .toList(),
              onChanged: onCategoryChanged,
            ),
          ),
          SizedBox(
            width: 240,
            child: DropdownButtonFormField<int?>(
              initialValue: selectedBranchId,
              decoration: const InputDecoration(labelText: 'Branch'),
              items: [
                const DropdownMenuItem<int?>(
                  value: null,
                  child: Text('All branches'),
                ),
                ...branches
                    .where((branch) => branch.isActive)
                    .map(
                      (branch) => DropdownMenuItem<int?>(
                        value: branch.id,
                        child: Text(branch.name),
                      ),
                    ),
              ],
              onChanged: onBranchChanged,
            ),
          ),
          SizedBox(
            width: 220,
            child: DropdownButtonFormField<String>(
              initialValue: selectedSortKey,
              decoration: const InputDecoration(labelText: 'Sort by'),
              items: const [
                DropdownMenuItem(
                  value: _SortOption.featured,
                  child: Text('Featured first'),
                ),
                DropdownMenuItem(
                  value: _SortOption.newest,
                  child: Text('Newest first'),
                ),
                DropdownMenuItem(
                  value: _SortOption.rating,
                  child: Text('Top rated'),
                ),
                DropdownMenuItem(
                  value: _SortOption.priceLow,
                  child: Text('Price: low to high'),
                ),
                DropdownMenuItem(
                  value: _SortOption.priceHigh,
                  child: Text('Price: high to low'),
                ),
              ],
              onChanged: onSortChanged,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterGroupsSection extends StatelessWidget {
  final List<DiscoveryFilterGroupModel> groups;
  final Set<int> selectedValueIds;
  final ValueChanged<int> onFilterToggle;

  const _FilterGroupsSection({
    required this.groups,
    required this.selectedValueIds,
    required this.onFilterToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Filters',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 12),
        for (final group in groups.where((group) => group.values.isNotEmpty)) ...[
          _FilterGroupCard(
            group: group,
            selectedValueIds: selectedValueIds,
            onFilterToggle: onFilterToggle,
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _FilterGroupCard extends StatelessWidget {
  final DiscoveryFilterGroupModel group;
  final Set<int> selectedValueIds;
  final ValueChanged<int> onFilterToggle;

  const _FilterGroupCard({
    required this.group,
    required this.selectedValueIds,
    required this.onFilterToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            group.name,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final value in group.values.where((value) => value.productCount > 0))
                FilterChip(
                  label: Text('${value.value} (${value.productCount})'),
                  selected: selectedValueIds.contains(value.id),
                  onSelected: (_) => onFilterToggle(value.id),
                  selectedColor: AppColors.creamSoft,
                  checkmarkColor: AppColors.brownDeep,
                  side: const BorderSide(color: AppColors.border),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ResultSummaryBar extends StatelessWidget {
  final int productCount;
  final String? branchName;
  final bool hasActiveFilters;
  final VoidCallback onReset;

  const _ResultSummaryBar({
    required this.productCount,
    this.branchName,
    required this.hasActiveFilters,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            branchName == null
                ? '$productCount products available'
                : '$productCount products available for $branchName',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
        if (hasActiveFilters)
          TextButton.icon(
            onPressed: onReset,
            icon: const Icon(Icons.refresh),
            label: const Text('Reset'),
          ),
      ],
    );
  }
}

class _ProductDiscoveryCard extends StatelessWidget {
  final ProductModel product;
  final int? selectedBranchId;
  final bool isFavorite;
  final VoidCallback onTap;
  final VoidCallback onAddToCart;
  final VoidCallback onToggleWishlist;

  const _ProductDiscoveryCard({
    required this.product,
    required this.selectedBranchId,
    required this.isFavorite,
    required this.onTap,
    required this.onAddToCart,
    required this.onToggleWishlist,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final price = product.effectivePrice;
    final hasSale = product.salePrice != null && product.salePrice! < product.price;
    final subtitle = _productSummary(product, l10n);
    final branchLabel = selectedBranchId != null
        ? (product.branchName?.isNotEmpty == true
            ? product.branchName!
            : 'Selected branch')
        : (product.branchName?.isNotEmpty == true
            ? product.branchName!
            : 'Available across branches');

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(26),
      child: Ink(
        decoration: BoxDecoration(
          gradient: AppColors.surfaceGradient,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: AppColors.border),
          boxShadow: AppColors.panelShadow,
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  PremiumNetworkImage(
                    imageUrl: product.imageUrl,
                    height: 160,
                    borderRadius: BorderRadius.circular(20),
                    fallbackIcon: Icons.shopping_bag_outlined,
                    semanticLabel: product.localizedName(l10n),
                  ),
                  Positioned(
                    left: 12,
                    top: 12,
                    child: _StatusBadge(
                      label: product.stockQty > 0 ? 'In stock' : 'Out of stock',
                      backgroundColor: product.stockQty > 0
                          ? const Color(0xFFDCEFD7)
                          : const Color(0xFFF4D6D6),
                      foregroundColor: product.stockQty > 0
                          ? const Color(0xFF22593E)
                          : const Color(0xFF7A2424),
                    ),
                  ),
                  if (product.isFeatured)
                    const Positioned(
                      left: 12,
                      bottom: 12,
                      child: _StatusBadge(
                        label: 'Featured',
                        backgroundColor: AppColors.creamSoft,
                        foregroundColor: AppColors.brownDeep,
                      ),
                    ),
                  Positioned(
                    right: 12,
                    top: 12,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: onToggleWishlist,
                        borderRadius: BorderRadius.circular(999),
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: AppColors.white.withValues(alpha: 0.92),
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Icon(
                            isFavorite
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            color: isFavorite
                                ? const Color(0xFFB4473B)
                                : AppColors.brownDeep,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                product.localizedName(l10n),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textMuted,
                      height: 1.45,
                    ),
              ),
              const Spacer(),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _MetaPill(icon: Icons.storefront_outlined, label: branchLabel),
                  _MetaPill(
                    icon: Icons.star_border_rounded,
                    label:
                        '${product.averageRating.toStringAsFixed(1)} · ${product.reviewCount} reviews',
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'SAR ${price.toStringAsFixed(0)}',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.brownDeep,
                                  ),
                        ),
                        if (hasSale)
                          Text(
                            'SAR ${product.price.toStringAsFixed(0)}',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: AppColors.textMuted,
                                  decoration: TextDecoration.lineThrough,
                                ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: product.stockQty > 0 ? onAddToCart : null,
                    child: const Text('Add to cart'),
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

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color backgroundColor;
  final Color foregroundColor;

  const _StatusBadge({
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: foregroundColor,
              fontWeight: FontWeight.w800,
            ),
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MetaPill({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.brownDeep),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppColors.brownDeep,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        ],
      ),
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
    return Semantics(
      liveRegion: true,
      label: '$title. $subtitle',
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 10),
            Text(subtitle, style: const TextStyle(height: 1.5)),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: onPressed,
              child: Text(actionLabel),
            ),
          ],
        ),
      ),
    );
  }
}

String _productSummary(ProductModel product, AppLocalizations l10n) {
  final primary = (product.shortDescription ?? product.description ?? '').trim();
  if (primary.isNotEmpty) {
    return primary;
  }
  final packSize = (product.packSize ?? '').trim();
  if (packSize.isNotEmpty) {
    return 'Pack size: $packSize';
  }
  return l10n.t('product_default_description');
}

extension on ProductModel {
  double get effectivePrice {
    if (salePrice != null && salePrice! > 0 && salePrice! < price) {
      return salePrice!;
    }
    return price;
  }
}
