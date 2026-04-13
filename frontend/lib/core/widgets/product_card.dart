import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../localization/app_localizations.dart';
import '../constants/app_colors.dart';
import 'premium_network_image.dart';

const double kProductCardImageHeight = 156;
const double kProductCardTitleHeight = 52;
const double kProductCardSubtitleHeight = 42;
const double kProductCardButtonHeight = 48;
const double kProductCardMainAxisExtent = 490;

class ProductCard extends StatefulWidget {
  final String name;
  final String subtitle;
  final String price;
  final String? imageUrl;
  final VoidCallback? onAddToCart;
  final VoidCallback? onTap;

  const ProductCard({
    super.key,
    required this.name,
    required this.subtitle,
    required this.price,
    this.imageUrl,
    this.onAddToCart,
    this.onTap,
  });

  @override
  State<ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<ProductCard> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final card = InkWell(
      borderRadius: BorderRadius.circular(30),
      onTap: widget.onTap,
      child: Ink(
        decoration: BoxDecoration(
          gradient: AppColors.surfaceGradient,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: AppColors.border),
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ProductVisual(imageUrl: widget.imageUrl),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceSoft,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: AppColors.borderStrong.withValues(alpha: 0.45)),
                    ),
                    child: Text(
                      context.l10n.t('brand_badge'),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppColors.secondary,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.9,
                          ),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    width: 34,
                    height: 34,
                    decoration: const BoxDecoration(
                      gradient: AppColors.goldGradient,
                      shape: BoxShape.circle,
                      boxShadow: AppColors.softShadow,
                    ),
                    child: const Icon(
                      Icons.arrow_outward_rounded,
                      size: 18,
                      color: AppColors.primaryDark,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: kProductCardTitleHeight,
                child: Align(
                  alignment: Alignment.topLeft,
                  child: Text(
                    widget.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              SizedBox(
                height: kProductCardSubtitleHeight,
                child: Align(
                  alignment: Alignment.topLeft,
                  child: Text(
                    widget.subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.bodyText,
                        ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.white.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.border.withValues(alpha: 0.9)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.price,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: AppColors.primaryDark,
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      context.l10n.t('currency_label'),
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: AppColors.secondary,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: kProductCardButtonHeight,
                child: ElevatedButton(
                  onPressed: widget.onAddToCart,
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size.fromHeight(kProductCardButtonHeight),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    backgroundColor: AppColors.primaryDark,
                    foregroundColor: AppColors.white,
                  ),
                  child: Text(context.l10n.t('product_add_to_cart')),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    final animated = AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      transform: Matrix4.translationValues(0, _hovering ? -6.0 : 0.0, 0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        boxShadow: _hovering ? AppColors.strongShadow : AppColors.panelShadow,
      ),
      child: card,
    );

    if (!kIsWeb) {
      return animated;
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: animated,
    );
  }
}

class _ProductVisual extends StatelessWidget {
  final String? imageUrl;

  const _ProductVisual({this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: kProductCardImageHeight,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: AppColors.softPanelGradient,
        border: Border.all(color: AppColors.border.withValues(alpha: 0.8)),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -16,
            top: -18,
            child: Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.accentGold.withValues(alpha: 0.12),
              ),
            ),
          ),
          PremiumNetworkImage(
            imageUrl: imageUrl,
            height: kProductCardImageHeight,
            borderRadius: BorderRadius.circular(22),
            fallbackIcon: Icons.diamond_outlined,
            fallbackIconSize: 22,
          ),
        ],
      ),
    );
  }
}
