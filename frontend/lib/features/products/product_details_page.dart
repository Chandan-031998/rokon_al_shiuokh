import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/extensions/localized_content.dart';
import '../../core/widgets/premium_network_image.dart';
import '../../localization/app_locale_controller.dart';
import '../../localization/app_localizations.dart';
import '../../models/branch_model.dart';
import '../../models/product_detail_model.dart';
import '../../models/product_image_model.dart';
import '../../models/product_model.dart';
import '../../models/review_model.dart';
import '../../services/api_service.dart';
import '../auth/login_page.dart';

String formatLocalizedPrice(
  ProductModel product,
  double amount, {
  required String regionCode,
  required String fallbackCurrencyCode,
}) {
  final currencyCode = product.currencyCodeForRegion(
    regionCode,
    fallback: fallbackCurrencyCode,
  );
  final normalized =
      amount % 1 == 0 ? amount.toStringAsFixed(0) : amount.toStringAsFixed(2);
  return '$currencyCode $normalized';
}

class ProductDetailsPage extends StatefulWidget {
  final ProductModel product;
  final List<BranchModel> branches;
  final ApiService apiService;
  final AppLocaleController localeController;

  const ProductDetailsPage({
    super.key,
    required this.product,
    required this.branches,
    required this.apiService,
    required this.localeController,
  });

  @override
  State<ProductDetailsPage> createState() => _ProductDetailsPageState();
}

class _ProductDetailsPageState extends State<ProductDetailsPage> {
  late int _quantity;
  int? _selectedBranchId;
  int _selectedImageIndex = 0;
  bool _isSubmitting = false;
  bool _isWishlistBusy = false;
  bool _isSubmittingReview = false;
  int _reviewRating = 5;
  final TextEditingController _reviewTitleController = TextEditingController();
  final TextEditingController _reviewBodyController = TextEditingController();
  late Future<_ProductDetailsViewData> _detailFuture;

  @override
  void initState() {
    super.initState();
    widget.localeController.addListener(_handleStorefrontChanged);
    _quantity = 1;
    _selectedBranchId = widget.product.branchId ??
        (widget.branches.isNotEmpty ? widget.branches.first.id : null);
    _detailFuture = _loadDetail();
  }

