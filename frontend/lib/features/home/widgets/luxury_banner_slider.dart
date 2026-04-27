import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/extensions/localized_content.dart';
import '../../../core/widgets/brand_logo.dart';
import '../../../core/widgets/premium_network_image.dart';
import '../../../localization/app_localizations.dart';
import '../../../models/cms_page_model.dart';

class LuxuryBannerSlider extends StatelessWidget {
  final Future<List<CmsPageModel>> slidesFuture;
  final VoidCallback onRetry;
  final VoidCallback? onBrowseProducts;
  final VoidCallback? onChangeBranch;

  const LuxuryBannerSlider({
    super.key,
    required this.slidesFuture,
    required this.onRetry,
    this.onBrowseProducts,
    this.onChangeBranch,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<CmsPageModel>>(
      future: slidesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _SliderStateCard(
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return _SliderStateCard(
            child: _SliderMessage(
              title: 'Homepage banners are unavailable',
              description:
                  'The storefront hero banners could not be loaded from admin-managed content.',
              actionLabel: 'Retry',
              onPressed: onRetry,
            ),
          );
        }

        final slides = (snapshot.data ?? const <CmsPageModel>[])
            .where((page) => page.slug.isNotEmpty)
            .toList()
          ..sort((left, right) => left.sortOrder.compareTo(right.sortOrder));

        if (slides.isEmpty) {
          return _SliderStateCard(
            child: _SliderMessage(
              title: 'No homepage banners published',
              description:
                  'Publish active hero banners from the admin content module to populate this section.',
              actionLabel: 'Refresh',
              onPressed: onRetry,
            ),
          );
        }

        return _BannerCarousel(
          slides: slides,
          onBrowseProducts: onBrowseProducts,
          onChangeBranch: onChangeBranch,
        );
      },
    );
  }
}

class _BannerCarousel extends StatefulWidget {
  final List<CmsPageModel> slides;
  final VoidCallback? onBrowseProducts;
  final VoidCallback? onChangeBranch;

  const _BannerCarousel({
    required this.slides,
    this.onBrowseProducts,
    this.onChangeBranch,
  });

  @override
  State<_BannerCarousel> createState() => _BannerCarouselState();
}

