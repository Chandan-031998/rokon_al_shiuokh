import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/extensions/localized_content.dart';
import '../../localization/app_locale_controller.dart';
import '../../localization/app_localizations.dart';
import '../../models/category_model.dart';
import '../../services/api_service.dart';
import '../navigation/app_shell.dart';
import '../products/product_list_page.dart';

class CategoriesPage extends StatefulWidget {
  final VoidCallback onOpenCart;
  final VoidCallback onOpenAccount;
  final ApiService apiService;
  final AppLocaleController localeController;
  final bool showAppBar;

  const CategoriesPage({
    super.key,
    required this.onOpenCart,
    required this.onOpenAccount,
    this.apiService = const ApiService(),
    required this.localeController,
    this.showAppBar = true,
  });

  @override
  State<CategoriesPage> createState() => _CategoriesPageState();
}

class _CategoriesPageState extends State<CategoriesPage> {
  late Future<List<CategoryModel>> _categoriesFuture;

  @override
  void initState() {
    super.initState();
    widget.localeController.addListener(_handleStorefrontChanged);
    _categoriesFuture = _loadCategories();
  }

  @override
  void didUpdateWidget(covariant CategoriesPage oldWidget) {
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
    super.dispose();
  }

  Future<List<CategoryModel>> _loadCategories() {
    return widget.apiService.fetchCategories(
      language: widget.localeController.languageCode,
      forceRefresh: true,
    );
  }

  void _handleStorefrontChanged() {
    if (!mounted) {
      return;
    }
    setState(() {
      _categoriesFuture = _loadCategories();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return TabScreenTemplate(
      eyebrow: l10n.t('categories_eyebrow'),
      title: l10n.t('categories_title'),
      subtitle: l10n.t('categories_subtitle'),
      icon: Icons.grid_view_rounded,
      showAppBar: widget.showAppBar,
      localeController: widget.localeController,
      sections: [
        FutureBuilder<List<CategoryModel>>(
          future: _categoriesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.all(42),
                child: Center(child: CircularProgressIndicator()),
              );
            }

            if (snapshot.hasError) {
              return ActionPanel(
                title: l10n.t('home_categories_error_title'),
                description: l10n.t('home_categories_error_desc'),
                actionLabel: l10n.t('common_retry'),
                onPressed: _handleStorefrontChanged,
                icon: Icons.inventory_2_outlined,
              );
            }

            final categories = snapshot.data ?? const <CategoryModel>[];
            if (categories.isEmpty) {
              return ActionPanel(
                title: l10n.t('categories_empty_title'),
                description: l10n.t('categories_empty_desc'),
                actionLabel: l10n.t('common_open_account'),
                onPressed: widget.onOpenAccount,
                icon: Icons.inventory_2_outlined,
              );
            }

            return LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final crossAxisCount = width >= 1080
                    ? 4
                    : width >= 900
                        ? 3
                        : width >= 600
                            ? 2
                            : 1;

                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: 18,
                    mainAxisSpacing: 18,
                    mainAxisExtent: width >= 1080
                        ? 352
                        : width >= 900
                            ? 358
                            : width >= 600
                                ? 340
                                : width >= 380
                                    ? 336
                                    : 352,
                  ),
                  itemCount: categories.length,
                  itemBuilder: (context, index) {
                    final category = categories[index];
                    return _CategoryCard(
                      category: category,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ProductListPage(
                              category: category,
                              apiService: widget.apiService,
                              localeController: widget.localeController,
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
        ),
        ActionPanel(
          title: l10n.t('categories_continue_cart_title'),
          description: l10n.t('categories_continue_cart_desc'),
          actionLabel: l10n.t('common_open_cart'),
          onPressed: widget.onOpenCart,
          icon: Icons.shopping_bag_outlined,
        ),
        ActionPanel(
          title: l10n.t('categories_preferences_title'),
          description: l10n.t('categories_preferences_desc'),
          actionLabel: l10n.t('common_open_account'),
          onPressed: widget.onOpenAccount,
          icon: Icons.person_outline,
        ),
      ],
    );
  }
}

class _CategoryCard extends StatefulWidget {
  final CategoryModel category;
  final VoidCallback onTap;

  const _CategoryCard({
    required this.category,
    required this.onTap,
  });

  @override
  State<_CategoryCard> createState() => _CategoryCardState();
}

class _CategoryCardState extends State<_CategoryCard> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 380;
        final cardPadding = isCompact ? 16.0 : 20.0;
        final visualHeight = isCompact ? 104.0 : 118.0;
        final visualIconSize = isCompact ? 38.0 : 42.0;
        final badgeVertical = isCompact ? 5.0 : 6.0;
        final sectionGap = isCompact ? 14.0 : 18.0;
        final titleGap = isCompact ? 10.0 : 12.0;
        final titleHeight = isCompact ? 46.0 : 52.0;
        final footerGap = isCompact ? 12.0 : 16.0;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          transform: Matrix4.translationValues(0, _hovering ? -4.0 : 0.0, 0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: const Color(0x122D1A12),
                blurRadius: _hovering ? 22 : 16,
                offset: Offset(0, _hovering ? 14 : 10),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: widget.onTap,
              onHover: (hovering) => setState(() => _hovering = hovering),
              child: Ink(
                decoration: BoxDecoration(
                  gradient: AppColors.surfaceGradient,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.border),
                ),
                child: Padding(
                  padding: EdgeInsets.all(cardPadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _CategoryVisual(
                        category: widget.category,
                        height: visualHeight,
                        iconSize: visualIconSize,
                      ),
                      SizedBox(height: sectionGap),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: badgeVertical,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceSoft,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color:
                                AppColors.borderStrong.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Text(
                          'ROKON AL SHIOUKH',
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: AppColors.brown,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.7,
                                  ),
                        ),
                      ),
                      SizedBox(height: titleGap),
                      SizedBox(
                        height: titleHeight,
                        child: Align(
                          alignment: Alignment.topLeft,
                          child: Text(
                            widget.category.localizedName(context.l10n),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  height: isCompact ? 1.1 : null,
                                ),
                          ),
                        ),
                      ),
                      const Spacer(),
                      SizedBox(height: footerGap),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              context.l10n.t('categories_view_collection'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .labelLarge
                                  ?.copyWith(
                                    color: AppColors.brown,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ),
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
            ),
          ),
        );
      },
    );
  }
}

