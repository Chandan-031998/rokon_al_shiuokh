import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/extensions/localized_content.dart';
import '../../core/widgets/premium_network_image.dart';
import '../../localization/app_localizations.dart';
import '../../models/branch_model.dart';
import '../../models/product_model.dart';
import '../../models/wishlist_item_model.dart';
import '../../services/api_service.dart';
import '../products/product_details_page.dart';

class WishlistPage extends StatefulWidget {
  final ApiService apiService;

  const WishlistPage({
    super.key,
    required this.apiService,
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
    _wishlistFuture = widget.apiService.fetchWishlist();
    _branchesFuture = widget.apiService.fetchBranches();
  }

  void _reload() {
    setState(() {
      _wishlistFuture = widget.apiService.fetchWishlist();
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
        const SnackBar(content: Text('Removed from wishlist.')),
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
    return Scaffold(
      appBar: AppBar(title: const Text('Wishlist')),
      body: FutureBuilder<List<WishlistItemModel>>(
        future: _wishlistFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return _WishlistStateCard(
              title: 'Unable to load wishlist',
              description:
                  'The latest saved products could not be retrieved right now.',
              actionLabel: 'Retry',
              onPressed: _reload,
            );
          }

          final items = snapshot.data ?? const <WishlistItemModel>[];
          if (items.isEmpty) {
            return _WishlistStateCard(
              title: 'Your wishlist is empty',
              description:
                  'Tap the heart on any product to save it here for later.',
              actionLabel: 'Refresh',
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
                              product.shortDescription?.trim().isNotEmpty == true
                                  ? product.shortDescription!
                                  : (product.packSize?.trim().isNotEmpty == true
                                      ? 'Pack size: ${product.packSize}'
                                      : 'Saved for later'),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(color: AppColors.textMuted),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'SAR ${product.effectivePrice.toStringAsFixed(0)}',
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
                                  child: const Text('Add to cart'),
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
                                  label: const Text('Remove'),
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