class _BannerCarouselState extends State<_BannerCarousel> {
  late final PageController _pageController;
  Timer? _autoPlayTimer;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 1);
    _startAutoplay();
  }

  @override
  void dispose() {
    _autoPlayTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _BannerCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_currentIndex >= widget.slides.length) {
      _currentIndex = 0;
    }
    if (oldWidget.slides.length != widget.slides.length) {
      _startAutoplay();
    }
  }

  void _startAutoplay() {
    _autoPlayTimer?.cancel();
    if (widget.slides.length <= 1) {
      return;
    }
    _autoPlayTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || !_pageController.hasClients || widget.slides.isEmpty) {
        return;
      }
      final nextIndex = (_currentIndex + 1) % widget.slides.length;
      _pageController.animateToPage(
        nextIndex,
        duration: const Duration(milliseconds: 650),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _goToPage(int index) {
    if (!_pageController.hasClients) {
      return;
    }
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 520),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = width >= 980;
    final isTablet = width >= 680;
    final isCompactMobile = width < 460;
    final sliderHeight = isDesktop
        ? 430.0
        : isTablet
            ? 380.0
            : isCompactMobile
                ? 374.0
                : 356.0;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.95, end: 1),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: ((value - 0.95) / 0.05).clamp(0, 1),
          child: Transform.translate(
            offset: Offset(0, 22 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.fromLTRB(24, 0, 24, 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(isDesktop ? 34 : 30),
          boxShadow: AppColors.strongShadow,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(isDesktop ? 34 : 30),
          child: SizedBox(
            height: sliderHeight,
            child: Stack(
              children: [
                NotificationListener<ScrollNotification>(
                  onNotification: (notification) {
                    if (notification is ScrollStartNotification) {
                      _autoPlayTimer?.cancel();
                    } else if (notification is ScrollEndNotification) {
                      _startAutoplay();
                    }
                    return false;
                  },
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: (index) {
                      setState(() => _currentIndex = index);
                    },
                    itemCount: widget.slides.length,
                    itemBuilder: (context, index) {
                      final slide = widget.slides[index];
                      return _BannerSlide(
                        page: slide,
                        active: index == _currentIndex,
                        isDesktop: isDesktop,
                        isTablet: isTablet,
                        isCompactMobile: isCompactMobile,
                        onPrimaryTap: widget.onBrowseProducts,
                        onSecondaryTap: widget.onChangeBranch,
                      );
                    },
                  ),
                ),
                if (isDesktop && widget.slides.length > 1) ...[
                  Positioned(
                    left: 18,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: _SliderArrowButton(
                        icon: Icons.arrow_back_ios_new_rounded,
                        onPressed: () => _goToPage(
                          (_currentIndex - 1 + widget.slides.length) %
                              widget.slides.length,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 18,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: _SliderArrowButton(
                        icon: Icons.arrow_forward_ios_rounded,
                        onPressed: () => _goToPage(
                            (_currentIndex + 1) % widget.slides.length),
                      ),
                    ),
                  ),
                ],
                Positioned(
                  left: isDesktop ? 28 : 20,
                  right: isDesktop ? 28 : 20,
                  bottom: isDesktop ? 24 : (isCompactMobile ? 12 : 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: List.generate(
                            widget.slides.length,
                            (index) => Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: _SliderIndicator(
                                active: index == _currentIndex,
                                onTap: () => _goToPage(index),
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (isTablet)
                        _SliderInfoPill(
                          icon: Icons.workspace_premium_outlined,
                          label: _localizedHeroLabel(
                            _localizedMetadata(
                              widget.slides[_currentIndex],
                              context.l10n,
                              'metric',
                            ),
                            context.l10n,
                            'home_hero_metric_storefront',
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BannerSlide extends StatelessWidget {
  final CmsPageModel page;
  final bool active;
  final bool isDesktop;
  final bool isTablet;
  final bool isCompactMobile;
  final VoidCallback? onPrimaryTap;
  final VoidCallback? onSecondaryTap;

  const _BannerSlide({
    required this.page,
    required this.active,
    required this.isDesktop,
    required this.isTablet,
    required this.isCompactMobile,
    this.onPrimaryTap,
    this.onSecondaryTap,
  });

  @override
  Widget build(BuildContext context) {
    final contentWidth = isDesktop
        ? 520.0
        : isTablet
            ? 440.0
            : double.infinity;

    return Stack(
      fit: StackFit.expand,
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween(begin: active ? 1.0 : 1.05, end: active ? 1.05 : 1.0),
          duration: const Duration(milliseconds: 900),
          curve: Curves.easeOutCubic,
          builder: (context, scale, child) {
            return Transform.scale(scale: scale, child: child);
          },
          child: _BannerBackground(imageUrl: page.imageUrl),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                AppColors.primaryDark.withValues(alpha: 0.82),
                AppColors.primary.withValues(alpha: 0.64),
                AppColors.primaryDark.withValues(alpha: 0.18),
              ],
              stops: const [0.0, 0.46, 1.0],
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [
                Colors.black.withValues(alpha: 0.24),
                Colors.transparent,
              ],
            ),
          ),
        ),
        Positioned.fill(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              isDesktop ? 38 : 22,
              isDesktop ? 34 : 22,
              isDesktop ? 38 : 22,
              isDesktop ? 34 : 22,
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: contentWidth),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 420),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeOutCubic,
                  transitionBuilder: (child, animation) {
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0.06, 0),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    );
                  },
                  child: _SlideContent(
                    key: ValueKey(page.id),
                    page: page,
                    isDesktop: isDesktop,
                    isCompactMobile: isCompactMobile,
                    onPrimaryTap: onPrimaryTap,
                    onSecondaryTap: onSecondaryTap,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SlideContent extends StatelessWidget {
  final CmsPageModel page;
  final bool isDesktop;
  final bool isCompactMobile;
  final VoidCallback? onPrimaryTap;
  final VoidCallback? onSecondaryTap;

  const _SlideContent({
    super.key,
    required this.page,
    required this.isDesktop,
    required this.isCompactMobile,
    this.onPrimaryTap,
    this.onSecondaryTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final containerPadding = isDesktop ? 24.0 : (isCompactMobile ? 14.0 : 16.0);
    final eyebrowPadding = EdgeInsets.symmetric(
      horizontal: isCompactMobile ? 10 : 12,
      vertical: isCompactMobile ? 6 : 8,
    );
    final logoSize = isDesktop ? 58.0 : (isCompactMobile ? 40.0 : 48.0);
    final titleSize = isDesktop ? 36.0 : (isCompactMobile ? 24.0 : 26.0);
    final introGap = isCompactMobile ? 12.0 : 16.0;
    final bodyGap = isCompactMobile ? 10.0 : 14.0;
    final actionGap = isCompactMobile ? 14.0 : 18.0;
    final eyebrow = _localizedHeroLabel(
      _localizedMetadata(page, l10n, 'eyebrow'),
      l10n,
      'home_hero_eyebrow_storefront_feature',
    );
    final subtitle =
        (page.localizedExcerpt(l10n) ?? page.localizedBody(l10n) ?? '').trim();
    final primaryLabel = _localizedHeroLabel(
      page.localizedCtaLabel(l10n),
      l10n,
      'home_hero_cta_browse_collection',
    );
    final secondaryLabel = _localizedHeroLabel(
      _localizedMetadata(page, l10n, 'secondary_label'),
      l10n,
      'home_hero_cta_change_branch',
    );

    return Container(
      padding: EdgeInsets.all(containerPadding),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.14),
            Colors.white.withValues(alpha: 0.06),
          ],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: eyebrowPadding,
            decoration: BoxDecoration(
              color: AppColors.accentLightGold.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: AppColors.accentLightGold.withValues(alpha: 0.34),
              ),
            ),
            child: Text(
              eyebrow,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.accentLightGold,
                    letterSpacing: 1.8,
                  ),
            ),
          ),
          SizedBox(height: introGap),
          Row(
            children: [
              BrandLogo(
                size: logoSize,
                padding: const EdgeInsets.all(2),
                showShadow: false,
                transparentHighlight: true,
              ),
              SizedBox(width: isCompactMobile ? 10 : 12),
              Expanded(
                child: Text(
                  page.localizedTitle(l10n),
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: AppColors.white,
                        fontSize: titleSize,
                        height: 1.06,
                      ),
                  maxLines: isCompactMobile ? 3 : null,
                  overflow: isCompactMobile
                      ? TextOverflow.ellipsis
                      : TextOverflow.visible,
                ),
              ),
            ],
          ),
          if (subtitle.isNotEmpty) ...[
            SizedBox(height: bodyGap),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.creamSoft,
                    fontSize: isCompactMobile ? 15 : null,
                    height: isCompactMobile ? 1.45 : null,
                  ),
              maxLines: isCompactMobile ? 3 : null,
              overflow: isCompactMobile
                  ? TextOverflow.ellipsis
                  : TextOverflow.visible,
            ),
          ],
          SizedBox(height: actionGap),
          Wrap(
            spacing: isCompactMobile ? 10 : 12,
            runSpacing: isCompactMobile ? 10 : 12,
            children: [
              FilledButton(
                onPressed: onPrimaryTap,
                child: Text(primaryLabel),
              ),
              OutlinedButton(
                onPressed: onSecondaryTap,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.white,
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.25)),
                  backgroundColor: Colors.white.withValues(alpha: 0.06),
                ),
                child: Text(secondaryLabel),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BannerBackground extends StatelessWidget {
  final String? imageUrl;

  const _BannerBackground({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    final resolvedImageUrl = (imageUrl ?? '').trim();
    if (resolvedImageUrl.isEmpty) {
      return const _BannerBackgroundFallback();
    }

    return PremiumNetworkImage(
      imageUrl: resolvedImageUrl,
      borderRadius: BorderRadius.zero,
      fit: BoxFit.cover,
      transformWidth: 2200,
      transformQuality: 86,
      fallbackIcon: Icons.image_outlined,
    );
  }
}

class _BannerBackgroundFallback extends StatelessWidget {
  const _BannerBackgroundFallback();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: AppColors.heroGradient),
      child: Stack(
        fit: StackFit.expand,
        children: [
          const Positioned(
            top: -50,
            right: -30,
            child: _FallbackGlow(size: 180),
          ),
          const Positioned(
            bottom: -60,
            left: -20,
            child: _FallbackGlow(size: 160),
          ),
          Center(
            child: Opacity(
              opacity: 0.22,
              child: Transform.scale(
                scale: 1.2,
                child: const BrandLogo(
                  size: 120,
                  padding: EdgeInsets.all(2),
                  showShadow: false,
                  transparentHighlight: true,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FallbackGlow extends StatelessWidget {
  final double size;

  const _FallbackGlow({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            Colors.white.withValues(alpha: 0.18),
            AppColors.accentLightGold.withValues(alpha: 0.08),
            Colors.transparent,
          ],
        ),
      ),
    );
  }
}

class _SliderArrowButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;

  const _SliderArrowButton({
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Icon(icon, color: AppColors.white, size: 20),
        ),
      ),
    );
  }
}

class _SliderIndicator extends StatelessWidget {
  final bool active;
  final VoidCallback onTap;

  const _SliderIndicator({
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        width: active ? 30 : 10,
        height: 10,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          gradient: active ? AppColors.goldGradient : null,
          color: active ? null : Colors.white.withValues(alpha: 0.36),
          border: active
              ? null
              : Border.all(color: Colors.white.withValues(alpha: 0.24)),
        ),
      ),
    );
  }
}

class _SliderInfoPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _SliderInfoPill({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.accentLightGold, size: 18),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: AppColors.white,
                ),
          ),
        ],
      ),
    );
  }
}

