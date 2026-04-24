import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/extensions/localized_content.dart';
import '../../core/widgets/product_card.dart';
import '../../localization/app_locale_controller.dart';
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
  final AppLocaleController localeController;

  const ProductListPage({
    super.key,
    required this.category,
    this.apiService = const ApiService(),
    required this.localeController,
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
  String _sortKey = _SortOption.relevance;
  final Set<int> _selectedFilterValueIds = <int>{};
  final Set<String> _selectedPackSizes = <String>{};
  final Set<String> _selectedTagValues = <String>{};
  final Set<String> _selectedShippingModes = <String>{};
  String? _selectedPriceRangeKey;
  bool _isAddingToCart = false;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _selectedCategoryId = widget.category.id;
    widget.localeController.addListener(_handleStorefrontChanged);
    _categoriesFuture = _loadCategories();
    _branchesFuture = _loadBranches();
    _popularSearchTermsFuture = widget.apiService.fetchPopularSearchTerms();
    _discoveryFuture = _loadDiscovery();
  }

  @override
  void didUpdateWidget(covariant ProductListPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.localeController != widget.localeController) {
      oldWidget.localeController.removeListener(_handleStorefrontChanged);
      widget.localeController.addListener(_handleStorefrontChanged);
      _handleStorefrontChanged();
    }
  }

  @override
  void dispose() {
    widget.localeController.removeListener(_handleStorefrontChanged);
    _searchController.dispose();
    super.dispose();
  }

  Future<List<CategoryModel>> _loadCategories() {
    return widget.apiService.fetchCategories(
      language: widget.localeController.languageCode,
      forceRefresh: true,
    );
  }

  Future<List<BranchModel>> _loadBranches() {
    return widget.apiService.fetchBranches(
      forceRefresh: true,
      regionCode: widget.localeController.regionCode,
    );
  }

  Future<_DiscoveryViewData> _loadDiscovery() async {
    final categoryId = _selectedCategoryId ?? widget.category.id;
    final language = widget.localeController.languageCode;
    final regionCode = widget.localeController.regionCode;
    final responses = await Future.wait([
      widget.apiService.fetchCategoryDiscoveryProducts(
        categoryId,
        branchId: _selectedBranchId,
        language: language,
        regionCode: regionCode,
        query: _searchQuery,
        filterValueIds: _selectedFilterValueIds.toList(),
      ),
      widget.apiService.fetchDiscoveryFilters(
        categoryId: categoryId,
        branchId: _selectedBranchId,
        language: language,
        regionCode: regionCode,
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

  void _handleStorefrontChanged() {
    if (!mounted) {
      return;
    }
    setState(() {
      _selectedBranchId = null;
      _categoriesFuture = _loadCategories();
      _branchesFuture = _loadBranches();
      _discoveryFuture = _loadDiscovery();
    });
  }

  String _currencyCodeFor(ProductModel product) {
    return product.currencyCodeForRegion(
      widget.localeController.regionCode,
      fallback: widget.localeController.currencyCode,
    );
  }

  String _formatPrice(ProductModel product, double amount) {
    final normalized =
        amount % 1 == 0 ? amount.toStringAsFixed(0) : amount.toStringAsFixed(2);
    return '${_currencyCodeFor(product)} $normalized';
  }

  List<ProductModel> _sortProducts(List<ProductModel> products) {
    final sorted = List<ProductModel>.from(products);
    sorted.sort((left, right) {
      switch (_sortKey) {
        case _SortOption.relevance:
          if (_searchQuery.trim().isNotEmpty) {
            return 0;
          }
          final featuredCompare =
              (right.isFeatured ? 1 : 0).compareTo(left.isFeatured ? 1 : 0);
          if (featuredCompare != 0) {
            return featuredCompare;
          }
          final stockCompare = right.stockQty.compareTo(left.stockQty);
          if (stockCompare != 0) {
            return stockCompare;
          }
          return (right.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0))
              .compareTo(
                  left.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0));
        case _SortOption.priceLow:
          return left.effectivePrice.compareTo(right.effectivePrice);
        case _SortOption.priceHigh:
          return right.effectivePrice.compareTo(left.effectivePrice);
        case _SortOption.newest:
          return (right.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0))
              .compareTo(
                  left.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0));
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
          localeController: widget.localeController,
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
            context.l10n.t(
              'discovery_add_to_cart_success',
              {'name': product.localizedName(context.l10n)},
            ),
          ),
        ),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.t('discovery_add_to_cart_error'))),
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
                ? context.l10n.t(
                    'discovery_wishlist_removed',
                    {'name': product.localizedName(context.l10n)},
                  )
                : context.l10n.t(
                    'discovery_wishlist_saved',
                    {'name': product.localizedName(context.l10n)},
                  ),
          ),
        ),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.t('discovery_wishlist_error'))),
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
            title: l10n.t(
              'discovery_header_title',
              {'category': widget.category.localizedName(l10n)},
            ),
            subtitle: l10n.t('discovery_header_subtitle'),
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
                  final categories =
                      categorySnapshot.data ?? const <CategoryModel>[];
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
                    localeController: widget.localeController,
                    categories: categories,
                    branches: branches,
                    selectedCategoryId: safeCategoryId,
                    selectedBranchId: safeBranchId,
                    selectedSortKey: _sortKey,
                    onCategoryChanged: (value) {
                      setState(() {
                        _selectedCategoryId = value;
                        _selectedFilterValueIds.clear();
                        _selectedPackSizes.clear();
                        _selectedTagValues.clear();
                        _selectedShippingModes.clear();
                        _selectedPriceRangeKey = null;
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
          FutureBuilder<List<BranchModel>>(
            future: _branchesFuture,
            builder: (context, branchListSnapshot) {
              final activeBranches =
                  (branchListSnapshot.data ?? const <BranchModel>[])
                      .where((branch) => branch.isActive)
                      .toList();
              return FutureBuilder<_DiscoveryViewData>(
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
                      title: l10n.t('discovery_load_error_title'),
                      subtitle: l10n.t('discovery_load_error_desc'),
                      actionLabel: l10n.t('common_retry'),
                      onPressed: _reloadDiscovery,
                    );
                  }

                  final discovery = snapshot.data ?? const _DiscoveryViewData();
                  final retailFacets = _buildRetailFacets(
                    products: discovery.products,
                    branches: activeBranches,
                  );
                  final visibleProducts = _applyRetailFacets(
                    products: discovery.products,
                    branches: activeBranches,
                  );
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _RetailFacetSection(
                        facets: retailFacets,
                        selectedPackSizes: _selectedPackSizes,
                        selectedTagValues: _selectedTagValues,
                        selectedShippingModes: _selectedShippingModes,
                        selectedPriceRangeKey: _selectedPriceRangeKey,
                        onPackSizeToggle: (value) {
                          setState(() {
                            if (_selectedPackSizes.contains(value)) {
                              _selectedPackSizes.remove(value);
                            } else {
                              _selectedPackSizes.add(value);
                            }
                          });
                        },
                        onTagToggle: (value) {
                          setState(() {
                            if (_selectedTagValues.contains(value)) {
                              _selectedTagValues.remove(value);
                            } else {
                              _selectedTagValues.add(value);
                            }
                          });
                        },
                        onShippingToggle: (value) {
                          setState(() {
                            if (_selectedShippingModes.contains(value)) {
                              _selectedShippingModes.remove(value);
                            } else {
                              _selectedShippingModes.add(value);
                            }
                          });
                        },
                        onPriceChanged: (value) {
                          setState(() => _selectedPriceRangeKey = value);
                        },
                      ),
                      if (retailFacets.hasAny) const SizedBox(height: 16),
                      if (discovery.filters.isNotEmpty)
                        _FilterGroupsSection(
                          groups: discovery.filters,
                          localeController: widget.localeController,
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
                        productCount: visibleProducts.length,
                        branchName: _branchNameFromProducts(
                            visibleProducts, _selectedBranchId),
                        hasActiveFilters: _selectedFilterValueIds.isNotEmpty ||
                            _selectedPackSizes.isNotEmpty ||
                            _selectedTagValues.isNotEmpty ||
                            _selectedShippingModes.isNotEmpty ||
                            _selectedPriceRangeKey != null ||
                            _searchQuery.isNotEmpty ||
                            _selectedBranchId != null,
                        onReset: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                            _selectedBranchId = null;
                            _selectedFilterValueIds.clear();
                            _selectedPackSizes.clear();
                            _selectedTagValues.clear();
                            _selectedShippingModes.clear();
                            _selectedPriceRangeKey = null;
                            _sortKey = _SortOption.relevance;
                            _discoveryFuture = _loadDiscovery();
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      if (visibleProducts.isEmpty)
                        _StateCard(
                          title: l10n.t('discovery_empty_title'),
                          subtitle: l10n.t('discovery_empty_desc'),
                          actionLabel: l10n.t('discovery_reset_filters'),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _searchQuery = '';
                              _selectedBranchId = null;
                              _selectedFilterValueIds.clear();
                              _selectedPackSizes.clear();
                              _selectedTagValues.clear();
                              _selectedShippingModes.clear();
                              _selectedPriceRangeKey = null;
                              _sortKey = _SortOption.relevance;
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
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: crossAxisCount,
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 16,
                                mainAxisExtent: kProductCardMainAxisExtent,
                              ),
                              itemCount: visibleProducts.length,
                              itemBuilder: (context, index) {
                                final product = visibleProducts[index];
                                return ValueListenableBuilder<Set<int>>(
                                  valueListenable:
                                      ApiService.wishlistIdsListenable,
                                  builder: (context, wishlistIds, _) {
                                    final branchLabel = _selectedBranchId !=
                                            null
                                        ? (product.branchName?.isNotEmpty ==
                                                true
                                            ? product.branchName!
                                            : l10n.t('product_branch_selected'))
                                        : (product.branchName?.isNotEmpty ==
                                                true
                                            ? product.branchName!
                                            : l10n.t('product_branch_all'));
                                    final hasSale = product.salePrice != null &&
                                        product.salePrice! < product.price;
                                    return ProductCard(
                                      name: product.localizedName(l10n),
                                      arabicTitle: l10n.isArabic
                                          ? null
                                          : (product.nameAr ?? '')
                                                  .trim()
                                                  .isNotEmpty
                                              ? product.nameAr
                                              : null,
                                      subtitle: _productSummary(product, l10n),
                                      price: _formatPrice(
                                        product,
                                        product.effectivePrice,
                                      ),
                                      originalPrice: hasSale
                                          ? _formatPrice(product, product.price)
                                          : null,
                                      imageUrl: product.imageUrl,
                                      branchLabel: branchLabel,
                                      averageRating: product.averageRating,
                                      reviewCount: product.reviewCount,
                                      isFeatured: product.isFeatured,
                                      stockQty: product.stockQty,
                                      isFavorite:
                                          wishlistIds.contains(product.id),
                                      showWishlistPlaceholder: true,
                                      onTap: () => _openProductDetails(product),
                                      onAddToCart: () => _addToCart(product),
                                      onFavoriteToggle: () =>
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
              );
            },
          ),
        ],
      ),
    );
  }

  String? _branchNameFromProducts(
      List<ProductModel> products, int? selectedBranchId) {
    if (selectedBranchId == null) {
      return null;
    }
    for (final product in products) {
      if (product.branchId == selectedBranchId &&
          (product.branchName ?? '').trim().isNotEmpty) {
        return product.branchName;
      }
    }
    return context.l10n.t('product_branch_selected');
  }

  _RetailFacetOptions _buildRetailFacets({
    required List<ProductModel> products,
    required List<BranchModel> branches,
  }) {
    final packSizes = <String>{};
    final tagValues = <String>{};
    var hasDelivery = false;
    var hasPickup = false;

    for (final product in products) {
      final packSize = (product.packSize ?? '').trim();
      if (packSize.isNotEmpty) {
        packSizes.add(packSize);
      }
      tagValues.addAll(_tagTokens(product.tags));
      final shipping = _shippingAvailability(product, branches);
      hasDelivery = hasDelivery || shipping.$1;
      hasPickup = hasPickup || shipping.$2;
    }

    final sortedPackSizes = packSizes.toList()
      ..sort(
          (left, right) => left.toLowerCase().compareTo(right.toLowerCase()));
    final sortedTags = tagValues.toList()
      ..sort(
          (left, right) => left.toLowerCase().compareTo(right.toLowerCase()));

    return _RetailFacetOptions(
      priceRanges: _priceRangesFor(products),
      packSizes: sortedPackSizes,
      shippingModes: [
        if (hasDelivery) _RetailShippingMode.delivery,
        if (hasPickup) _RetailShippingMode.pickup,
      ],
      tags: sortedTags.take(12).toList(),
    );
  }

  List<ProductModel> _applyRetailFacets({
    required List<ProductModel> products,
    required List<BranchModel> branches,
  }) {
    return products.where((product) {
      if (_selectedPriceRangeKey != null) {
        final priceRange = _priceRangeByKey(_selectedPriceRangeKey!);
        if (priceRange != null &&
            !_matchesPriceRange(product.effectivePrice, priceRange)) {
          return false;
        }
      }
      if (_selectedPackSizes.isNotEmpty) {
        final packSize = (product.packSize ?? '').trim();
        if (!_selectedPackSizes.contains(packSize)) {
          return false;
        }
      }
      if (_selectedTagValues.isNotEmpty) {
        final tags = _tagTokens(product.tags).toSet();
        if (_selectedTagValues.intersection(tags).isEmpty) {
          return false;
        }
      }
      if (_selectedShippingModes.isNotEmpty) {
        final shipping = _shippingAvailability(product, branches);
        final supportsDelivery =
            _selectedShippingModes.contains(_RetailShippingMode.delivery) &&
                shipping.$1;
        final supportsPickup =
            _selectedShippingModes.contains(_RetailShippingMode.pickup) &&
                shipping.$2;
        if (!supportsDelivery && !supportsPickup) {
          return false;
        }
      }
      return true;
    }).toList();
  }
}

class _RetailFacetOptions {
  final List<_PriceRangeOption> priceRanges;
  final List<String> packSizes;
  final List<String> shippingModes;
  final List<String> tags;

  const _RetailFacetOptions({
    this.priceRanges = const <_PriceRangeOption>[],
    this.packSizes = const <String>[],
    this.shippingModes = const <String>[],
    this.tags = const <String>[],
  });

  bool get hasAny =>
      priceRanges.isNotEmpty ||
      packSizes.isNotEmpty ||
      shippingModes.isNotEmpty ||
      tags.isNotEmpty;
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
  static const relevance = 'relevance';
  static const newest = 'newest';
  static const priceLow = 'price_low';
  static const priceHigh = 'price_high';
}

class _RetailShippingMode {
  static const delivery = 'delivery';
  static const pickup = 'pickup';
}

class _PriceRangeOption {
  final String key;
  final double? min;
  final double? max;

  const _PriceRangeOption({
    required this.key,
    this.min,
    this.max,
  });
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
    final l10n = context.l10n;
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        return TextField(
          controller: controller,
          onSubmitted: onSubmitted,
          decoration: InputDecoration(
            hintText: l10n.t('discovery_search_hint'),
            prefixIcon: const Icon(Icons.search),
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (value.text.trim().isNotEmpty)
                  IconButton(
                    onPressed: () {
                      controller.clear();
                      onSearchPressed();
                    },
                    icon: const Icon(Icons.close_rounded),
                    tooltip: l10n.t('common_close'),
                  ),
                IconButton(
                  onPressed: onSearchPressed,
                  icon: const Icon(Icons.arrow_forward_rounded),
                  tooltip: l10n.t('discovery_search_action'),
                ),
              ],
            ),
          ),
        );
      },
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
  final AppLocaleController localeController;
  final List<CategoryModel> categories;
  final List<BranchModel> branches;
  final int? selectedCategoryId;
  final int? selectedBranchId;
  final String selectedSortKey;
  final ValueChanged<int?> onCategoryChanged;
  final ValueChanged<int?> onBranchChanged;
  final ValueChanged<String?> onSortChanged;

  const _ControlsPanel({
    required this.localeController,
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
    final l10n = context.l10n;
    final categoryField = DropdownButtonFormField<int?>(
      initialValue: selectedCategoryId,
      decoration:
          InputDecoration(labelText: l10n.t('discovery_filter_category')),
      items: categories
          .map(
            (category) => DropdownMenuItem<int?>(
              value: category.id,
              child: Text(category.localizedName(l10n)),
            ),
          )
          .toList(),
      onChanged: onCategoryChanged,
    );
    final branchField = DropdownButtonFormField<int?>(
      initialValue: selectedBranchId,
      decoration: InputDecoration(labelText: l10n.t('discovery_filter_branch')),
      items: [
        DropdownMenuItem<int?>(
          value: null,
          child: Text(l10n.t('discovery_all_branches')),
        ),
        ...branches.where((branch) => branch.isActive).map(
              (branch) => DropdownMenuItem<int?>(
                value: branch.id,
                child: Text(branch.name),
              ),
            ),
      ],
      onChanged: onBranchChanged,
    );
    final sortField = DropdownButtonFormField<String>(
      initialValue: selectedSortKey,
      decoration: InputDecoration(labelText: l10n.t('discovery_sort_label')),
      items: [
        DropdownMenuItem(
          value: _SortOption.relevance,
          child: Text(l10n.t('discovery_sort_relevance')),
        ),
        DropdownMenuItem(
          value: _SortOption.newest,
          child: Text(l10n.t('discovery_sort_newest')),
        ),
        DropdownMenuItem(
          value: _SortOption.priceLow,
          child: Text(l10n.t('discovery_sort_price_low')),
        ),
        DropdownMenuItem(
          value: _SortOption.priceHigh,
          child: Text(l10n.t('discovery_sort_price_high')),
        ),
      ],
      onChanged: onSortChanged,
    );

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          if (width < 640) {
            return Column(
              children: [
                categoryField,
                const SizedBox(height: 12),
                branchField,
                const SizedBox(height: 12),
                sortField,
              ],
            );
          }
          if (width < 980) {
            return Column(
              children: [
                Row(
                  children: [
                    Expanded(child: categoryField),
                    const SizedBox(width: 12),
                    Expanded(child: branchField),
                  ],
                ),
                const SizedBox(height: 12),
                sortField,
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: categoryField),
              const SizedBox(width: 14),
              Expanded(child: branchField),
              const SizedBox(width: 14),
              Expanded(child: sortField),
            ],
          );
        },
      ),
    );
  }
}

