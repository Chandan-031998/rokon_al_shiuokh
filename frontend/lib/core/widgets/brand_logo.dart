import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

class BrandLogo extends StatelessWidget {
  final double size;
  final EdgeInsets padding;
  final Color? backgroundColor;
  final BorderRadius borderRadius;
  final bool showShadow;
  final bool transparentHighlight;

  const BrandLogo({
    super.key,
    this.size = 48,
    this.padding = const EdgeInsets.all(4),
    this.backgroundColor,
    this.borderRadius = const BorderRadius.all(Radius.circular(18)),
    this.showShadow = true,
    this.transparentHighlight = true,
  });

  @override
  Widget build(BuildContext context) {
    return LuxuryLogoWidget(
      size: size,
      padding: padding,
      backgroundColor: backgroundColor,
      borderRadius: borderRadius,
      showShadow: showShadow,
      transparentHighlight: transparentHighlight,
    );
  }
}

class LuxuryLogoWidget extends StatelessWidget {
  final double size;
  final EdgeInsets padding;
  final Color? backgroundColor;
  final BorderRadius borderRadius;
  final bool showShadow;
  final bool transparentHighlight;

  const LuxuryLogoWidget({
    super.key,
    this.size = 48,
    this.padding = const EdgeInsets.all(4),
    this.backgroundColor,
    this.borderRadius = const BorderRadius.all(Radius.circular(18)),
    this.showShadow = true,
    this.transparentHighlight = true,
  });

  @override
  Widget build(BuildContext context) {
    final hasPanel = backgroundColor != null;
    final extraFramePadding = transparentHighlight ? 10.0 : 0.0;

    return SizedBox(
      width: size + padding.horizontal + extraFramePadding,
      height: size + padding.vertical + extraFramePadding,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (transparentHighlight) ...[
            Container(
              width: size + 20,
              height: size + 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.accentLightGold.withValues(alpha: 0.42),
                    AppColors.accentGold.withValues(alpha: 0.16),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.52, 1.0],
                ),
              ),
            ),
            Container(
              width: size + 6,
              height: size + 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: showShadow
                    ? [
                        BoxShadow(
                          color: AppColors.accentGold.withValues(alpha: 0.22),
                          blurRadius: 22,
                          spreadRadius: 2,
                        ),
                      ]
                    : const [],
              ),
            ),
          ],
          Container(
            decoration: BoxDecoration(
              gradient: hasPanel ? AppColors.logoBackgroundGradient : null,
              color: hasPanel ? backgroundColor : Colors.transparent,
              borderRadius: borderRadius,
              border: hasPanel
                  ? Border.all(color: AppColors.borderStrong.withValues(alpha: 0.7))
                  : null,
              boxShadow: hasPanel && showShadow ? AppColors.softShadow : const [],
            ),
            child: Padding(
              padding: padding,
              child: Image.asset(
                'assets/images/newlogo.png',
                width: size,
                height: size,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
