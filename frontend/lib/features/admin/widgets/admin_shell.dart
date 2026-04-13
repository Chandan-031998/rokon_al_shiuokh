import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/brand_logo.dart';
import '../../../core/widgets/language_toggle.dart';
import '../../../localization/app_locale_controller.dart';
import '../../../localization/app_localizations.dart';
import '../../../models/user_model.dart';
import '../admin_session_controller.dart';

class AdminShell extends StatelessWidget {
  final AdminSessionController sessionController;
  final AppLocaleController localeController;
  final Widget child;

  const AdminShell({
    super.key,
    required this.sessionController,
    required this.localeController,
    required this.child,
  });

  List<({String label, String path, IconData icon})> _items(
      AppLocalizations l10n) => <({String label, String path, IconData icon})>[
        (
          label: l10n.t('admin_nav_dashboard'),
          path: '/admin',
          icon: Icons.dashboard_outlined,
        ),
        (
          label: l10n.t('admin_nav_products'),
          path: '/admin/products',
          icon: Icons.inventory_2_outlined,
        ),
        (
          label: l10n.t('admin_nav_categories'),
          path: '/admin/categories',
          icon: Icons.category_outlined,
        ),
        (
          label: l10n.t('admin_nav_orders'),
          path: '/admin/orders',
          icon: Icons.receipt_long_outlined,
        ),
        (
          label: l10n.t('admin_nav_customers'),
          path: '/admin/customers',
          icon: Icons.people_outline,
        ),
        (
          label: l10n.t('admin_nav_branches'),
          path: '/admin/branches',
          icon: Icons.storefront_outlined,
        ),
        (
          label: l10n.t('admin_nav_deliveries'),
          path: '/admin/deliveries',
          icon: Icons.local_shipping_outlined,
        ),
        (
          label: l10n.t('admin_nav_offers'),
          path: '/admin/offers',
          icon: Icons.local_offer_outlined,
        ),
        (
          label: l10n.t('admin_nav_import'),
          path: '/admin/import',
          icon: Icons.upload_file_outlined,
        ),
        (
          label: l10n.t('admin_nav_settings'),
          path: '/admin/settings',
          icon: Icons.settings_outlined,
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final items = _items(l10n);
    final path = GoRouterState.of(context).uri.path;
    final isWide = MediaQuery.sizeOf(context).width >= 1100;
    final scaffoldKey = GlobalKey<ScaffoldState>();

    return Scaffold(
      key: scaffoldKey,
      backgroundColor: const Color(0xFFF7F1E8),
      body: Row(
        children: [
          if (isWide)
            _Sidebar(
              items: items,
              currentPath: path,
              user: sessionController.user,
              onNavigate: context.go,
              onLogout: sessionController.logout,
            ),
          Expanded(
            child: Column(
              children: [
                _Topbar(
                  items: items,
                  localeController: localeController,
                  currentPath: path,
                  user: sessionController.user,
                  showMenuButton: !isWide,
                  onMenuPressed: () => scaffoldKey.currentState?.openDrawer(),
                  onLogout: sessionController.logout,
                ),
                Expanded(child: child),
              ],
            ),
          ),
        ],
      ),
      drawer: isWide
          ? null
          : Drawer(
              width: 280,
            child: _Sidebar(
                items: items,
                currentPath: path,
                user: sessionController.user,
                onNavigate: (target) {
                  Navigator.of(context).pop();
                  context.go(target);
                },
                onLogout: () async {
                  Navigator.of(context).pop();
                  await sessionController.logout();
                  if (context.mounted) {
                    context.go('/admin/login');
                  }
                },
              ),
            ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  final List<({String label, String path, IconData icon})> items;
  final String currentPath;
  final UserModel? user;
  final ValueChanged<String> onNavigate;
  final Future<void> Function() onLogout;

  const _Sidebar({
    required this.items,
    required this.currentPath,
    required this.user,
    required this.onNavigate,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 286,
      decoration: const BoxDecoration(
        color: AppColors.brownDeep,
        boxShadow: [
          BoxShadow(
            color: Color(0x1A2D1A12),
            blurRadius: 24,
            offset: Offset(10, 0),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 24, 22, 18),
              child: Row(
                children: [
                  const BrandLogo(
                    size: 42,
                    padding: EdgeInsets.all(4),
                    backgroundColor: Color(0x0FFFFFFF),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.l10n.t('admin_brand_title'),
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                color: AppColors.white,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        Text(
                          context.l10n.t('admin_brand_subtitle'),
                          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                color: AppColors.gold,
                                letterSpacing: 0.7,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                children: [
                  for (final item in items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: _SidebarItem(
                        label: item.label,
                        icon: item.icon,
                        selected: currentPath == item.path,
                        onTap: () => onNavigate(item.path),
                      ),
                    ),
                ],
              ),
            ),
            Container(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 18),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user?.fullName ?? 'Admin',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: AppColors.white,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user?.email ?? '',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.creamSoft,
                        ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: onLogout,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.white,
                        side: BorderSide(color: Colors.white.withValues(alpha: 0.16)),
                      ),
                      icon: const Icon(Icons.logout),
                      label: Text(context.l10n.t('common_logout')),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _SidebarItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? Colors.white.withValues(alpha: 0.12) : Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: selected ? AppColors.gold : AppColors.creamSoft,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: selected ? AppColors.white : AppColors.creamSoft,
                        fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Topbar extends StatelessWidget {
  final List<({String label, String path, IconData icon})> items;
  final AppLocaleController localeController;
  final String currentPath;
  final UserModel? user;
  final bool showMenuButton;
  final VoidCallback onMenuPressed;
  final Future<void> Function() onLogout;

  const _Topbar({
    required this.items,
    required this.localeController,
    required this.currentPath,
    required this.user,
    required this.showMenuButton,
    required this.onMenuPressed,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final title = items.firstWhere(
      (item) => item.path == currentPath,
      orElse: () => items.first,
    ).label;

    return Container(
      height: 84,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: AppColors.cream,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            if (showMenuButton)
              IconButton(
                onPressed: onMenuPressed,
                icon: const Icon(Icons.menu_rounded),
              ),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  Text(
                    context.l10n.t('admin_topbar_subtitle'),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textMuted,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            LanguageToggle(
              controller: localeController,
              compact: true,
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  const Icon(Icons.admin_panel_settings_outlined, size: 18),
                  const SizedBox(width: 10),
                  Text(
                    user?.fullName ?? context.l10n.t('admin_user_fallback'),
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
