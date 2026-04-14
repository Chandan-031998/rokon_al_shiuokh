import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/extensions/localized_content.dart';
import '../../core/widgets/brand_logo.dart';
import '../../core/widgets/language_toggle.dart';
import '../../core/widgets/product_card.dart';
import '../../core/widgets/section_title.dart';
import '../../localization/app_locale_controller.dart';
import '../../localization/app_localizations.dart';
import '../../models/branch_model.dart';
import '../../models/category_model.dart';
import '../../models/product_model.dart';
import '../../services/api_service.dart';
import '../navigation/app_shell.dart';
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
  }

  Future<void> _refreshHomeContent() async {
    setState(() {
      widget.apiService.clearPublicCatalogCache();
      _categoriesFuture = widget.apiService.fetchCategories(forceRefresh: true);
      _featuredProductsFuture =
          widget.apiService.fetchFeaturedProducts(forceRefresh: true);
      _branchesFuture = widget.apiService.fetchBranches(forceRefresh: true);
    });
    try {
      await Future.wait([
        _categoriesFuture,
        _featuredProductsFuture,
        _branchesFuture,
      ]);
    } catch (_) {
      // Keep the current section-level error states instead of surfacing
      // refresh failures as uncaught exceptions in Flutter web.
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
                      onBrowseProducts: widget.onBrowseProducts,
                      onRetry: _refreshHomeContent,
                      isWide: isWide,
                    ),
                    KeyedSubtree(
                      key: _featuredKey,
                      child:
                          SectionTitle(title: l10n.t('home_featured_products')),
                    ),
                    _FeaturedSection(
                      featuredProductsFuture: _featuredProductsFuture,
                      onAddToCart: _handleAddToCart,
                      onRetry: _refreshHomeContent,
                    ),
                    KeyedSubtree(
                      key: _offersKey,
                      child: SectionTitle(title: l10n.t('home_special_offers')),
                    ),
                    _OffersPlaceholder(
                      isWide: isWide,
                      onBrowseProducts: widget.onBrowseProducts,
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
                    _DeliveryInfo(selectedBranchId: _selectedBranchId),
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
}

class _CategorySection extends StatelessWidget {
  final Future<List<CategoryModel>> categoriesFuture;
  final VoidCallback? onBrowseProducts;
  final Future<void> Function() onRetry;
  final bool isWide;

  const _CategorySection({
    required this.categoriesFuture,
    required this.onBrowseProducts,
    required this.onRetry,
    required this.isWide,
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
            actionLabel: l10n.t('common_browse_products'),
            onPressed: onBrowseProducts,
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
                  onTap: onBrowseProducts,
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
  final Future<void> Function() onRetry;

  const _FeaturedSection({
    required this.featuredProductsFuture,
    required this.onAddToCart,
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
                return ProductCard(
                  name: product.localizedName(l10n),
                  subtitle: _productSubtitle(product, l10n),
                  price: 'SAR ${product.price.toStringAsFixed(0)}',
                  imageUrl: product.imageUrl,
                  onAddToCart: () => onAddToCart(product),
                );
              },
            );
          },
        );
      },
    );
  }
}

class _OffersPlaceholder extends StatelessWidget {
  final bool isWide;
  final VoidCallback? onBrowseProducts;

  const _OffersPlaceholder({
    required this.isWide,
    this.onBrowseProducts,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      padding: EdgeInsets.all(isWide ? 28 : 22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF3A2419), AppColors.brownDeep, Color(0xFF7B5A3A)],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0x29FFFFFF)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F2D1A12),
            blurRadius: 22,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: isWide
          ? Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Icon(
                        Icons.local_offer_outlined,
                        color: AppColors.creamSoft,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          l10n.t('home_offers_placeholder'),
                          style: const TextStyle(
                            height: 1.65,
                            color: AppColors.creamSoft,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 18),
                FilledButton(
                  onPressed: onBrowseProducts,
                  child: Text(l10n.t('common_browse_products')),
                ),
              ],
            )
          : Row(
              children: [
                const Icon(Icons.local_offer_outlined,
                    color: AppColors.creamSoft),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    l10n.t('home_offers_placeholder'),
                    style: const TextStyle(
                      height: 1.55,
                      color: AppColors.creamSoft,
                    ),
                  ),
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

class _DeliveryInfo extends StatelessWidget {
  final int? selectedBranchId;

  const _DeliveryInfo({required this.selectedBranchId});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final branchMessage = selectedBranchId == null
        ? l10n.t('home_select_branch_prompt')
        : l10n.t('home_selected_branch_delivery');

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
                  l10n.t('home_delivery_information'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(branchMessage),
          const SizedBox(height: 10),
          Text(
            l10n.t('home_estimated_fulfilment'),
            style: const TextStyle(color: AppColors.textMuted, height: 1.45),
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
