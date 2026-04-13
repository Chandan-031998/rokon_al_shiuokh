import 'package:flutter/material.dart';

import '../../localization/app_localizations.dart';
import '../constants/app_colors.dart';

class SectionTitle extends StatelessWidget {
  final String title;

  const SectionTitle({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isWide = width >= 980;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        isWide ? 24 : 20,
        isWide ? 44 : 30,
        isWide ? 24 : 20,
        isWide ? 20 : 16,
      ),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isWide ? 22 : 18,
          vertical: isWide ? 18 : 16,
        ),
        decoration: BoxDecoration(
          gradient: AppColors.softPanelGradient,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.border),
          boxShadow: AppColors.softShadow,
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                gradient: AppColors.goldGradient,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.borderStrong.withValues(alpha: 0.5)),
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                color: AppColors.primaryDark,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.t('brand_badge'),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.secondary,
                          letterSpacing: 1.8,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    title,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontSize: isWide ? 28 : 24,
                        ),
                  ),
                ],
              ),
            ),
            Container(
              width: isWide ? 72 : 46,
              height: 2,
              decoration: BoxDecoration(
                gradient: AppColors.goldGradient,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
