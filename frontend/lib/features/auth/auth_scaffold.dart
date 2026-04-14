import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/widgets/brand_logo.dart';
import '../../localization/app_localizations.dart';

class AuthScaffold extends StatelessWidget {
  final String title;
  final String subtitle;
  final String footerPrompt;
  final String footerActionLabel;
  final VoidCallback onFooterAction;
  final Widget child;

  const AuthScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.footerPrompt,
    required this.footerActionLabel,
    required this.onFooterAction,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 920;

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1240),
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  isWide ? 28 : 20,
                  16,
                  isWide ? 28 : 20,
                  28,
                ),
                children: [
                  if (isWide)
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            flex: 11,
                            child: _AuthBrandPanel(
                              title: title,
                              subtitle: subtitle,
                            ),
                          ),
                          const SizedBox(width: 24),
                          Expanded(
                            flex: 9,
                            child: _AuthFormPanel(
                              title: title,
                              subtitle: subtitle,
                              footerPrompt: footerPrompt,
                              footerActionLabel: footerActionLabel,
                              onFooterAction: onFooterAction,
                              child: child,
                            ),
                          ),
                        ],
                      ),
                    )
                  else ...[
                    _AuthBrandPanel(
                      title: title,
                      subtitle: subtitle,
                      compact: true,
                    ),
                    const SizedBox(height: 18),
                    _AuthFormPanel(
                      title: title,
                      subtitle: subtitle,
                      footerPrompt: footerPrompt,
                      footerActionLabel: footerActionLabel,
                      onFooterAction: onFooterAction,
                      child: child,
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class AuthField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hintText;
  final TextInputType? keyboardType;
  final bool obscureText;
  final String? Function(String?) validator;

  const AuthField({
    super.key,
    required this.controller,
    required this.label,
    required this.hintText,
    required this.validator,
    this.keyboardType,
    this.obscureText = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: const BorderSide(color: AppColors.border),
        ),
      ),
    );
  }
}

class _AuthBrandPanel extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool compact;

  const _AuthBrandPanel({
    required this.title,
    required this.subtitle,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Container(
      padding: EdgeInsets.all(compact ? 24 : 34),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(36),
        gradient: AppColors.heroGradient,
        boxShadow: AppColors.strongShadow,
      ),
      child: Stack(
        children: [
          Positioned(
            top: -40,
            right: -16,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
          ),
          Positioned(
            bottom: -48,
            left: -24,
            child: Container(
              width: 144,
              height: 144,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
          ),
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(compact ? 20 : 26),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: AppColors.accentLightGold.withValues(alpha: 0.22),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: AppColors.accentLightGold.withValues(alpha: 0.28),
                    ),
                  ),
                  child: Text(
                    l10n.t('auth_brand_eyebrow'),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.creamSoft,
                          letterSpacing: 1.6,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
                const SizedBox(height: 24),
                const BrandLogo(
                  size: 70,
                  padding: EdgeInsets.all(2),
                  showShadow: false,
                  transparentHighlight: true,
                ),
                const SizedBox(height: 22),
                Text(
                  title,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: AppColors.white,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 12),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppColors.creamSoft,
                        height: 1.7,
                      ),
                ),
                const SizedBox(height: 28),
                _BrandPoint(
                  icon: Icons.diamond_outlined,
                  label: l10n.t('auth_point_curated'),
                ),
                const SizedBox(height: 14),
                _BrandPoint(
                  icon: Icons.local_shipping_outlined,
                  label: l10n.t('auth_point_delivery'),
                ),
                const SizedBox(height: 14),
                _BrandPoint(
                  icon: Icons.storefront_outlined,
                  label: l10n.t('auth_point_branches'),
                ),
                if (!compact) ...[
                  const Spacer(),
                  Text(
                    l10n.t('auth_brand_footer'),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.creamSoft.withValues(alpha: 0.86),
                        ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AuthFormPanel extends StatelessWidget {
  final String title;
  final String subtitle;
  final String footerPrompt;
  final String footerActionLabel;
  final VoidCallback onFooterAction;
  final Widget child;

  const _AuthFormPanel({
    required this.title,
    required this.subtitle,
    required this.footerPrompt,
    required this.footerActionLabel,
    required this.onFooterAction,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: AppColors.surfaceGradient,
        borderRadius: BorderRadius.circular(36),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.panelShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style:
                Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.7),
          ),
          const SizedBox(height: 26),
          child,
          const SizedBox(height: 18),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: [
              Text(footerPrompt, style: Theme.of(context).textTheme.bodyMedium),
              TextButton(
                onPressed: onFooterAction,
                child: Text(footerActionLabel),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BrandPoint extends StatelessWidget {
  final IconData icon;
  final String label;

  const _BrandPoint({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: AppColors.creamSoft, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppColors.white,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
      ],
    );
  }
}
