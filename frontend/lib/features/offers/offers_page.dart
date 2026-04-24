import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/extensions/localized_content.dart';
import '../../core/widgets/premium_network_image.dart';
import '../../localization/app_locale_controller.dart';
import '../../localization/app_localizations.dart';
import '../../models/offer_model.dart';
import '../../services/api_service.dart';

class OffersPage extends StatefulWidget {
  final ApiService apiService;
  final AppLocaleController localeController;

  const OffersPage({
    super.key,
    this.apiService = const ApiService(),
    required this.localeController,
  });

  @override
  State<OffersPage> createState() => _OffersPageState();
}

class _OffersPageState extends State<OffersPage> {
  late Future<List<OfferModel>> _offersFuture;

  @override
  void initState() {
    super.initState();
    widget.localeController.addListener(_reloadForStorefront);
    _offersFuture = _loadOffers();
  }

  @override
  void didUpdateWidget(covariant OffersPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.localeController != widget.localeController) {
      oldWidget.localeController.removeListener(_reloadForStorefront);
      widget.localeController.addListener(_reloadForStorefront);
      _reloadForStorefront();
    }
  }

  @override
  void dispose() {
    widget.localeController.removeListener(_reloadForStorefront);
    super.dispose();
  }

  Future<List<OfferModel>> _loadOffers() {
    return widget.apiService.fetchOffers(
      language: widget.localeController.languageCode,
      regionCode: widget.localeController.regionCode,
    );
  }

  void _reloadForStorefront() {
    if (!mounted) {
      return;
    }
    setState(() {
      _offersFuture = _loadOffers();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.t('offers_page_title'))),
      body: FutureBuilder<List<OfferModel>>(
        future: _offersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return _OffersStateCard(
              title: l10n.t('offers_error_title'),
              description: l10n.t('offers_error_desc'),
              actionLabel: l10n.t('common_retry'),
              onPressed: _reloadForStorefront,
            );
          }

          final offers = snapshot.data ?? const <OfferModel>[];
          if (offers.isEmpty) {
            return _OffersStateCard(
              title: l10n.t('offers_empty_title'),
              description: l10n.t('offers_empty_desc'),
              actionLabel: l10n.t('common_refresh'),
              onPressed: _reloadForStorefront,
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
            itemCount: offers.length,
            separatorBuilder: (_, __) => const SizedBox(height: 14),
            itemBuilder: (context, index) => _OfferCard(offer: offers[index]),
          );
        },
      ),
    );
  }
}

class _OfferCard extends StatelessWidget {
  final OfferModel offer;

  const _OfferCard({required this.offer});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final hasImage = (offer.bannerUrl ?? '').trim().isNotEmpty;

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
              transformWidth: 1200,
              transformQuality: 84,
              height: 180,
              borderRadius: BorderRadius.circular(18),
              fallbackIcon: Icons.local_offer_outlined,
            )
          else
            _OfferImageFallback(offer: offer),
          const SizedBox(height: 16),
          Text(
            offer.localizedTitle(l10n),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppColors.creamSoft,
                  fontWeight: FontWeight.w800,
                ),
          ),
          if ((offer.localizedSubtitle(l10n) ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              offer.localizedSubtitle(l10n)!,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.creamSoft.withValues(alpha: 0.92),
                  ),
            ),
          ],
          if ((offer.localizedDescription(l10n) ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              offer.localizedDescription(l10n)!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.creamSoft.withValues(alpha: 0.84),
                    height: 1.6,
                  ),
            ),
          ],
          const SizedBox(height: 14),
          Text(
            _offerBadge(offer, l10n),
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: AppColors.accentLightGold,
                  fontWeight: FontWeight.w800,
                ),
          ),
        ],
      ),
    );
  }
}

class _OfferImageFallback extends StatelessWidget {
  final OfferModel offer;

  const _OfferImageFallback({required this.offer});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 140,
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
      ),
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Text(
        offer.localizedTitle(context.l10n),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppColors.creamSoft,
              fontWeight: FontWeight.w800,
            ),
      ),
    );
  }
}

class _OffersStateCard extends StatelessWidget {
  final String title;
  final String description;
  final String actionLabel;
  final VoidCallback onPressed;

  const _OffersStateCard({
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
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(28),
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
    );
  }
}

String _offerBadge(OfferModel offer, AppLocalizations l10n) {
  if ((offer.discountType ?? '').trim() == 'percentage' &&
      offer.discountValue > 0) {
    return '${offer.discountValue.toStringAsFixed(0)}% ${l10n.t('product_percentage_off')}';
  }
  if ((offer.discountType ?? '').trim() == 'flat' && offer.discountValue > 0) {
    return '${l10n.t('product_save_amount')} ${offer.discountValue.toStringAsFixed(0)}';
  }
  return l10n.t('product_limited_offer');
}
