import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/extensions/localized_content.dart';
import '../../core/widgets/brand_logo.dart';
import '../../core/widgets/language_toggle.dart';
import '../../core/widgets/premium_network_image.dart';
import '../../core/widgets/product_card.dart';
import '../../core/widgets/section_title.dart';
import '../../localization/app_locale_controller.dart';
import '../../localization/app_localizations.dart';
import '../../models/branch_model.dart';
import '../../models/category_model.dart';
import '../../models/cms_page_model.dart';
import '../../models/offer_model.dart';
import '../../models/product_model.dart';
import '../../models/support_settings_model.dart';
import '../../services/api_service.dart';
import '../auth/login_page.dart';
import '../navigation/app_shell.dart';
import '../products/product_details_page.dart';
import '../products/product_list_page.dart';
import 'widgets/luxury_banner_slider.dart';

class HomePage extends StatefulWidget {
  final VoidCallback? onBrowseProducts;
  final VoidCallback? onChangeBranch;
  final VoidCallback? onAddToCart;
  final ApiService apiService;
  final AppLocaleController localeController;
  final bool showAppBar;
  final HomeSection requestedSection;
  final int sectionRequestId;

  const HomePage({
    super.key,
    this.onBrowseProducts,
    this.onChangeBranch,
    this.onAddToCart,
    this.apiService = const ApiService(),
    required this.localeController,
    this.showAppBar = true,
    this.requestedSection = HomeSection.hero,
    this.sectionRequestId = 0,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _scrollController = ScrollController();
  final _heroKey = GlobalKey();
  final _categoriesKey = GlobalKey();
  final _featuredKey = GlobalKey();
  final _offersKey = GlobalKey();
  final _footerKey = GlobalKey();
  late Future<List<CategoryModel>> _categoriesFuture;
  late Future<List<ProductModel>> _featuredProductsFuture;
  late Future<List<BranchModel>> _branchesFuture;
  late Future<List<OfferModel>> _offersFuture;
  late Future<List<CmsPageModel>> _deliveryBlocksFuture;
  late Future<SupportSettingsModel> _supportSettingsFuture;
  int? _selectedBranchId;
  bool _isAddingToCart = false;

  @override
  void initState() {
    super.initState();
    _loadHomeContent();
  }

  @override
  void didUpdateWidget(covariant HomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.sectionRequestId != oldWidget.sectionRequestId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToSection(widget.requestedSection);
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _loadHomeContent() {
    _categoriesFuture = widget.apiService.fetchCategories();
    _featuredProductsFuture = widget.apiService.fetchFeaturedProducts();
    _branchesFuture = widget.apiService.fetchBranches();
    _offersFuture = widget.apiService.fetchOffers();
    _deliveryBlocksFuture =
        widget.apiService.fetchCmsPages(section: 'delivery_information');
    _supportSettingsFuture = widget.apiService.fetchSupportSettings();
  }

  Future<void> _refreshHomeContent() async {
    setState(() {
      widget.apiService.clearPublicCatalogCache();
      _categoriesFuture = widget.apiService.fetchCategories(forceRefresh: true);
      _featuredProductsFuture =
          widget.apiService.fetchFeaturedProducts(forceRefresh: true);
      _branchesFuture = widget.apiService.fetchBranches(forceRefresh: true);
      _offersFuture = widget.apiService.fetchOffers();
      _deliveryBlocksFuture =
          widget.apiService.fetchCmsPages(section: 'delivery_information');
      _supportSettingsFuture = widget.apiService.fetchSupportSettings();
    });
    try {
      await Future.wait([
        _categoriesFuture,
        _featuredProductsFuture,
        _branchesFuture,
        _offersFuture,
        _deliveryBlocksFuture,
        _supportSettingsFuture,
      ]);
    } catch (_) {
      // Keep section-level empty and error states visible instead of surfacing
      // refresh failures as uncaught exceptions.
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
    final currentIds = ApiService.wishlistIdsListenable.value;
    final isFavorite = currentIds.contains(product.id);

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

  Future<void> _scrollToSection(HomeSection section) async {
    final targetContext = switch (section) {
      HomeSection.hero => _heroKey.currentContext,
      HomeSection.featured => _featuredKey.currentContext,
      HomeSection.offers => _offersKey.currentContext,
    };

    if (targetContext == null) {
      return;
    }

    await Scrollable.ensureVisible(
      targetContext,
      alignment: section == HomeSection.hero ? 0 : 0.06,
      duration: const Duration(milliseconds: 550),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isWide = MediaQuery.sizeOf(context).width >= 980;

    return Scaffold(
      appBar: widget.showAppBar
          ? AppBar(
              toolbarHeight: 82,
              title: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const BrandLogo(
                    size: 56,
                    padding: EdgeInsets.zero,
                    showShadow: false,
                    transparentHighlight: false,
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        l10n.t('app_title'),
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontSize: 19,
                            ),
                      ),
                      Text(
                        l10n.t('brand_tagline'),
                        style:
                            Theme.of(context).textTheme.labelMedium?.copyWith(
                                  color: AppColors.goldMuted,
                                  letterSpacing: 0.6,
                                ),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 16),
                  child: Center(
                    child: LanguageToggle(
                      controller: widget.localeController,
                      compact: true,
                    ),
                  ),
                ),
              ],
            )
          : null,
      body: RefreshIndicator(
        onRefresh: _refreshHomeContent,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final contentWidth =
                constraints.maxWidth > 1280 ? 1280.0 : constraints.maxWidth;

            return Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: contentWidth,
                child: ListView(
                  controller: _scrollController,
                  padding: EdgeInsets.fromLTRB(
                    0,
                    isWide ? 30 : 8,
                    0,
                    isWide ? 36 : 12,
                  ),
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    KeyedSubtree(
                      key: _heroKey,
                      child: LuxuryBannerSlider(
                        onBrowseProducts: widget.onBrowseProducts,
                        onChangeBranch: widget.onChangeBranch,
                      ),
                    ),
                    KeyedSubtree(
                      key: _categoriesKey,
                      child:
                          SectionTitle(title: l10n.t('home_main_categories')),
                    ),
                    _CategorySection(
                      categoriesFuture: _categoriesFuture,
                      apiService: widget.apiService,
                      onRetry: _refreshHomeContent,
                    ),
                    KeyedSubtree(
                      key: _featuredKey,
                      child:
                          SectionTitle(title: l10n.t('home_featured_products')),
                    ),
                    _FeaturedSection(
                      featuredProductsFuture: _featuredProductsFuture,
                      onAddToCart: _handleAddToCart,
                      onProductTap: _openProductDetails,
                      onToggleWishlist: _toggleWishlist,
                      onRetry: _refreshHomeContent,
                    ),
                    KeyedSubtree(
                      key: _offersKey,
                      child: SectionTitle(title: l10n.t('home_special_offers')),
                    ),
                    _OfferSection(
                      offersFuture: _offersFuture,
                      featuredProductsFuture: _featuredProductsFuture,
                      onRetry: _refreshHomeContent,
                      onOfferTap: _openOfferDestination,
                    ),
                    SectionTitle(title: l10n.t('home_branch_selection')),
                    _BranchSection(
                      branchesFuture: _branchesFuture,
                      selectedBranchId: _selectedBranchId,
                      onBranchSelected: (branchId) {
                        setState(() => _selectedBranchId = branchId);
                      },
                      onRetry: _refreshHomeContent,
                      onChangeBranch: widget.onChangeBranch,
                    ),
                    SectionTitle(title: l10n.t('home_delivery_information')),
                    _DeliveryInfoSection(
                      selectedBranchId: _selectedBranchId,
                      branchesFuture: _branchesFuture,
                      deliveryBlocksFuture: _deliveryBlocksFuture,
                      supportSettingsFuture: _supportSettingsFuture,
                      onRetry: _refreshHomeContent,
                    ),
                    KeyedSubtree(
                      key: _footerKey,
                      child: const _HomeFooter(),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _handleAddToCart(ProductModel product) async {
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
          content: Text(context.l10n.t('home_add_to_cart_success',
              {'name': product.localizedName(context.l10n)})),
          action: widget.onAddToCart == null
              ? null
              : SnackBarAction(
                  label: context.l10n.t('common_view_cart'),
                  onPressed: widget.onAddToCart!,
                ),
        ),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.t('home_add_to_cart_error'))),
      );
    } finally {
      if (mounted) {
        setState(() => _isAddingToCart = false);
      }
    }
  }

  Future<void> _openOfferDestination(OfferModel offer) async {
    if (offer.productId != null) {
      try {
        final detail = await widget.apiService.fetchProductDetail(offer.productId!);
        final branches = await _branchesFuture;
        if (!mounted) {
          return;
        }
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ProductDetailsPage(
              product: detail.product,
              branches: branches,
              apiService: widget.apiService,
            ),
          ),
        );
        return;
      } catch (_) {
        // Fall back to category navigation below.
      }
    }

    if (offer.categoryId != null) {
      final categories = await _categoriesFuture;
      CategoryModel? targetCategory;
      for (final category in categories) {
        if (category.id == offer.categoryId) {
          targetCategory = category;
          break;
        }
      }
      if (targetCategory != null && mounted) {
        final resolvedCategory = targetCategory;
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ProductListPage(
              category: resolvedCategory,
              apiService: widget.apiService,
            ),
          ),
        );
        return;
      }
    }

    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'This offer is not linked to an available product or category yet.',
        ),
      ),
    );
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
}

