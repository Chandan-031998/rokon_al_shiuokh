import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../../localization/app_localizations.dart';
import 'premium_network_image.dart';

const double kProductCardMainAxisExtent = 508;

class ProductCard extends StatefulWidget {
  final String name;
  final String? arabicTitle;
  final String? subtitle;
  final String price;
  final String? originalPrice;
  final String? imageUrl;
  final String? branchLabel;
  final double averageRating;
  final int reviewCount;
  final bool isFeatured;
  final int stockQty;
  final VoidCallback? onAddToCart;
  final VoidCallback? onTap;
  final bool isFavorite;
  final VoidCallback? onFavoriteToggle;
  final bool showWishlistPlaceholder;

  const ProductCard({
    super.key,
    required this.name,
    required this.price,
    this.arabicTitle,
    this.subtitle,
    this.originalPrice,
    this.imageUrl,
    this.branchLabel,
    this.averageRating = 0,
    this.reviewCount = 0,
    this.isFeatured = false,
    this.stockQty = 0,
    this.onAddToCart,
    this.onTap,
    this.isFavorite = false,
    this.onFavoriteToggle,
    this.showWishlistPlaceholder = false,
  });

  @override
  State<ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<ProductCard> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final hasOriginalPrice = (widget.originalPrice ?? '').trim().isNotEmpty &&
        widget.originalPrice != widget.price;
    final inStock = widget.stockQty > 0;
    final card = Semantics(
      button: widget.onTap != null,
      label:
          '${widget.name}. ${widget.subtitle ?? widget.arabicTitle ?? ''}. ${widget.price}.',
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: widget.onTap,
        child: Ink(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFFFFCF8), Color(0xFFF7EEE2)],
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: AppColors.border),
            boxShadow:
                _hovering ? AppColors.strongShadow : AppColors.panelShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _CardImageRail(
                imageUrl: widget.imageUrl,
                semanticLabel: widget.name,
                isFeatured: widget.isFeatured,
                inStock: inStock,
                hasSale: hasOriginalPrice,
                isFavorite: widget.isFavorite,
                onFavoriteToggle: widget.onFavoriteToggle,
                showWishlistPlaceholder: widget.showWishlistPlaceholder,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  height: 1.08,
                                ),
                      ),
                      if ((widget.arabicTitle ?? '').trim().isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          widget.arabicTitle!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: AppColors.bodyText,
                                    height: 1.35,
                                  ),
                        ),
                      ],
                      if ((widget.subtitle ?? '').trim().isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          widget.subtitle!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppColors.textMuted,
                                    height: 1.45,
                                  ),
                        ),
                      ],
                      const Spacer(),
                      if ((widget.branchLabel ?? '').trim().isNotEmpty) ...[
                        _CardInfoChip(
                          icon: Icons.storefront_outlined,
                          label: widget.branchLabel!,
                        ),
                        const SizedBox(height: 10),
                      ],
                      Row(
                        children: [
                          Expanded(
                            child: _CardInfoChip(
                              icon: Icons.star_rounded,
                              label:
                                  '${widget.averageRating.toStringAsFixed(1)} · ${widget.reviewCount} ${context.l10n.t('product_reviews_label')}',
                            ),
                          ),
                          if (widget.isFeatured) ...[
                            const SizedBox(width: 8),
                            _MicroBadge(
                              label: context.l10n.t('product_featured_badge'),
                              foregroundColor: AppColors.primaryDark,
                              backgroundColor: AppColors.accentLightGold,
                            ),
                          ],
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
                                  widget.price,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleLarge
                                      ?.copyWith(
                                        color: AppColors.primaryDark,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: -0.3,
                                      ),
                                ),
                                if (hasOriginalPrice)
                                  Text(
                                    widget.originalPrice!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          color: AppColors.textMuted,
                                          decoration:
                                              TextDecoration.lineThrough,
                                        ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          SizedBox(
                            height: 46,
                            child: FilledButton.icon(
                              onPressed: inStock ? widget.onAddToCart : null,
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                minimumSize: const Size(0, 46),
                              ),
                              icon: const Icon(Icons.add_shopping_cart_outlined,
                                  size: 18),
                              label: Text(context.l10n.t('common_add_to_cart')),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (!kIsWeb) {
      return card;
    }
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: card,
    );
  }
}

class _CardImageRail extends StatelessWidget {
  final String? imageUrl;
  final String semanticLabel;
  final bool isFeatured;
  final bool inStock;
  final bool hasSale;
  final bool isFavorite;
  final VoidCallback? onFavoriteToggle;
  final bool showWishlistPlaceholder;

  const _CardImageRail({
    required this.imageUrl,
    required this.semanticLabel,
    required this.isFeatured,
    required this.inStock,
    required this.hasSale,
    required this.isFavorite,
    required this.onFavoriteToggle,
    required this.showWishlistPlaceholder,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final imageRailHeight = screenWidth >= 1024
        ? 256.0
        : screenWidth >= 640
            ? 224.0
            : 192.0;
    const imageBorderRadius = BorderRadius.vertical(top: Radius.circular(28));
    return SizedBox(
      height: imageRailHeight,
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: imageBorderRadius,
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF3A2218),
                      Color(0xFF7A4A2A),
                      Color(0xFFC89B5A)
                    ],
                  ),
                ),
                child: SizedBox.expand(
                  child: PremiumNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.high,
                    borderRadius: imageBorderRadius,
                    fallbackIcon: Icons.shopping_bag_outlined,
                    semanticLabel: semanticLabel,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 14,
            top: 14,
            child: _MicroBadge(
              label: inStock
                  ? context.l10n.t('product_in_stock')
                  : context.l10n.t('product_out_of_stock'),
              backgroundColor:
                  inStock ? const Color(0xE5E0F0DA) : const Color(0xE8F7D8D3),
              foregroundColor:
                  inStock ? const Color(0xFF23563A) : const Color(0xFF7B2E25),
            ),
          ),
          if (hasSale)
            Positioned(
              left: 14,
              top: 54,
              child: _MicroBadge(
                label: context.l10n.t('product_sale_badge'),
                backgroundColor: const Color(0xFFECC7C0),
                foregroundColor: const Color(0xFF8A2E22),
              ),
            ),
          if (onFavoriteToggle != null || showWishlistPlaceholder)
            Positioned(
              right: 14,
              top: 14,
              child: Material(
                color: AppColors.white.withValues(alpha: 0.94),
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onFavoriteToggle,
                  child: SizedBox(
                    width: 42,
                    height: 42,
                    child: Icon(
                      isFavorite
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      color: isFavorite
                          ? const Color(0xFFB4473B)
                          : AppColors.primaryDark,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ),
          Positioned(
            left: 14,
            bottom: 14,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.primaryDark.withValues(alpha: 0.74),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: AppColors.accentLightGold.withValues(alpha: 0.42),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.auto_awesome_rounded,
                    size: 14,
                    color: AppColors.accentLightGold,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isFeatured
                        ? context.l10n.t('product_signature_pick')
                        : context.l10n.t('product_collection_badge'),
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: AppColors.white,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CardInfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _CardInfoChip({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: AppColors.brownDeep),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
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

class _MicroBadge extends StatelessWidget {
  final String label;
  final Color backgroundColor;
  final Color foregroundColor;

  const _MicroBadge({
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: foregroundColor,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
      ),
    );
  }
}
