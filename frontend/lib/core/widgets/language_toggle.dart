import 'package:flutter/material.dart';

import '../../localization/app_locale_controller.dart';
import '../../localization/app_localizations.dart';
import '../constants/app_colors.dart';

class LanguageToggle extends StatelessWidget {
  final AppLocaleController controller;
  final bool compact;

  const LanguageToggle({
    super.key,
    required this.controller,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final isArabic = controller.locale.languageCode == 'ar';
        final width = compact ? 82.0 : 94.0;
        final height = compact ? 38.0 : 42.0;
        final thumbInset = compact ? 3.0 : 4.0;
        final segmentWidth = (width - (thumbInset * 2)) / 2;

        Future<void> setLanguage(String code) async {
          await controller.setLocale(Locale(code));
        }

        return Semantics(
          button: true,
          label: context.l10n.t('account_language'),
          child: Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFFFFBF7), Color(0xFFF3E6D2)],
              ),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: AppColors.borderStrong.withValues(alpha: 0.52)),
              boxShadow: compact ? const [] : AppColors.softShadow,
            ),
            child: Stack(
              children: [
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  left: isArabic ? null : thumbInset,
                  right: isArabic ? thumbInset : null,
                  top: thumbInset,
                  width: segmentWidth,
                  height: height - (thumbInset * 2),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: AppColors.goldGradient,
                      borderRadius: BorderRadius.circular(999),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x1A5A2E1F),
                          blurRadius: 12,
                          offset: Offset(0, 6),
                        ),
                      ],
                    ),
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: _LanguageToggleSegment(
                        label: 'EN',
                        compact: compact,
                        active: !isArabic,
                        onTap: () => setLanguage('en'),
                      ),
                    ),
                    Expanded(
                      child: _LanguageToggleSegment(
                        label: 'AR',
                        compact: compact,
                        active: isArabic,
                        onTap: () => setLanguage('ar'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _LanguageToggleSegment extends StatelessWidget {
  final String label;
  final bool compact;
  final bool active;
  final VoidCallback onTap;

  const _LanguageToggleSegment({
    required this.label,
    required this.compact,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Center(
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            style: Theme.of(context).textTheme.labelLarge!.copyWith(
                  color: active ? AppColors.primaryDark : AppColors.secondary,
                  fontWeight: FontWeight.w800,
                  fontSize: compact ? 11.5 : 12.5,
                  letterSpacing: 0.8,
                ),
            child: Text(label),
          ),
        ),
      ),
    );
  }
}
