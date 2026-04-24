import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/extensions/localized_content.dart';
import '../../core/widgets/premium_network_image.dart';
import '../../localization/app_locale_controller.dart';
import '../../localization/app_localizations.dart';
import '../../models/branch_model.dart';
import '../../models/product_model.dart';
import '../../models/wishlist_item_model.dart';
import '../../services/api_service.dart';
import '../products/product_details_page.dart';

class WishlistPage extends StatefulWidget {
  final ApiService apiService;
  final AppLocaleController localeController;

  const WishlistPage({
    super.key,
    required this.apiService,
    required this.localeController,
  });

  @override
  State<WishlistPage> createState() => _WishlistPageState();
}

class _WishlistPageState extends State<WishlistPage> {
  late Future<List<WishlistItemModel>> _wishlistFuture;
  late Future<List<BranchModel>> _branchesFuture;
  int? _busyProductId;

  @override
  void initState() {
    super.initState();
    widget.localeController.addListener(_reload);
    _wishlistFuture = widget.apiService.fetchWishlist();
    _branchesFuture = widget.apiService.fetchBranches(
      regionCode: widget.localeController.regionCode,
    );
  }

  @override
  void didUpdateWidget(covariant WishlistPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.localeController != widget.localeController) {
      oldWidget.localeController.removeListener(_reload);
      widget.localeController.addListener(_reload);
      _reload();
    }
  }

  @override
  void dispose() {
    widget.localeController.removeListener(_reload);
    super.dispose();
  }

  void _reload() {
    setState(() {
      _wishlistFuture = widget.apiService.fetchWishlist();
      _branchesFuture = widget.apiService.fetchBranches(
        forceRefresh: true,
        regionCode: widget.localeController.regionCode,
      );
    });
  }

  Future<void> _remove(int productId) async {
    setState(() => _busyProductId = productId);
    try {
      await widget.apiService.removeWishlistItem(productId);
      if (!mounted) {
        return;
      }
      _reload();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.t('wishlist_removed_generic'))),
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
        setState(() => _busyProductId = null);
      }
    }
  }

  Future<void> _addToCart(ProductModel product) async {
    try {
      await widget.apiService.addToCart(
        productId: product.id,
        branchId: product.branchId,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Added ${product.name} to cart.')),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to add this product to cart.')),
      );
    }
  }

  Future<void> _openProduct(ProductModel product) async {
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
    if (!mounted) {
      return;
    }
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.t('account_wishlist_title'))),
      body: FutureBuilder<List<WishlistItemModel>>(
        future: _wishlistFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return _WishlistStateCard(
              title: l10n.t('wishlist_error_title'),
              description: l10n.t('wishlist_error_desc'),
              actionLabel: l10n.t('common_retry'),
              onPressed: _reload,
            );
          }

          final items = snapshot.data ?? const <WishlistItemModel>[];
          if (items.isEmpty) {
            return _WishlistStateCard(
              title: l10n.t('wishlist_empty_title'),
              description: l10n.t('wishlist_empty_desc'),
              actionLabel: l10n.t('common_refresh'),
              onPressed: _reload,
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 14),
            itemBuilder: (context, index) {
              final item = items[index];
              final product = item.product;
              if (product == null) {
                return const SizedBox.shrink();
              }
              return InkWell(
                onTap: () => _openProduct(product),
                borderRadius: BorderRadius.circular(24),
                child: Ink(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 92,
                        height: 92,
                        child: PremiumNetworkImage(
                          imageUrl: product.imageUrl,
                          borderRadius: BorderRadius.circular(18),
                          fallbackIcon: Icons.favorite_border_rounded,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              product.localizedName(context.l10n),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              product.shortDescription?.trim().isNotEmpty ==
                                      true
                                  ? product.shortDescription!
                                  : (product.packSize?.trim().isNotEmpty == true
                                      ? '${l10n.t('product_pack_size_prefix')}: ${product.packSize}'
                                      : l10n.t('wishlist_saved_for_later')),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(color: AppColors.textMuted),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              '${product.currencyCodeForRegion(widget.localeController.regionCode, fallback: widget.localeController.currencyCode)} ${product.effectivePrice.toStringAsFixed(0)}',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    color: AppColors.brownDeep,
                                    fontWeight: FontWeight.w900,
                                  ),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                FilledButton(
                                  onPressed: product.stockQty > 0
                                      ? () => _addToCart(product)
                                      : null,
                                  child: Text(l10n.t('common_add_to_cart')),
                                ),
                                OutlinedButton.icon(
                                  onPressed: _busyProductId == product.id
                                      ? null
                                      : () => _remove(product.id),
                                  icon: _busyProductId == product.id
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(Icons.favorite_rounded),
                                  label: Text(l10n.t('common_remove')),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _WishlistStateCard extends StatelessWidget {
  final String title;
  final String description;
  final String actionLabel;
  final VoidCallback onPressed;

  const _WishlistStateCard({
    required this.title,
    required this.description,
    required this.actionLabel,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Semantics(
          liveRegion: true,
          label: '$title. $description',
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(26),
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
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        height: 1.6,
                      ),
                ),
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
