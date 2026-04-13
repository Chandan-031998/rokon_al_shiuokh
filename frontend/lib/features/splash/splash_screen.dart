import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/widgets/brand_logo.dart';
import '../../localization/app_localizations.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.brownDeep, AppColors.brown, AppColors.goldMuted],
          ),
        ),
        child: Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.92, end: 1),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              return Opacity(
                opacity: ((value - 0.92) / 0.08).clamp(0, 1),
                child: Transform.scale(
                  scale: value,
                  child: child,
                ),
              );
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const BrandLogo(
                  size: 110,
                  padding: EdgeInsets.all(18),
                  backgroundColor: Color(0xFFFDF8F1),
                  borderRadius: BorderRadius.all(Radius.circular(28)),
                ),
                const SizedBox(height: 28),
                Text(
                  l10n.t('app_title').toUpperCase(),
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: AppColors.white,
                        letterSpacing: 2.8,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.t('splash_subtitle'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.creamSoft,
                        letterSpacing: 0.3,
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