  @override
  void dispose() {
    widget.localeController.removeListener(_handleStorefrontChanged);
    _reviewTitleController.dispose();
    _reviewBodyController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ProductDetailsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.localeController != widget.localeController) {
      oldWidget.localeController.removeListener(_handleStorefrontChanged);
      widget.localeController.addListener(_handleStorefrontChanged);
      _handleStorefrontChanged();
    }
  }

  Future<_ProductDetailsViewData> _loadDetail() async {
    final responses = await Future.wait([
      widget.apiService.fetchProductDetail(
        widget.product.id,
        language: widget.localeController.languageCode,
        regionCode: widget.localeController.regionCode,
      ),
      widget.apiService.fetchProductReviews(widget.product.id),
    ]);
    final detail = responses[0] as ProductDetailModel;
    final reviews = responses[1] as List<ReviewModel>;
    return _ProductDetailsViewData(detail: detail, reviews: reviews);
  }

  void _handleStorefrontChanged() {
    if (!mounted) {
      return;
    }
    setState(() {
      _detailFuture = _loadDetail();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.product.localizedName(l10n)),
        actions: [
          ValueListenableBuilder<Set<int>>(
            valueListenable: ApiService.wishlistIdsListenable,
            builder: (context, wishlistIds, _) {
              final isFavorite = wishlistIds.contains(widget.product.id);
              return IconButton(
                onPressed:
                    _isWishlistBusy ? null : () => _toggleWishlist(isFavorite),
                tooltip:
                    isFavorite ? 'Remove from wishlist' : 'Save to wishlist',
                icon: Icon(
                  isFavorite
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  color: isFavorite
                      ? const Color(0xFFB4473B)
                      : AppColors.brownDeep,
                ),
              );
            },
          ),
        ],
      ),
      body: FutureBuilder<_ProductDetailsViewData>(
        future: _detailFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _StateScaffold(
              title: 'Unable to load this product',
              description:
                  'The latest product details could not be retrieved. Retry to refresh the gallery, branch availability, and customer reviews.',
              actionLabel: 'Retry',
              onPressed: () {
                setState(() {
                  _detailFuture = _loadDetail();
                });
              },
            );
          }

          final viewData = snapshot.data ??
              _ProductDetailsViewData(
                detail: ProductDetailModel(product: widget.product),
                reviews: const <ReviewModel>[],
              );
          final product = viewData.detail.product;
          final images = _resolvedImages(product);
          final safeSelectedIndex =
              _selectedImageIndex.clamp(0, images.length - 1);
          final selectedImage = images[safeSelectedIndex];
          final availableBranches = viewData.detail.availableBranches.isNotEmpty
              ? viewData.detail.availableBranches
              : widget.branches;
          final selectedBranch =
              _resolveSelectedBranch(availableBranches, _selectedBranchId);
          final description = _resolveDescription(product, l10n);
          final hasSale =
              product.salePrice != null && product.salePrice! < product.price;
          final effectivePrice = hasSale ? product.salePrice! : product.price;

          return LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 980;
              final horizontalPadding = isWide ? 28.0 : 20.0;
              final content = [
                _BreadcrumbLine(
                  title: product.localizedName(l10n),
                  branchName: product.branchName,
                ),
                const SizedBox(height: 18),
                isWide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 11,
                            child: _GalleryPanel(
                              images: images,
                              selectedImage: selectedImage,
                              selectedIndex: safeSelectedIndex,
                              onSelectImage: (index) {
                                setState(() => _selectedImageIndex = index);
                              },
                              semanticTitle: product.localizedName(l10n),
                            ),
                          ),
                          const SizedBox(width: 24),
                          Expanded(
                            flex: 9,
                            child: _PurchaseColumn(
                              product: product,
                              selectedBranchId: _selectedBranchId,
                              selectedBranch: selectedBranch,
                              availableBranches: availableBranches,
                              quantity: _quantity,
                              hasSale: hasSale,
                              effectivePrice: effectivePrice,
                              regionCode: widget.localeController.regionCode,
                              fallbackCurrencyCode:
                                  widget.localeController.currencyCode,
                              isSubmitting: _isSubmitting,
                              onBranchChanged: (value) {
                                setState(() => _selectedBranchId = value);
                              },
                              onDecrement: _quantity > 1
                                  ? () => setState(() => _quantity -= 1)
                                  : null,
                              onIncrement: () => setState(() => _quantity += 1),
                              onAddToCart: product.stockQty > 0
                                  ? () => _addToCart(product, selectedBranch)
                                  : null,
                              onToggleWishlist: () {
                                final isFavorite = ApiService
                                    .wishlistIdsListenable.value
                                    .contains(widget.product.id);
                                _toggleWishlist(isFavorite);
                              },
                            ),
                          ),
                        ],
                      )
                    : Column(
                        children: [
                          _GalleryPanel(
                            images: images,
                            selectedImage: selectedImage,
                            selectedIndex: safeSelectedIndex,
                            onSelectImage: (index) {
                              setState(() => _selectedImageIndex = index);
                            },
                            semanticTitle: product.localizedName(l10n),
                          ),
                          const SizedBox(height: 18),
                          _PurchaseColumn(
                            product: product,
                            selectedBranchId: _selectedBranchId,
                            selectedBranch: selectedBranch,
                            availableBranches: availableBranches,
                            quantity: _quantity,
                            hasSale: hasSale,
                            effectivePrice: effectivePrice,
                            regionCode: widget.localeController.regionCode,
                            fallbackCurrencyCode:
                                widget.localeController.currencyCode,
                            isSubmitting: _isSubmitting,
                            onBranchChanged: (value) {
                              setState(() => _selectedBranchId = value);
                            },
                            onDecrement: _quantity > 1
                                ? () => setState(() => _quantity -= 1)
                                : null,
                            onIncrement: () => setState(() => _quantity += 1),
                            onAddToCart: product.stockQty > 0
                                ? () => _addToCart(product, selectedBranch)
                                : null,
                            onToggleWishlist: () {
                              final isFavorite = ApiService
                                  .wishlistIdsListenable.value
                                  .contains(widget.product.id);
                              _toggleWishlist(isFavorite);
                            },
                          ),
                        ],
                      ),
                const SizedBox(height: 22),
                isWide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 11,
                            child: _DetailsStoryPanel(
                              product: product,
                              description: description,
                            ),
                          ),
                          const SizedBox(width: 24),
                          Expanded(
                            flex: 9,
                            child: _BranchAvailabilityPanel(
                              branch: selectedBranch,
                              branches: availableBranches,
                            ),
                          ),
                        ],
                      )
                    : Column(
                        children: [
                          _DetailsStoryPanel(
                            product: product,
                            description: description,
                          ),
                          const SizedBox(height: 18),
                          _BranchAvailabilityPanel(
                            branch: selectedBranch,
                            branches: availableBranches,
                          ),
                        ],
                      ),
                const SizedBox(height: 22),
                _ReviewsSection(
                  product: product,
                  reviews: viewData.reviews,
                  rating: _reviewRating,
                  titleController: _reviewTitleController,
                  bodyController: _reviewBodyController,
                  isSubmittingReview: _isSubmittingReview,
                  onRatingChanged: (value) {
                    setState(() => _reviewRating = value);
                  },
                  onSubmitReview: () => _submitReview(product),
                ),
                if (viewData.detail.relatedProducts.isNotEmpty) ...[
                  const SizedBox(height: 22),
                  _RelatedProductsSection(
                    products: viewData.detail.relatedProducts,
                    onProductSelected: (product) async {
                      await Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (_) => ProductDetailsPage(
                            product: product,
                            branches: widget.branches,
                            apiService: widget.apiService,
                            localeController: widget.localeController,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ];

              return ListView(
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  16,
                  horizontalPadding,
                  28,
                ),
                children: content,
              );
            },
          );
        },
      ),
    );
  }

  List<ProductImageModel> _resolvedImages(ProductModel product) {
    final images = <ProductImageModel>[
      ...product.images.where((image) => image.imageUrl.trim().isNotEmpty),
    ];
    if (images.isEmpty && (product.imageUrl ?? '').trim().isNotEmpty) {
      images.add(
        ProductImageModel(
          id: 0,
          imageUrl: product.imageUrl!,
          isPrimary: true,
        ),
      );
    }
    if (images.isEmpty) {
      images.add(
        const ProductImageModel(
          id: 0,
          imageUrl: '',
          isPrimary: true,
        ),
      );
    }
    return images;
  }

  BranchModel? _resolveSelectedBranch(
    List<BranchModel> branches,
    int? branchId,
  ) {
    if (branches.isEmpty) {
      return null;
    }
    for (final branch in branches) {
      if (branch.id == branchId) {
        return branch;
      }
    }
    return branches.first;
  }

  String _resolveDescription(ProductModel product, AppLocalizations l10n) {
    final candidates = <String?>[
      product.fullDescription,
      product.description,
      product.shortDescription,
    ];
    for (final candidate in candidates) {
      final trimmed = (candidate ?? '').trim();
      if (trimmed.isNotEmpty) {
        return trimmed;
      }
    }
    return l10n.t('product_default_description');
  }

  Future<bool> _ensureSignedIn() async {
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

  Future<void> _addToCart(ProductModel product, BranchModel? branch) async {
    setState(() => _isSubmitting = true);
    try {
      await widget.apiService.addToCart(
        productId: product.id,
        quantity: _quantity,
        branchId: branch?.id ?? _selectedBranchId,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Added $_quantity x ${product.localizedName(context.l10n)} from ${branch?.name ?? 'selected branch'}.',
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
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _toggleWishlist(bool isFavorite) async {
    if (!isFavorite && !await _ensureSignedIn()) {
      return;
    }

    setState(() => _isWishlistBusy = true);
    try {
      if (isFavorite) {
        await widget.apiService.removeWishlistItem(widget.product.id);
      } else {
        await widget.apiService.addWishlistItem(widget.product.id);
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
                    {'name': widget.product.localizedName(context.l10n)},
                  )
                : context.l10n.t(
                    'discovery_wishlist_saved',
                    {'name': widget.product.localizedName(context.l10n)},
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
    } finally {
      if (mounted) {
        setState(() => _isWishlistBusy = false);
      }
    }
  }

  Future<void> _submitReview(ProductModel product) async {
    if (!await _ensureSignedIn()) {
      return;
    }

    setState(() => _isSubmittingReview = true);
    try {
      await widget.apiService.submitReview(
        productId: product.id,
        rating: _reviewRating,
        title: _reviewTitleController.text,
        body: _reviewBodyController.text,
      );
      _reviewTitleController.clear();
      _reviewBodyController.clear();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Review submitted successfully and is pending moderation.',
          ),
        ),
      );
      setState(() {
        _reviewRating = 5;
        _detailFuture = _loadDetail();
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmittingReview = false);
      }
    }
  }
}

class _ProductDetailsViewData {
  final ProductDetailModel detail;
  final List<ReviewModel> reviews;

  const _ProductDetailsViewData({
    required this.detail,
    required this.reviews,
  });
}

class _BreadcrumbLine extends StatelessWidget {
  final String title;
  final String? branchName;

  const _BreadcrumbLine({
    required this.title,
    this.branchName,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          'Collections',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: AppColors.textMuted,
                fontWeight: FontWeight.w700,
              ),
        ),
        const Icon(Icons.chevron_right_rounded,
            size: 18, color: AppColors.bodyText),
        Text(
          title,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: AppColors.brownDeep,
                fontWeight: FontWeight.w800,
              ),
        ),
        if ((branchName ?? '').trim().isNotEmpty) ...[
          const Icon(Icons.chevron_right_rounded,
              size: 18, color: AppColors.bodyText),
          Text(
            branchName!,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AppColors.goldMuted,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ],
    );
  }
}