class _SliderStateCard extends StatelessWidget {
  final Widget child;

  const _SliderStateCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 340,
      margin: const EdgeInsets.fromLTRB(24, 0, 24, 10),
      decoration: BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: BorderRadius.circular(30),
        boxShadow: AppColors.strongShadow,
      ),
      child: child,
    );
  }
}

class _SliderMessage extends StatelessWidget {
  final String title;
  final String description;
  final String actionLabel;
  final VoidCallback onPressed;

  const _SliderMessage({
    required this.title,
    required this.description,
    required this.actionLabel,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Align(
        alignment: Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppColors.white,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 12),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppColors.creamSoft,
                        height: 1.6,
                      ),
                ),
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: onPressed,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.creamSoft,
                    foregroundColor: AppColors.brownDeep,
                  ),
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

String? _localizedMetadata(
  CmsPageModel page,
  AppLocalizations l10n,
  String key,
) {
  final metadata = page.metadataJson;
  if (l10n.isArabic) {
    final arabic = metadata['${key}_ar']?.toString().trim();
    if (arabic != null && arabic.isNotEmpty) {
      return arabic;
    }
  }

  final value = metadata[key]?.toString().trim();
  if (value == null || value.isEmpty) {
    return null;
  }
  return value;
}

String _localizedHeroLabel(
  String? value,
  AppLocalizations l10n,
  String fallbackKey,
) {
  final normalized = (value ?? '').trim();
  if (normalized.isEmpty) {
    return l10n.t(fallbackKey);
  }

  if (!l10n.isArabic) {
    return normalized;
  }

  switch (normalized.toLowerCase()) {
    case 'browse collection':
      return l10n.t('home_hero_cta_browse_collection');
    case 'change branch':
      return l10n.t('home_hero_cta_change_branch');
    case 'storefront feature':
      return l10n.t('home_hero_eyebrow_storefront_feature');
    case 'signature collection':
      return l10n.t('home_hero_eyebrow_signature_collection');
    case 'storefront':
      return l10n.t('home_hero_metric_storefront');
    case 'majlis ready':
      return l10n.t('home_hero_metric_majlis_ready');
  }

  return normalized;
}