class _FilterGroupsSection extends StatelessWidget {
  final List<DiscoveryFilterGroupModel> groups;
  final AppLocaleController localeController;
  final Set<int> selectedValueIds;
  final ValueChanged<int> onFilterToggle;

  const _FilterGroupsSection({
    required this.groups,
    required this.localeController,
    required this.selectedValueIds,
    required this.onFilterToggle,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.t('discovery_more_filters'),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 12),
        for (final group
            in groups.where((group) => group.values.isNotEmpty)) ...[
          _FilterGroupCard(
            group: group,
            localeController: localeController,
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
  final AppLocaleController localeController;
  final Set<int> selectedValueIds;
  final ValueChanged<int> onFilterToggle;

  const _FilterGroupCard({
    required this.group,
    required this.localeController,
    required this.selectedValueIds,
    required this.onFilterToggle,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
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
            _localizedGroupName(group, l10n),
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final value
                  in group.values.where((value) => value.productCount > 0))
                FilterChip(
                  label: Text(
                    '${_localizedFilterValue(value, localeController)} (${value.productCount})',
                  ),
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
    final l10n = context.l10n;
    return Row(
      children: [
        Expanded(
          child: Text(
            branchName == null
                ? l10n.t(
                    'discovery_results_summary_all',
                    {'count': '$productCount'},
                  )
                : l10n.t(
                    'discovery_results_summary_branch',
                    {'count': '$productCount', 'branch': branchName!},
                  ),
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
        if (hasActiveFilters)
          TextButton.icon(
            onPressed: onReset,
            icon: const Icon(Icons.refresh),
            label: Text(l10n.t('discovery_reset_filters')),
          ),
      ],
    );
  }
}

class _RetailFacetSection extends StatelessWidget {
  final _RetailFacetOptions facets;
  final Set<String> selectedPackSizes;
  final Set<String> selectedTagValues;
  final Set<String> selectedShippingModes;
  final String? selectedPriceRangeKey;
  final ValueChanged<String> onPackSizeToggle;
  final ValueChanged<String> onTagToggle;
  final ValueChanged<String> onShippingToggle;
  final ValueChanged<String?> onPriceChanged;

  const _RetailFacetSection({
    required this.facets,
    required this.selectedPackSizes,
    required this.selectedTagValues,
    required this.selectedShippingModes,
    required this.selectedPriceRangeKey,
    required this.onPackSizeToggle,
    required this.onTagToggle,
    required this.onShippingToggle,
    required this.onPriceChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (!facets.hasAny) {
      return const SizedBox.shrink();
    }
    final l10n = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.t('discovery_shop_by'),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 12),
        if (facets.priceRanges.isNotEmpty) ...[
          _FacetBlock(
            title: l10n.t('discovery_filter_price'),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final range in facets.priceRanges)
                  ChoiceChip(
                    label: Text(_localizedPriceRange(context, range)),
                    selected: selectedPriceRangeKey == range.key,
                    onSelected: (_) => onPriceChanged(
                      selectedPriceRangeKey == range.key ? null : range.key,
                    ),
                    selectedColor: AppColors.creamSoft,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (facets.packSizes.isNotEmpty) ...[
          _FacetBlock(
            title: l10n.t('discovery_filter_pack_size'),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final packSize in facets.packSizes)
                  FilterChip(
                    label: Text(packSize),
                    selected: selectedPackSizes.contains(packSize),
                    onSelected: (_) => onPackSizeToggle(packSize),
                    selectedColor: AppColors.creamSoft,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (facets.shippingModes.isNotEmpty) ...[
          _FacetBlock(
            title: l10n.t('discovery_filter_shipping'),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final mode in facets.shippingModes)
                  FilterChip(
                    label: Text(
                      mode == _RetailShippingMode.delivery
                          ? l10n.t('discovery_shipping_delivery')
                          : l10n.t('discovery_shipping_pickup'),
                    ),
                    selected: selectedShippingModes.contains(mode),
                    onSelected: (_) => onShippingToggle(mode),
                    selectedColor: AppColors.creamSoft,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (facets.tags.isNotEmpty)
          _FacetBlock(
            title: l10n.t('discovery_filter_tags'),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final tag in facets.tags)
                  FilterChip(
                    label: Text(tag),
                    selected: selectedTagValues.contains(tag),
                    onSelected: (_) => onTagToggle(tag),
                    selectedColor: AppColors.creamSoft,
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _FacetBlock extends StatelessWidget {
  final String title;
  final Widget child;

  const _FacetBlock({
    required this.title,
    required this.child,
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
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 12),
          child,
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
  final primary =
      (product.shortDescription ?? product.description ?? '').trim();
  if (primary.isNotEmpty) {
    return primary;
  }
  final packSize = (product.packSize ?? '').trim();
  if (packSize.isNotEmpty) {
    return '${l10n.t('product_pack_size_prefix')}: $packSize';
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

List<String> _tagTokens(String? rawTags) {
  return (rawTags ?? '')
      .split(',')
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toSet()
      .toList();
}

List<_PriceRangeOption> _priceRangesFor(List<ProductModel> products) {
  if (products.isEmpty) {
    return const <_PriceRangeOption>[];
  }
  return const [
    _PriceRangeOption(key: 'under_25', max: 25),
    _PriceRangeOption(key: '25_50', min: 25, max: 50),
    _PriceRangeOption(key: '50_100', min: 50, max: 100),
    _PriceRangeOption(key: '100_plus', min: 100),
  ];
}

_PriceRangeOption? _priceRangeByKey(String key) {
  switch (key) {
    case 'under_25':
      return const _PriceRangeOption(key: 'under_25', max: 25);
    case '25_50':
      return const _PriceRangeOption(key: '25_50', min: 25, max: 50);
    case '50_100':
      return const _PriceRangeOption(key: '50_100', min: 50, max: 100);
    case '100_plus':
      return const _PriceRangeOption(key: '100_plus', min: 100);
  }
  return null;
}

bool _matchesPriceRange(double amount, _PriceRangeOption option) {
  final min = option.min;
  final max = option.max;
  if (min != null && amount < min) {
    return false;
  }
  if (max != null && amount >= max) {
    return false;
  }
  return true;
}

(bool, bool) _shippingAvailability(
  ProductModel product,
  List<BranchModel> branches,
) {
  final availableIds = product.availableBranchIds.toSet();
  var hasDelivery = false;
  var hasPickup = false;

  for (final branch in branches) {
    if (availableIds.isNotEmpty && !availableIds.contains(branch.id)) {
      continue;
    }
    hasDelivery = hasDelivery || branch.deliveryAvailable;
    hasPickup = hasPickup || branch.pickupAvailable;
  }

  return (hasDelivery, hasPickup);
}

String _localizedPriceRange(BuildContext context, _PriceRangeOption option) {
  final l10n = context.l10n;
  switch (option.key) {
    case 'under_25':
      return l10n.t('discovery_price_under_25');
    case '25_50':
      return l10n.t('discovery_price_25_50');
    case '50_100':
      return l10n.t('discovery_price_50_100');
    case '100_plus':
      return l10n.t('discovery_price_100_plus');
    default:
      return option.key;
  }
}

String _localizedGroupName(
  DiscoveryFilterGroupModel group,
  AppLocalizations l10n,
) {
  switch (group.slug) {
    case 'brand':
      return l10n.t('discovery_filter_brand');
    case 'size':
    case 'pack_size':
      return l10n.t('discovery_filter_pack_size');
    case 'delivery_method':
    case 'shipping':
      return l10n.t('discovery_filter_shipping');
    case 'function':
    case 'tags':
      return l10n.t('discovery_filter_tags');
    default:
      return group.name;
  }
}

String _localizedFilterValue(
  DiscoveryFilterValueModel value,
  AppLocaleController controller,
) {
  final arabic = value.valueAr?.trim();
  if (controller.isArabic && arabic != null && arabic.isNotEmpty) {
    return arabic;
  }
  return value.value;
}