class _GalleryPanel extends StatelessWidget {
  final List<ProductImageModel> images;
  final ProductImageModel selectedImage;
  final int selectedIndex;
  final ValueChanged<int> onSelectImage;
  final String semanticTitle;

  const _GalleryPanel({
    required this.images,
    required this.selectedImage,
    required this.selectedIndex,
    required this.onSelectImage,
    required this.semanticTitle,
  });

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 980;
    return _LuxuryPanel(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            constraints: BoxConstraints(
              minHeight: isWide ? 520 : 320,
              maxHeight: isWide ? 620 : 420,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF3B1F14),
                  Color(0xFF6A3E28),
                  Color(0xFFB57F46)
                ],
              ),
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: PremiumNetworkImage(
                    imageUrl: selectedImage.imageUrl,
                    transformWidth: isWide ? 2000 : 1440,
                    transformQuality: 86,
                    borderRadius: BorderRadius.circular(28),
                    fit: BoxFit.cover,
                    fallbackIcon: Icons.shopping_bag_outlined,
                    fallbackIconSize: 56,
                    semanticLabel: semanticTitle,
                  ),
                ),
                Positioned(
                  left: 18,
                  top: 18,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.primaryDark.withValues(alpha: 0.74),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color:
                            AppColors.accentLightGold.withValues(alpha: 0.45),
                      ),
                    ),
                    child: Text(
                      images.length > 1
                          ? '${selectedIndex + 1} of ${images.length}'
                          : 'Gallery view',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: AppColors.white,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (images.length > 1) ...[
            const SizedBox(height: 14),
            SizedBox(
              height: 94,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: images.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final image = images[index];
                  final isSelected = index == selectedIndex;
                  return InkWell(
                    onTap: () => onSelectImage(index),
                    borderRadius: BorderRadius.circular(18),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 94,
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.accentGold
                              : AppColors.border,
                          width: isSelected ? 2 : 1,
                        ),
                        color: isSelected
                            ? AppColors.accentLightGold.withValues(alpha: 0.28)
                            : AppColors.surface,
                      ),
                      child: PremiumNetworkImage(
                        imageUrl: image.imageUrl,
                        transformWidth: 320,
                        transformQuality: 80,
                        borderRadius: BorderRadius.circular(14),
                        fit: BoxFit.cover,
                        fallbackIcon: Icons.image_outlined,
                        semanticLabel: '$semanticTitle thumbnail ${index + 1}',
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PurchaseColumn extends StatelessWidget {
  final ProductModel product;
  final int? selectedBranchId;
  final BranchModel? selectedBranch;
  final List<BranchModel> availableBranches;
  final int quantity;
  final bool hasSale;
  final double effectivePrice;
  final String regionCode;
  final String fallbackCurrencyCode;
  final bool isSubmitting;
  final ValueChanged<int?> onBranchChanged;
  final VoidCallback? onDecrement;
  final VoidCallback onIncrement;
  final VoidCallback? onAddToCart;
  final VoidCallback onToggleWishlist;

  const _PurchaseColumn({
    required this.product,
    required this.selectedBranchId,
    required this.selectedBranch,
    required this.availableBranches,
    required this.quantity,
    required this.hasSale,
    required this.effectivePrice,
    required this.regionCode,
    required this.fallbackCurrencyCode,
    required this.isSubmitting,
    required this.onBranchChanged,
    required this.onDecrement,
    required this.onIncrement,
    required this.onAddToCart,
    required this.onToggleWishlist,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final inStock = product.stockQty > 0;

    return Column(
      children: [
        _LuxuryPanel(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _ToneBadge(
                    label: inStock
                        ? context.l10n.t('product_in_stock')
                        : context.l10n.t('product_out_of_stock'),
                    backgroundColor: inStock
                        ? const Color(0xFFDDEDD8)
                        : const Color(0xFFF5DBD8),
                    foregroundColor: inStock
                        ? const Color(0xFF25583C)
                        : const Color(0xFF7C3028),
                  ),
                  if (product.isFeatured)
                    const _ToneBadge(
                      label: 'Featured',
                      backgroundColor: AppColors.accentLightGold,
                      foregroundColor: AppColors.primaryDark,
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                product.localizedName(l10n),
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      height: 1.02,
                    ),
              ),
              if ((product.nameAr ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  product.nameAr!,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.bodyText,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                      ),
                ),
              ],
              if ((product.shortDescription ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  product.shortDescription!,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppColors.textMuted,
                      ),
                ),
              ],
              const SizedBox(height: 18),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatLocalizedPrice(
                      product,
                      effectivePrice,
                      regionCode: regionCode,
                      fallbackCurrencyCode: fallbackCurrencyCode,
                    ),
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: AppColors.primaryDark,
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  if (hasSale) ...[
                    const SizedBox(width: 12),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        formatLocalizedPrice(
                          product,
                          product.price,
                          regionCode: regionCode,
                          fallbackCurrencyCode: fallbackCurrencyCode,
                        ),
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: AppColors.textMuted,
                                  decoration: TextDecoration.lineThrough,
                                ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _MetricPill(
                    icon: Icons.star_rounded,
                    label: '${product.averageRating.toStringAsFixed(1)} rating',
                  ),
                  _MetricPill(
                    icon: Icons.reviews_outlined,
                    label: '${product.reviewCount} reviews',
                  ),
                  if ((product.packSize ?? '').trim().isNotEmpty)
                    _MetricPill(
                      icon: Icons.scale_outlined,
                      label: product.packSize!,
                    ),
                  _MetricPill(
                    icon: Icons.inventory_2_outlined,
                    label: inStock
                        ? '${product.stockQty} units available'
                        : 'Currently unavailable',
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _LuxuryPanel(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Purchase options',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<int?>(
                initialValue: selectedBranchId,
                decoration: const InputDecoration(
                  labelText: 'Branch availability',
                ),
                items: availableBranches
                    .map(
                      (branch) => DropdownMenuItem<int?>(
                        value: branch.id,
                        child: Text(branch.name),
                      ),
                    )
                    .toList(),
                onChanged: onBranchChanged,
              ),
              if (selectedBranch != null) ...[
                const SizedBox(height: 14),
                _BranchSummaryTile(branch: selectedBranch!),
              ],
              const SizedBox(height: 14),
              _QuantityStrip(
                quantity: quantity,
                onDecrement: onDecrement,
                onIncrement: onIncrement,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: isSubmitting ? null : onAddToCart,
                      icon: isSubmitting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.shopping_bag_outlined),
                      label: Text(
                        inStock
                            ? l10n.t('product_add_to_cart')
                            : l10n.t('product_out_of_stock'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton(
                    onPressed: onToggleWishlist,
                    child: Text(l10n.t('account_wishlist_title')),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DetailsStoryPanel extends StatelessWidget {
  final ProductModel product;
  final String description;

  const _DetailsStoryPanel({
    required this.product,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return _LuxuryPanel(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Product overview',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  height: 1.7,
                ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              if ((product.sku ?? '').trim().isNotEmpty)
                _MetricPill(
                  icon: Icons.qr_code_2_outlined,
                  label: 'SKU ${product.sku}',
                ),
              if ((product.categoryName ?? '').trim().isNotEmpty)
                _MetricPill(
                  icon: Icons.category_outlined,
                  label: product.categoryName!,
                ),
              if ((product.tags ?? '').trim().isNotEmpty)
                _MetricPill(
                  icon: Icons.sell_outlined,
                  label: product.tags!,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BranchAvailabilityPanel extends StatelessWidget {
  final BranchModel? branch;
  final List<BranchModel> branches;

  const _BranchAvailabilityPanel({
    required this.branch,
    required this.branches,
  });

  @override
  Widget build(BuildContext context) {
    return _LuxuryPanel(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Branch availability',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 14),
          if (branch == null)
            Text(
              'No active branches are available for this product yet.',
              style: Theme.of(context).textTheme.bodyLarge,
            )
          else
            _BranchSummaryTile(branch: branch!),
          if (branches.length > 1) ...[
            const SizedBox(height: 16),
            Text(
              'Other branches',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 10),
            for (final item in branches.take(4))
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _BranchAvailabilityRow(branch: item),
              ),
          ],
        ],
      ),
    );
  }
}

class _BranchSummaryTile extends StatelessWidget {
  final BranchModel branch;

  const _BranchSummaryTile({
    required this.branch,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            branch.name,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            branch.productAvailable
                ? 'This product is currently available at this branch.'
                : 'This product is currently unavailable at this branch.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textMuted,
                  height: 1.5,
                ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _MetricPill(
                icon: Icons.shopping_bag_outlined,
                label: branch.pickupAvailable
                    ? 'Pickup available'
                    : 'Pickup unavailable',
              ),
              _MetricPill(
                icon: Icons.local_shipping_outlined,
                label: branch.deliveryAvailable
                    ? 'Delivery available'
                    : 'Delivery unavailable',
              ),
              if ((branch.deliveryCoverage ?? '').trim().isNotEmpty)
                _MetricPill(
                  icon: Icons.place_outlined,
                  label: branch.deliveryCoverage!,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BranchAvailabilityRow extends StatelessWidget {
  final BranchModel branch;

  const _BranchAvailabilityRow({
    required this.branch,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              branch.name,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ),
          _ToneBadge(
            label: branch.productAvailable ? 'Available' : 'Unavailable',
            backgroundColor: branch.productAvailable
                ? const Color(0xFFDDEDD8)
                : const Color(0xFFF5DBD8),
            foregroundColor: branch.productAvailable
                ? const Color(0xFF25583C)
                : const Color(0xFF7C3028),
          ),
        ],
      ),
    );
  }
}

class _QuantityStrip extends StatelessWidget {
  final int quantity;
  final VoidCallback? onDecrement;
  final VoidCallback onIncrement;

  const _QuantityStrip({
    required this.quantity,
    required this.onDecrement,
    required this.onIncrement,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Text(
            context.l10n.t('product_quantity'),
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const Spacer(),
          IconButton(
            onPressed: onDecrement,
            icon: const Icon(Icons.remove_circle_outline),
          ),
          Text(
            '$quantity',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          IconButton(
            onPressed: onIncrement,
            icon: const Icon(Icons.add_circle_outline),
          ),
        ],
      ),
    );
  }
}

class _ReviewsSection extends StatelessWidget {
  final ProductModel product;
  final List<ReviewModel> reviews;
  final int rating;
  final TextEditingController titleController;
  final TextEditingController bodyController;
  final bool isSubmittingReview;
  final ValueChanged<int> onRatingChanged;
  final VoidCallback onSubmitReview;

  const _ReviewsSection({
    required this.product,
    required this.reviews,
    required this.rating,
    required this.titleController,
    required this.bodyController,
    required this.isSubmittingReview,
    required this.onRatingChanged,
    required this.onSubmitReview,
  });

  @override
  Widget build(BuildContext context) {
    final distribution = product.ratingDistribution;
    return _LuxuryPanel(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Customer reviews',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final stacked = constraints.maxWidth < 860;
              final summary = _ReviewSummaryChart(
                averageRating: product.averageRating,
                reviewCount: product.reviewCount,
                distribution: distribution,
              );
              final composer = _ReviewComposerCard(
                rating: rating,
                titleController: titleController,
                bodyController: bodyController,
                isSubmittingReview: isSubmittingReview,
                onRatingChanged: onRatingChanged,
                onSubmitReview: onSubmitReview,
              );
              if (stacked) {
                return Column(
                  children: [
                    summary,
                    const SizedBox(height: 16),
                    composer,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: summary),
                  const SizedBox(width: 18),
                  Expanded(child: composer),
                ],
              );
            },
          ),
          const SizedBox(height: 18),
          if (reviews.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border),
              ),
              child: Text(
                context.l10n.t('product_reviews_empty'),
              ),
            )
          else
            Column(
              children: [
                for (final review in reviews.take(5)) ...[
                  _ReviewCard(review: review),
                  const SizedBox(height: 12),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

class _ReviewSummaryChart extends StatelessWidget {
  final double averageRating;
  final int reviewCount;
  final Map<String, int> distribution;

  const _ReviewSummaryChart({
    required this.averageRating,
    required this.reviewCount,
    required this.distribution,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${averageRating.toStringAsFixed(1)} / 5',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            '$reviewCount reviews',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textMuted,
                ),
          ),
          const SizedBox(height: 16),
          for (int star = 5; star >= 1; star--)
            Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: Row(
                children: [
                  SizedBox(
                    width: 32,
                    child: Text(
                      '$star★',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        minHeight: 9,
                        value: reviewCount == 0
                            ? 0
                            : (distribution['$star'] ?? 0) / reviewCount,
                        backgroundColor: AppColors.creamSoft,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          AppColors.accentGold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 20,
                    child: Text('${distribution['$star'] ?? 0}'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ReviewComposerCard extends StatelessWidget {
  final int rating;
  final TextEditingController titleController;
  final TextEditingController bodyController;
  final bool isSubmittingReview;
  final ValueChanged<int> onRatingChanged;
  final VoidCallback onSubmitReview;

  const _ReviewComposerCard({
    required this.rating,
    required this.titleController,
    required this.bodyController,
    required this.isSubmittingReview,
    required this.onRatingChanged,
    required this.onSubmitReview,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Write a review',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Signed-in customers can submit a product rating and review. New reviews appear publicly after moderation.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textMuted,
                  height: 1.5,
                ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 4,
            children: [
              for (int star = 1; star <= 5; star++)
                IconButton(
                  onPressed:
                      isSubmittingReview ? null : () => onRatingChanged(star),
                  icon: Icon(
                    star <= rating
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    color: AppColors.accentGold,
                    size: 30,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: titleController,
            enabled: !isSubmittingReview,
            decoration: const InputDecoration(
              labelText: 'Review title',
              hintText: 'Summarize your experience',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: bodyController,
            enabled: !isSubmittingReview,
            minLines: 4,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Your review',
              hintText:
                  'Share product quality, aroma, packaging, or service details.',
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: isSubmittingReview ? null : onSubmitReview,
            icon: isSubmittingReview
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.rate_review_outlined),
            label: Text(isSubmittingReview ? 'Submitting...' : 'Submit review'),
          ),
        ],
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final ReviewModel review;

  const _ReviewCard({
    required this.review,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '${review.rating}/5',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(width: 10),
              if (review.isVerifiedPurchase)
                const _MetricPill(
                  icon: Icons.verified_outlined,
                  label: 'Verified purchase',
                ),
            ],
          ),
          if ((review.title ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              review.title!,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: AppColors.brownDeep,
                  ),
            ),
          ],
          if ((review.body ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              review.body!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    height: 1.6,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RelatedProductsSection extends StatelessWidget {
  final List<ProductModel> products;
  final ValueChanged<ProductModel> onProductSelected;

  const _RelatedProductsSection({
    required this.products,
    required this.onProductSelected,
  });

  @override
  Widget build(BuildContext context) {
    return _LuxuryPanel(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Related products',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 270,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: products.length,
              separatorBuilder: (_, __) => const SizedBox(width: 14),
              itemBuilder: (context, index) {
                final product = products[index];
                return SizedBox(
                  width: 230,
                  child: InkWell(
                    onTap: () => onProductSelected(product),
                    borderRadius: BorderRadius.circular(24),
                    child: Ink(
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            PremiumNetworkImage(
                              imageUrl: product.imageUrl,
                              height: 150,
                              borderRadius: BorderRadius.circular(18),
                              fallbackIcon: Icons.shopping_bag_outlined,
                              semanticLabel: product.name,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              product.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.w900,
                                  ),
                            ),
                            const Spacer(),
                            Text(
                              'SAR ${product.effectivePrice.toStringAsFixed(0)}',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(
                                    color: AppColors.brownDeep,
                                    fontWeight: FontWeight.w900,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _LuxuryPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _LuxuryPanel({
    required this.child,
    this.padding = const EdgeInsets.all(20),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFFCF8), Color(0xFFF6ECDD)],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.panelShadow,
      ),
      child: child,
    );
  }
}

class _MetricPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MetricPill({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
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
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AppColors.brownDeep,
                  fontWeight: FontWeight.w800,
                ),
          ),
        ],
      ),
    );
  }
}

class _ToneBadge extends StatelessWidget {
  final String label;
  final Color backgroundColor;
  final Color foregroundColor;

  const _ToneBadge({
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: foregroundColor,
              fontWeight: FontWeight.w900,
            ),
      ),
    );
  }
}

class _StateScaffold extends StatelessWidget {
  final String title;
  final String description;
  final String actionLabel;
  final VoidCallback onPressed;

  const _StateScaffold({
    required this.title,
    required this.description,
    required this.actionLabel,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Semantics(
          liveRegion: true,
          label: '$title. $description',
          child: Container(
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 12),
                Text(description, style: const TextStyle(height: 1.55)),
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: onPressed,
                  child: Text(actionLabel),
                ),
              ],
            ),
          ),
        ),
      ),
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
