import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import 'brand_logo.dart';

class PremiumNetworkImage extends StatelessWidget {
  final String? imageUrl;
  final double? width;
  final double? height;
  final BorderRadius borderRadius;
  final BoxFit fit;
  final IconData fallbackIcon;
  final double fallbackIconSize;

  const PremiumNetworkImage({
    super.key,
    required this.imageUrl,
    required this.borderRadius,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.fallbackIcon = Icons.inventory_2_outlined,
    this.fallbackIconSize = 34,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedUrl = _normalizeImageUrl(imageUrl);
    final placeholder = _ImageFallback(
      icon: fallbackIcon,
      iconSize: fallbackIconSize,
    );

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.creamSoft, AppColors.cream],
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: resolvedUrl == null
          ? placeholder
          : Image.network(
              resolvedUrl,
              fit: fit,
              width: width,
              height: height,
              filterQuality: FilterQuality.medium,
              loadingBuilder: (context, child, progress) {
                if (progress == null) {
                  return child;
                }
                return _ImageSkeleton(borderRadius: borderRadius);
              },
              errorBuilder: (_, __, ___) => placeholder,
            ),
    );
  }
}

class _ImageFallback extends StatelessWidget {
  final IconData icon;
  final double iconSize;

  const _ImageFallback({
    required this.icon,
    required this.iconSize,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const BrandLogo(
            size: 42,
            padding: EdgeInsets.all(2),
            showShadow: false,
            transparentHighlight: true,
          ),
          const SizedBox(height: 10),
          Icon(icon, size: iconSize, color: AppColors.brown),
        ],
      ),
    );
  }
}

class _ImageSkeleton extends StatefulWidget {
  final BorderRadius borderRadius;

  const _ImageSkeleton({required this.borderRadius});

  @override
  State<_ImageSkeleton> createState() => _ImageSkeletonState();
}

class _ImageSkeletonState extends State<_ImageSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (bounds) {
            final offset = _controller.value * 2 - 1;
            return LinearGradient(
              begin: Alignment(-1.2 + offset, -0.3),
              end: Alignment(0.2 + offset, 0.3),
              colors: const [
                Color(0x00FFFFFF),
                Color(0x66FFFFFF),
                Color(0x00FFFFFF),
              ],
              stops: const [0.1, 0.5, 0.9],
            ).createShader(bounds);
          },
          blendMode: BlendMode.srcATop,
          child: child,
        );
      },
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: widget.borderRadius,
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF8F0E4), Color(0xFFF1E6D7), Color(0xFFE8D6BF)],
          ),
        ),
      ),
    );
  }
}

String? _normalizeImageUrl(String? rawUrl) {
  final value = rawUrl?.trim();
  if (value == null || value.isEmpty) {
    return null;
  }

  final uri = Uri.tryParse(value);
  if (uri == null) {
    return null;
  }

  if (uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https')) {
    return uri.toString();
  }

  return null;
}