class _CategoryVisual extends StatelessWidget {
  final CategoryModel category;
  final double height;
  final double iconSize;

  const _CategoryVisual({
    required this.category,
    required this.height,
    required this.iconSize,
  });

  @override
  Widget build(BuildContext context) {
    final icon = _CategoryIconMapper.iconFor(category.iconKey ?? category.name);

    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: AppColors.softPanelGradient,
        border: Border.all(color: AppColors.border.withValues(alpha: 0.8)),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -18,
            right: -8,
            child: Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.accentGold.withValues(alpha: 0.12),
              ),
            ),
          ),
          Center(
            child: category.imageUrl != null && category.imageUrl!.isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Image.network(
                      category.imageUrl!,
                      width: iconSize + 30,
                      height: iconSize + 30,
                      fit: BoxFit.cover,
                    ),
                  )
                : Icon(icon, size: iconSize, color: AppColors.brown),
          ),
        ],
      ),
    );
  }
}

class _CategoryIconMapper {
  static IconData iconFor(String value) {
    switch (value.toLowerCase()) {
      case 'coffee':
        return Icons.local_cafe_outlined;
      case 'spices':
        return Icons.spa_outlined;
      case 'herbs_attar':
      case 'herbs & attar':
        return Icons.favorite_outline;
      case 'incense':
        return Icons.auto_awesome_outlined;
      case 'nuts':
        return Icons.grain_outlined;
      case 'dates':
        return Icons.circle_outlined;
      case 'oils':
        return Icons.opacity_outlined;
      default:
        return Icons.category_outlined;
    }
  }
}
