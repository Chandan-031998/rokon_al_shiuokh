import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/extensions/localized_content.dart';
import '../../core/widgets/premium_network_image.dart';
import '../../localization/app_localizations.dart';
import '../../models/branch_model.dart';
import '../../models/product_detail_model.dart';
import '../../models/product_model.dart';
import '../../models/review_model.dart';
import '../../services/api_service.dart';
import '../auth/login_page.dart';

class ProductDetailsPage extends StatefulWidget {
  final ProductModel product;
  final List<BranchModel> branches;
  final ApiService apiService;

  const ProductDetailsPage({
    super.key,
    required this.product,
    required this.branches,
    required this.apiService,
  });

  @override
  State<ProductDetailsPage> createState() => _ProductDetailsPageState();
}

class _ProductDetailsPageState extends State<ProductDetailsPage> {
  late int _quantity;
  int? _selectedBranchId;
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
    _quantity = 1;
    _selectedBranchId = widget.product.branchId ??
        (widget.branches.isNotEmpty ? widget.branches.first.id : null);
    _detailFuture = _loadDetail();
  }

  @override
  void dispose() {
    _reviewTitleController.dispose();
    _reviewBodyController.dispose();
    super.dispose();
  }

  Future<_ProductDetailsViewData> _loadDetail() async {
    final responses = await Future.wait([
      widget.apiService.fetchProductDetail(widget.product.id),
      widget.apiService.fetchProductReviews(widget.product.id),
    ]);
    final detail = responses[0] as ProductDetailModel;
    final reviews = responses[1] as List<ReviewModel>;
    return _ProductDetailsViewData(detail: detail, reviews: reviews);
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
                tooltip: isFavorite ? 'Remove from wishlist' : 'Save to wishlist',
                icon: Icon(
                  isFavorite
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  color:
                      isFavorite ? const Color(0xFFB4473B) : AppColors.brownDeep,
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
                  'The latest product details could not be retrieved. Retry to refresh the full description, branch availability, and reviews.',
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
          final availableBranches = viewData.detail.availableBranches.isNotEmpty
              ? viewData.detail.availableBranches
              : widget.branches;
          final selectedBranch =
              _resolveSelectedBranch(availableBranches, _selectedBranchId);
          final description = _resolveDescription(product, l10n);

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            children: [
              _DetailsVisual(imageUrl: product.imageUrl),
              const SizedBox(height: 18),
              Text(
                product.localizedName(l10n),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 10),
              _PriceBlock(product: product),
              const SizedBox(height: 14),
              _RatingSummaryCard(product: product),
              const SizedBox(height: 12),
              _InfoPanel(
                title: 'Product overview',
                icon: Icons.inventory_2_outlined,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if ((product.shortDescription ?? '').trim().isNotEmpty) ...[
                      Text(
                        product.shortDescription!,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.brownDeep,
                            ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    Text(
                      description,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            height: 1.6,
                          ),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        if ((product.packSize ?? '').trim().isNotEmpty)
                          _InfoPill(
                            icon: Icons.scale_outlined,
                            label: 'Pack size: ${product.packSize}',
                          ),
                        if ((product.sku ?? '').trim().isNotEmpty)
                          _InfoPill(
                            icon: Icons.qr_code_2_outlined,
                            label: 'SKU: ${product.sku}',
                          ),
                        _InfoPill(
                          icon: Icons.inventory_outlined,
                          label: product.stockQty > 0
                              ? '${product.stockQty} units available'
                              : 'Currently out of stock',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _InfoPanel(
                title: 'Branch availability',
                icon: Icons.storefront_outlined,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButtonFormField<int?>(
                      initialValue: selectedBranch?.id,
                      items: availableBranches
                          .map(
                            (branch) => DropdownMenuItem<int?>(
                              value: branch.id,
                              child: Text(branch.name),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        setState(() => _selectedBranchId = value);
                      },
                      decoration: const InputDecoration(
                        labelText: 'Choose branch',
                      ),
                    ),
                    if (selectedBranch != null) ...[
                      const SizedBox(height: 14),
                      _BranchAvailabilityCard(branch: selectedBranch),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _QuantitySelector(
                quantity: _quantity,
                onDecrement:
                    _quantity > 1 ? () => setState(() => _quantity -= 1) : null,
                onIncrement: () => setState(() => _quantity += 1),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: product.stockQty > 0 && !_isSubmitting
                    ? () => _addToCart(product, selectedBranch)
                    : null,
                child: Text(product.stockQty > 0
                    ? l10n.t('product_add_to_cart')
                    : 'Out of stock'),
              ),
              const SizedBox(height: 24),
              _ReviewsSection(
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
                const SizedBox(height: 24),
                _RelatedProductsSection(
                  products: viewData.detail.relatedProducts,
                  onProductSelected: (product) async {
                    await Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (_) => ProductDetailsPage(
                          product: product,
                          branches: widget.branches,
                          apiService: widget.apiService,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ],
          );
        },
      ),
    );
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
                ? 'Removed ${widget.product.localizedName(context.l10n)} from wishlist.'
                : 'Saved ${widget.product.localizedName(context.l10n)} to wishlist.',
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

class _DetailsVisual extends StatelessWidget {
  final String? imageUrl;

  const _DetailsVisual({this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return PremiumNetworkImage(
      imageUrl: imageUrl,
      height: 280,
      borderRadius: BorderRadius.circular(28),
      fallbackIcon: Icons.shopping_bag_outlined,
      fallbackIconSize: 48,
      semanticLabel: 'Product image',
    );
  }
}

class _PriceBlock extends StatelessWidget {
  final ProductModel product;

  const _PriceBlock({required this.product});

  @override
  Widget build(BuildContext context) {
    final hasSale = product.salePrice != null && product.salePrice! < product.price;
    final effectivePrice = hasSale ? product.salePrice! : product.price;

    return Row(
      children: [
        Text(
          'SAR ${effectivePrice.toStringAsFixed(0)}',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: AppColors.brownDeep,
                fontWeight: FontWeight.w900,
              ),
        ),
        if (hasSale) ...[
          const SizedBox(width: 12),
          Text(
            'SAR ${product.price.toStringAsFixed(0)}',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.textMuted,
                  decoration: TextDecoration.lineThrough,
                ),
          ),
        ],
      ],
    );
  }
}

class _RatingSummaryCard extends StatelessWidget {
  final ProductModel product;

  const _RatingSummaryCard({required this.product});

  @override
  Widget build(BuildContext context) {
    final distribution = product.ratingDistribution;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.star_rounded, color: AppColors.accentGold),
              const SizedBox(width: 8),
              Text(
                '${product.averageRating.toStringAsFixed(1)} average rating',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const Spacer(),
              Text(
                '${product.reviewCount} reviews',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textMuted,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (int star = 5; star >= 1; star--)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 36,
                    child: Text(
                      '$star★',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        minHeight: 8,
                        value: product.reviewCount == 0
                            ? 0
                            : (distribution['$star'] ?? 0) / product.reviewCount,
                        backgroundColor: AppColors.creamSoft,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          AppColors.accentGold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text('${distribution['$star'] ?? 0}'),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _InfoPanel extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _InfoPanel({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.creamSoft,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: AppColors.brown),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.brownDeep,
                      ),
                ),
                const SizedBox(height: 12),
                child,
              ],
            ),
          ),
        ],
      ),
    );
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.creamSoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.brownDeep),
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

class _BranchAvailabilityCard extends StatelessWidget {
  final BranchModel branch;

  const _BranchAvailabilityCard({required this.branch});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            branch.name,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            branch.productAvailable
                ? 'This product is available at this branch.'
                : 'This product is not currently available at this branch.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  height: 1.5,
                ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _InfoPill(
                icon: Icons.shopping_bag_outlined,
                label: branch.pickupAvailable ? 'Pickup available' : 'Pickup unavailable',
              ),
              _InfoPill(
                icon: Icons.local_shipping_outlined,
                label: branch.deliveryAvailable
                    ? 'Delivery available'
                    : 'Delivery unavailable',
              ),
              if ((branch.deliveryCoverage ?? '').trim().isNotEmpty)
                _InfoPill(
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

class _QuantitySelector extends StatelessWidget {
  final int quantity;
  final VoidCallback? onDecrement;
  final VoidCallback onIncrement;

  const _QuantitySelector({
    required this.quantity,
    required this.onDecrement,
    required this.onIncrement,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Text(
            context.l10n.t('product_quantity'),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const Spacer(),
          IconButton(
            onPressed: onDecrement,
            tooltip: 'Decrease quantity',
            icon: const Icon(Icons.remove_circle_outline),
          ),
          Text(
            '$quantity',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          IconButton(
            onPressed: onIncrement,
            tooltip: 'Increase quantity',
            icon: const Icon(Icons.add_circle_outline),
          ),
        ],
      ),
    );
  }
}

class _ReviewsSection extends StatelessWidget {
  final List<ReviewModel> reviews;
  final int rating;
  final TextEditingController titleController;
  final TextEditingController bodyController;
  final bool isSubmittingReview;
  final ValueChanged<int> onRatingChanged;
  final VoidCallback onSubmitReview;

  const _ReviewsSection({
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Customer reviews',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 14),
        _ReviewComposerCard(
          rating: rating,
          titleController: titleController,
          bodyController: bodyController,
          isSubmittingReview: isSubmittingReview,
          onRatingChanged: onRatingChanged,
          onSubmitReview: onSubmitReview,
        ),
        const SizedBox(height: 14),
        if (reviews.isEmpty)
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppColors.border),
            ),
            child: const Text(
              'Approved customer reviews will appear here once moderation is complete.',
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
        color: AppColors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Write a review',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.brownDeep,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Signed-in customers can submit a product rating and review. New reviews appear publicly after moderation.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  height: 1.5,
                  color: AppColors.textMuted,
                ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              for (int star = 1; star <= 5; star++)
                IconButton(
                  onPressed: isSubmittingReview
                      ? null
                      : () => onRatingChanged(star),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: Icon(
                    star <= rating
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    color: AppColors.accentGold,
                    size: 30,
                  ),
                ),
              const SizedBox(width: 10),
              Text(
                '$rating/5',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: titleController,
            enabled: !isSubmittingReview,
            textInputAction: TextInputAction.next,
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
              hintText: 'Share product quality, aroma, packaging, or service details.',
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

  const _ReviewCard({required this.review});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(22),
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
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(width: 8),
              if (review.isVerifiedPurchase)
                const _InfoPill(
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
                    fontWeight: FontWeight.w800,
                    color: AppColors.brownDeep,
                  ),
            ),
          ],
          if ((review.body ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              review.body!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    height: 1.55,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Related products',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 250,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: products.length,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (context, index) {
              final product = products[index];
              return SizedBox(
                width: 220,
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
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          PremiumNetworkImage(
                            imageUrl: product.imageUrl,
                            height: 120,
                            borderRadius: BorderRadius.circular(18),
                            fallbackIcon: Icons.shopping_bag_outlined,
                            semanticLabel: product.name,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            product.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style:
                                Theme.of(context).textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w800,
                                    ),
                          ),
                          const Spacer(),
                          Text(
                            'SAR ${product.price.toStringAsFixed(0)}',
                            style:
                                Theme.of(context).textTheme.titleSmall?.copyWith(
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