class _CategorySection extends StatelessWidget {
  final Future<List<CategoryModel>> categoriesFuture;
  final ApiService apiService;
  final Future<void> Function() onRetry;

  const _CategorySection({
    required this.categoriesFuture,
    required this.apiService,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return FutureBuilder<List<CategoryModel>>(
      future: categoriesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _SectionLoading(height: 150);
        }

        if (snapshot.hasError) {
          return _SectionMessageCard(
            title: l10n.t('home_categories_error_title'),
            description: l10n.t('home_categories_error_desc'),
            actionLabel: l10n.t('common_retry'),
            onPressed: onRetry,
          );
        }

        final categories = snapshot.data ?? const <CategoryModel>[];
        if (categories.isEmpty) {
          return _SectionMessageCard(
            title: l10n.t('home_categories_empty_title'),
            description: l10n.t('home_categories_empty_desc'),
            actionLabel: l10n.t('common_retry'),
            onPressed: onRetry,
          );
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final preferredCrossAxisCount = width >= 1160
                ? 4
                : width >= 900
                    ? 3
                    : width >= 640
                        ? 2
                        : 1;
            final crossAxisCount = categories.length < preferredCrossAxisCount
                ? categories.length
                : preferredCrossAxisCount;

            return GridView.builder(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                mainAxisSpacing: 18,
                crossAxisSpacing: 18,
                mainAxisExtent: width >= 1160
                    ? 216
                    : width >= 900
                        ? 224
                        : width >= 640
                            ? 212
                            : 198,
              ),
              itemCount: categories.length,
              itemBuilder: (context, index) {
                final category = categories[index];
                return _HomeCategoryCard(
                  category: category,
                  actionLabel: l10n.t('categories_view_collection'),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ProductListPage(
                          category: category,
                          apiService: apiService,
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
    );
  }
}

class _HomeCategoryCard extends StatefulWidget {
  final CategoryModel category;
  final String actionLabel;
  final VoidCallback? onTap;

  const _HomeCategoryCard({
    required this.category,
    required this.actionLabel,
    this.onTap,
  });

  @override
  State<_HomeCategoryCard> createState() => _HomeCategoryCardState();
}

class _HomeCategoryCardState extends State<_HomeCategoryCard> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final card = InkWell(
      onTap: widget.onTap,
      borderRadius: BorderRadius.circular(26),
      onHover: (hovering) => setState(() => _hovering = hovering),
      child: Ink(
        decoration: BoxDecoration(
          gradient: AppColors.surfaceGradient,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: AppColors.border),
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: AppColors.goldGradient,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: AppColors.softShadow,
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  color: AppColors.primaryDark,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                widget.category.localizedName(context.l10n),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const Spacer(),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.actionLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: AppColors.brown,
                          ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    color: AppColors.brownDeep,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      transform: Matrix4.translationValues(0, _hovering ? -4.0 : 0.0, 0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        boxShadow: _hovering ? AppColors.panelShadow : AppColors.softShadow,
      ),
      child: card,
    );
  }
}

class _FeaturedSection extends StatelessWidget {
  final Future<List<ProductModel>> featuredProductsFuture;
  final Future<void> Function(ProductModel product) onAddToCart;
  final Future<void> Function(ProductModel product) onProductTap;
  final Future<void> Function(ProductModel product) onToggleWishlist;
  final Future<void> Function() onRetry;

  const _FeaturedSection({
    required this.featuredProductsFuture,
    required this.onAddToCart,
    required this.onProductTap,
    required this.onToggleWishlist,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return FutureBuilder<List<ProductModel>>(
      future: featuredProductsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _SectionLoading(height: 310);
        }

        if (snapshot.hasError) {
          return _SectionMessageCard(
            title: l10n.t('home_featured_error_title'),
            description: l10n.t('home_featured_error_desc'),
            actionLabel: l10n.t('common_retry'),
            onPressed: onRetry,
          );
        }

        final products = snapshot.data ?? const <ProductModel>[];
        if (products.isEmpty) {
          return _SectionMessageCard(
            title: l10n.t('home_featured_empty_title'),
            description: l10n.t('home_featured_empty_desc'),
            actionLabel: l10n.t('common_retry'),
            onPressed: onRetry,
          );
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final preferredCrossAxisCount = width >= 1160
                ? 4
                : width >= 900
                    ? 3
                    : width >= 640
                        ? 2
                        : 1;
            final crossAxisCount = products.length < preferredCrossAxisCount
                ? products.length
                : preferredCrossAxisCount;

            return GridView.builder(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                mainAxisSpacing: 18,
                crossAxisSpacing: 18,
                mainAxisExtent: kProductCardMainAxisExtent,
              ),
              itemCount: products.length,
              itemBuilder: (context, index) {
                final product = products[index];
                return ValueListenableBuilder<Set<int>>(
                  valueListenable: ApiService.wishlistIdsListenable,
                  builder: (context, wishlistIds, _) {
                    return ProductCard(
                      name: product.localizedName(l10n),
                      subtitle: _productSubtitle(product, l10n),
                      price: 'SAR ${product.effectivePrice.toStringAsFixed(0)}',
                      imageUrl: product.imageUrl,
                      isFavorite: wishlistIds.contains(product.id),
                      onFavoriteToggle: () => onToggleWishlist(product),
                      onAddToCart: () => onAddToCart(product),
                      onTap: () => onProductTap(product),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}

extension on ProductModel {
  double get effectivePrice {
    if (salePrice != null && salePrice! > 0 && salePrice! < price) {
      return salePrice!;
    }
    return price;
  }
}

class _OfferSection extends StatelessWidget {
  final Future<List<OfferModel>> offersFuture;
  final Future<List<ProductModel>> featuredProductsFuture;
  final Future<void> Function(OfferModel offer) onOfferTap;
  final Future<void> Function() onRetry;

  const _OfferSection({
    required this.offersFuture,
    required this.featuredProductsFuture,
    required this.onOfferTap,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<OfferModel>>(
      future: offersFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _SectionLoading(height: 190);
        }

        if (snapshot.hasError) {
          return _SectionMessageCard(
            title: 'Offers are unavailable right now',
            description:
                'The latest campaign banners could not be loaded. Retry to refresh the active offers.',
            actionLabel: 'Retry',
            onPressed: onRetry,
          );
        }

        final offers = snapshot.data ?? const <OfferModel>[];
        if (offers.isEmpty) {
          return FutureBuilder<List<ProductModel>>(
            future: featuredProductsFuture,
            builder: (context, featuredSnapshot) {
              final featuredProducts =
                  featuredSnapshot.data ?? const <ProductModel>[];
              final saleProducts = featuredProducts
                  .where(
                    (product) =>
                        product.salePrice != null &&
                        product.salePrice! > 0 &&
                        product.salePrice! < product.price,
                  )
                  .toList();
              if (saleProducts.isEmpty) {
                return _SectionMessageCard(
                  title: 'No active offers yet',
                  description:
                      'Promotions created from the admin panel will appear here automatically.',
                  actionLabel: 'Retry',
                  onPressed: onRetry,
                );
              }

              return _OfferGrid(
                offers: saleProducts
                    .map(
                      (product) => OfferModel(
                        id: product.id,
                        title: product.localizedName(context.l10n),
                        subtitle: product.shortDescription,
                        description:
                            product.fullDescription ?? product.description,
                        bannerUrl: product.imageUrl,
                        discountType: 'product',
                        discountValue:
                            product.price - (product.salePrice ?? product.price),
                        productId: product.id,
                        categoryId: product.categoryId,
                        branchId: product.branchId,
                        isActive: true,
                      ),
                    )
                    .toList(),
                onOfferTap: onOfferTap,
              );
            },
          );
        }

        return _OfferGrid(
          offers: offers,
          onOfferTap: onOfferTap,
        );
      },
    );
  }
}

class _OfferGrid extends StatelessWidget {
  final List<OfferModel> offers;
  final Future<void> Function(OfferModel offer) onOfferTap;

  const _OfferGrid({
    required this.offers,
    required this.onOfferTap,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final crossAxisCount = width >= 1180
            ? 3
            : width >= 760
                ? 2
                : 1;
        final visibleOffers = offers.take(crossAxisCount * 2).toList();

        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 18,
            crossAxisSpacing: 18,
            mainAxisExtent: 340,
          ),
          itemCount: visibleOffers.length,
          itemBuilder: (context, index) {
            return _OfferCard(
              offer: visibleOffers[index],
              onTap: () => onOfferTap(visibleOffers[index]),
            );
          },
        );
      },
    );
  }
}

class _OfferCard extends StatelessWidget {
  final OfferModel offer;
  final VoidCallback onTap;

  const _OfferCard({
    required this.offer,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage = (offer.bannerUrl ?? '').isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2F1C14), AppColors.brownDeep, Color(0xFF86643E)],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0x2DFFF5E9)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F2D1A12),
            blurRadius: 22,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasImage)
            PremiumNetworkImage(
              imageUrl: offer.bannerUrl,
              height: 148,
              borderRadius: BorderRadius.circular(20),
              fallbackIcon: Icons.local_offer_outlined,
            )
          else
            Container(
              height: 90,
              decoration: BoxDecoration(
                color: AppColors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
              ),
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: const Icon(
                Icons.auto_awesome,
                color: AppColors.creamSoft,
                size: 28,
              ),
            ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: AppColors.accentGold.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              _offerBadge(offer),
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppColors.creamSoft,
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            offer.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppColors.creamSoft,
                  fontWeight: FontWeight.w800,
                ),
          ),
          if ((offer.subtitle ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              offer.subtitle!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.creamSoft.withValues(alpha: 0.9),
                  ),
            ),
          ],
          if ((offer.description ?? '').isNotEmpty) ...[
            const SizedBox(height: 10),
            Expanded(
              child: Text(
                offer.description!,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.creamSoft.withValues(alpha: 0.82),
                      height: 1.5,
                    ),
              ),
            ),
          ] else
            const Spacer(),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Text(
                  _offerScope(offer),
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: AppColors.creamSoft.withValues(alpha: 0.86),
                      ),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton(
                onPressed: onTap,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.creamSoft,
                  foregroundColor: AppColors.brownDeep,
                ),
                child: const Text('Shop now'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HomeFooter extends StatelessWidget {
  const _HomeFooter();

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 980;
    final l10n = context.l10n;

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      padding: EdgeInsets.symmetric(
        horizontal: isWide ? 28 : 22,
        vertical: isWide ? 26 : 22,
      ),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.border),
      ),
      child: isWide
          ? Row(
              children: [
                Expanded(
                  child: _FooterBlock(
                    title: l10n.t('home_footer_title_brand'),
                    text: l10n.t('home_footer_text_brand'),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: _FooterBlock(
                    title: l10n.t('home_footer_title_branch'),
                    text: l10n.t('home_footer_text_branch'),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: _FooterBlock(
                    title: l10n.t('home_footer_title_next'),
                    text: l10n.t('home_footer_text_next'),
                  ),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _FooterBlock(
                  title: l10n.t('home_footer_title_brand'),
                  text: l10n.t('home_footer_text_brand'),
                ),
                const SizedBox(height: 18),
                _FooterBlock(
                  title: l10n.t('home_footer_title_branch'),
                  text: l10n.t('home_footer_text_branch'),
                ),
                const SizedBox(height: 18),
                _FooterBlock(
                  title: l10n.t('home_footer_title_next'),
                  text: l10n.t('home_footer_text_next'),
                ),
              ],
            ),
    );
  }
}

class _FooterBlock extends StatelessWidget {
  final String title;
  final String text;

