import 'package:flutter/material.dart';

import '../../localization/app_locale_controller.dart';
import '../../localization/app_localizations.dart';
import '../constants/app_colors.dart';

class StorefrontSwitcher extends StatelessWidget {
  final AppLocaleController controller;
  final bool compact;

  const StorefrontSwitcher({
    super.key,
    required this.controller,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final l10n = context.l10n;
        final languageLabel = controller.isArabic
            ? l10n.t('switcher_language_ar')
            : l10n.t('switcher_language_en');
        final regionLabel = controller.regionCode == 'ae'
            ? l10n.t('switcher_region_ae')
            : l10n.t('switcher_region_sa');

        return OutlinedButton.icon(
          onPressed: () => _showStorefrontSheet(context),
          style: OutlinedButton.styleFrom(
            backgroundColor: AppColors.surface,
            foregroundColor: AppColors.primaryDark,
            side: const BorderSide(color: AppColors.border),
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 12 : 14,
              vertical: compact ? 10 : 12,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
          icon: Icon(
            controller.isArabic
                ? Icons.translate_rounded
                : Icons.language_rounded,
            size: compact ? 18 : 20,
          ),
          label: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                languageLabel,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: AppColors.primaryDark,
                      fontWeight: FontWeight.w800,
                    ),
              ),
              Text(
                regionLabel,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.goldMuted,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showStorefrontSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _StorefrontSheet(controller: controller),
    );
  }
}

class _StorefrontSheet extends StatelessWidget {
  final AppLocaleController controller;

  const _StorefrontSheet({
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final mediaQuery = MediaQuery.of(context);
    final maxSheetHeight = mediaQuery.size.height - mediaQuery.padding.top - 24;

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxSheetHeight),
        child: Container(
          decoration: const BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: AnimatedBuilder(
            animation: controller,
            builder: (context, _) {
              return SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  20,
                  16,
                  20,
                  28 + mediaQuery.viewPadding.bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 56,
                        height: 5,
                        decoration: BoxDecoration(
                          color: AppColors.borderStrong.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      l10n.t('switcher_sheet_title'),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      l10n.t('switcher_sheet_subtitle'),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.textMuted,
                            height: 1.5,
                          ),
                    ),
                    const SizedBox(height: 18),
                    _SwitchCard(
                      title: l10n.t('switcher_language_title'),
                      subtitle: l10n.t('switcher_language_subtitle'),
                      child: SegmentedButton<String>(
                        segments: [
                          ButtonSegment<String>(
                            value: 'en',
                            label: Text(l10n.t('switcher_language_en')),
                          ),
                          ButtonSegment<String>(
                            value: 'ar',
                            label: Text(l10n.t('switcher_language_ar')),
                          ),
                        ],
                        selected: {controller.languageCode},
                        onSelectionChanged: (selection) {
                          final languageCode = selection.first;
                          controller.setLocale(Locale(languageCode));
                        },
                      ),
                    ),
                    const SizedBox(height: 14),
                    _SwitchCard(
                      title: l10n.t('switcher_region_title'),
                      subtitle: l10n.t('switcher_region_subtitle'),
                      child: SegmentedButton<String>(
                        segments: [
                          ButtonSegment<String>(
                            value: 'sa',
                            label: Text(l10n.t('switcher_region_sa')),
                          ),
                          ButtonSegment<String>(
                            value: 'ae',
                            label: Text(l10n.t('switcher_region_ae')),
                          ),
                        ],
                        selected: {controller.regionCode},
                        onSelectionChanged: (selection) {
                          controller.setRegionCode(selection.first);
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _SwitchCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _SwitchCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: AppColors.surfaceGradient,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textMuted,
                ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}