  const _FooterBlock({
    required this.title,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: AppColors.brownDeep,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          text,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.65),
        ),
      ],
    );
  }
}

class _BranchSection extends StatelessWidget {
  final Future<List<BranchModel>> branchesFuture;
  final int? selectedBranchId;
  final ValueChanged<int?> onBranchSelected;
  final Future<void> Function() onRetry;
  final VoidCallback? onChangeBranch;

  const _BranchSection({
    required this.branchesFuture,
    required this.selectedBranchId,
    required this.onBranchSelected,
    required this.onRetry,
    this.onChangeBranch,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return FutureBuilder<List<BranchModel>>(
      future: branchesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _SectionLoading(height: 140);
        }

        if (snapshot.hasError) {
          return _SectionMessageCard(
            title: l10n.t('home_branches_error_title'),
            description: l10n.t('home_branches_error_desc'),
            actionLabel: l10n.t('common_retry'),
            onPressed: onRetry,
          );
        }

        final branches = <BranchModel>[
          for (final branch in snapshot.data ?? const <BranchModel>[])
            if (branch.id > 0 && branch.name.trim().isNotEmpty) branch,
        ];
        if (branches.isEmpty) {
          return _SectionMessageCard(
            title: l10n.t('home_branches_empty_title'),
            description: l10n.t('home_branches_empty_desc'),
            actionLabel: l10n.t('common_retry'),
            onPressed: onRetry,
          );
        }

        final branchOptions = <int, BranchModel>{
          for (final branch in branches) branch.id: branch,
        };
        final selectedBranch =
            branchOptions[selectedBranchId] ?? branches.first;

        return Card(
          margin: const EdgeInsets.fromLTRB(20, 4, 20, 8),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        color: AppColors.creamSoft,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child:
                          const Icon(Icons.storefront, color: AppColors.brown),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            selectedBranch.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColors.textDark,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            selectedBranch.city ??
                                l10n.t('home_branch_city_available'),
                            style: const TextStyle(color: AppColors.textMuted),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: onChangeBranch,
                      child: Text(l10n.t('home_change_branch')),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<int?>(
                  key: ValueKey<int>(selectedBranch.id),
                  initialValue: selectedBranch.id,
                  items: branchOptions.values
                      .map(
                        (branch) => DropdownMenuItem<int?>(
                          value: branch.id,
                          child: Text(branch.name),
                        ),
                      )
                      .toList(),
                  onChanged: onBranchSelected,
                  decoration: InputDecoration(
                    labelText: l10n.t('home_select_branch'),
                    filled: true,
                    fillColor: AppColors.cream,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DeliveryInfoSection extends StatelessWidget {
  final int? selectedBranchId;
  final Future<List<BranchModel>> branchesFuture;
  final Future<List<CmsPageModel>> deliveryBlocksFuture;
  final Future<SupportSettingsModel> supportSettingsFuture;
  final Future<void> Function() onRetry;

  const _DeliveryInfoSection({
    required this.selectedBranchId,
    required this.branchesFuture,
    required this.deliveryBlocksFuture,
    required this.supportSettingsFuture,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<BranchModel>>(
      future: branchesFuture,
      builder: (context, branchSnapshot) {
        return FutureBuilder<List<CmsPageModel>>(
          future: deliveryBlocksFuture,
          builder: (context, deliverySnapshot) {
            return FutureBuilder<SupportSettingsModel>(
              future: supportSettingsFuture,
              builder: (context, supportSnapshot) {
                if (branchSnapshot.connectionState == ConnectionState.waiting ||
                    deliverySnapshot.connectionState == ConnectionState.waiting ||
                    supportSnapshot.connectionState == ConnectionState.waiting) {
                  return const _SectionLoading(height: 180);
                }

                if (branchSnapshot.hasError ||
                    deliverySnapshot.hasError ||
                    supportSnapshot.hasError) {
                  return _SectionMessageCard(
                    title: 'Delivery information is unavailable',
                    description:
                        'Branch coverage and support details could not be loaded. Retry to refresh the latest service information.',
                    actionLabel: 'Retry',
                    onPressed: onRetry,
                  );
                }

                final branches = branchSnapshot.data ?? const <BranchModel>[];
                final deliveryBlocks =
                    deliverySnapshot.data ?? const <CmsPageModel>[];
                final settings =
                    supportSnapshot.data ?? const SupportSettingsModel();
                final selectedBranch =
                    _findBranchById(branches, selectedBranchId) ??
                        (branches.isNotEmpty ? branches.first : null);
                final deliveryBlock =
                    deliveryBlocks.isNotEmpty ? deliveryBlocks.first : null;

                return Container(
                  margin: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppColors.white, Color(0xFFFFFBF7)],
                    ),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppColors.border),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x102D1A12),
                        blurRadius: 16,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: AppColors.creamSoft,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(
                              Icons.local_shipping_outlined,
                              color: AppColors.brown,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              (deliveryBlock?.title ?? '').trim().isNotEmpty
                                  ? deliveryBlock!.title
                                  : context.l10n.t('home_delivery_information'),
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        selectedBranch == null
                            ? 'Select a branch to see branch-specific pickup and delivery availability.'
                            : _branchDeliverySummary(selectedBranch),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              height: 1.55,
                            ),
                      ),
                      if ((deliveryBlock?.excerpt ?? '').trim().isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(
                          deliveryBlock!.excerpt!,
                          style:
                              const TextStyle(color: AppColors.textMuted, height: 1.5),
                        ),
                      ],
                      if ((deliveryBlock?.body ?? '').trim().isNotEmpty) ...[
                        const SizedBox(height: 14),
                        Text(
                          deliveryBlock!.body!,
                          style:
                              const TextStyle(color: AppColors.textDark, height: 1.6),
                        ),
                      ],
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          if ((settings.contactPhone ?? '').trim().isNotEmpty)
                            _InfoPill(
                              icon: Icons.call_outlined,
                              label: settings.contactPhone!,
                            ),
                          if ((settings.whatsappNumber ?? '').trim().isNotEmpty)
                            _InfoPill(
                              icon: Icons.chat_bubble_outline,
                              label: (settings.whatsappLabel ?? '').trim().isNotEmpty
                                  ? '${settings.whatsappLabel} · ${settings.whatsappNumber}'
                                  : settings.whatsappNumber!,
                            ),
                          if ((settings.supportHours ?? '').trim().isNotEmpty)
                            _InfoPill(
                              icon: Icons.schedule_outlined,
                              label: settings.supportHours!,
                            ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  BranchModel? _findBranchById(List<BranchModel> branches, int? branchId) {
    if (branchId == null) {
      return null;
    }
    for (final branch in branches) {
      if (branch.id == branchId) {
        return branch;
      }
    }
    return null;
  }
}

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoPill({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.creamSoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: AppColors.brownDeep),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
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

class _SectionLoading extends StatelessWidget {
  final double height;

  const _SectionLoading({required this.height});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: const Center(child: CircularProgressIndicator()),
    );
  }
}

class _SectionMessageCard extends StatelessWidget {
  final String title;
  final String description;
  final String actionLabel;
  final VoidCallback? onPressed;

  const _SectionMessageCard({
    required this.title,
    required this.description,
    required this.actionLabel,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      padding: const EdgeInsets.all(20),
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
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 10),
          Text(description, style: const TextStyle(height: 1.45)),
          const SizedBox(height: 14),
          ElevatedButton(
            onPressed: onPressed,
            child: Text(actionLabel),
          ),
        ],
      ),
    );
  }
}

String _productSubtitle(ProductModel product, AppLocalizations l10n) {
  final source =
      '${product.name} ${product.description ?? ''} ${product.sku ?? ''}';
  final match = RegExp(
    r'(\d+\s?(?:g|kg|ml|l|pack))',
    caseSensitive: false,
  ).firstMatch(source);
  return match?.group(1) ?? l10n.t('product_standard_pack');
}

String _offerBadge(OfferModel offer) {
  if (offer.discountValue <= 0) {
    return 'Limited offer';
  }
  if ((offer.discountType ?? '').toLowerCase() == 'percentage') {
    return '${offer.discountValue.toStringAsFixed(0)}% off';
  }
  return 'Save SAR ${offer.discountValue.toStringAsFixed(0)}';
}

String _offerScope(OfferModel offer) {
  if (offer.branchId != null) {
    return 'Active in selected branch';
  }
  if (offer.categoryId != null) {
    return 'Active for a featured collection';
  }
  if (offer.productId != null) {
    return 'Active for a highlighted product';
  }
  return 'Available while this promotion is live';
}

String _branchDeliverySummary(BranchModel branch) {
  final deliveryLine = branch.deliveryAvailable
      ? 'Delivery available'
      : 'Delivery currently unavailable';
  final pickupLine =
      branch.pickupAvailable ? 'Pickup available' : 'Pickup currently unavailable';
  final coverage = (branch.deliveryCoverage ?? '').trim();
  if (coverage.isEmpty) {
    return '$deliveryLine. $pickupLine.';
  }
  return '$deliveryLine. $pickupLine. Coverage: $coverage.';
}
