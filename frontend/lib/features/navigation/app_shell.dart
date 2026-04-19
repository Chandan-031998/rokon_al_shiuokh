import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/widgets/brand_logo.dart';
import '../../core/widgets/language_toggle.dart';
import '../../localization/app_locale_controller.dart';
import '../../localization/app_localizations.dart';
import '../../models/user_model.dart';
import '../../services/api_service.dart';
import '../account/account_page.dart';
import '../cart/cart_page.dart';
import '../categories/categories_page.dart';
import '../home/home_page.dart';
import '../orders/orders_page.dart';

enum AppTab { home, categories, cart, orders, account }

enum HomeSection { hero, featured, offers }

class AppShell extends StatefulWidget {
  final ApiService apiService;
  final AppLocaleController localeController;
  final AppTab initialTab;

  const AppShell({
    super.key,
    this.apiService = const ApiService(),
    required this.localeController,
    this.initialTab = AppTab.home,
  });

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late AppTab _currentTab;
  HomeSection _homeSection = HomeSection.hero;
  int _homeSectionRequestId = 0;
  Future<UserModel?>? _desktopProfileFuture;

  @override
  void initState() {
    super.initState();
    _currentTab = widget.initialTab;
    _desktopProfileFuture = _loadDesktopProfile();
    widget.apiService.refreshCartCount();
    widget.apiService.refreshWishlistIds();
  }

  @override
  void didUpdateWidget(covariant AppShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTab != widget.initialTab) {
      _currentTab = widget.initialTab;
    }
  }

  void _selectTab(AppTab tab) {
    final targetPath = _pathForTab(tab);
    final currentPath = GoRouterState.of(context).uri.path;
    setState(() => _currentTab = tab);
    if (tab == AppTab.account) {
      _refreshDesktopProfile();
    }
    if (currentPath != targetPath) {
      context.go(targetPath);
    }
  }

  void _openHomeSection(HomeSection section) {
    setState(() {
      _currentTab = AppTab.home;
      _homeSection = section;
      _homeSectionRequestId += 1;
    });
    if (GoRouterState.of(context).uri.path != '/') {
      context.go('/');
    }
  }

  String _pathForTab(AppTab tab) {
    return switch (tab) {
      AppTab.home => '/',
      AppTab.categories => '/categories',
      AppTab.cart => '/cart',
      AppTab.orders => '/orders',
      AppTab.account => '/account',
    };
  }

  Future<UserModel?> _loadDesktopProfile() async {
    final storedUser = await widget.apiService.getStoredUser();
    final hasSession = await widget.apiService.hasAuthSession();
    if (!hasSession) {
      return storedUser;
    }

    try {
      return await widget.apiService.fetchProfile();
    } catch (_) {
      return storedUser;
    }
  }

  void _refreshDesktopProfile() {
    setState(() {
      _desktopProfileFuture = _loadDesktopProfile();
    });
    widget.apiService.refreshWishlistIds();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final shellWidth = MediaQuery.sizeOf(context).width;
    final isDesktop = shellWidth >= 900;
    final screens = <AppTab, Widget>{
      AppTab.home: HomePage(
        onBrowseProducts: () => _selectTab(AppTab.categories),
        onChangeBranch: () => _selectTab(AppTab.categories),
        onAddToCart: () => _selectTab(AppTab.cart),
        apiService: widget.apiService,
        localeController: widget.localeController,
        showAppBar: !isDesktop,
        requestedSection: _homeSection,
        sectionRequestId: _homeSectionRequestId,
      ),
      AppTab.categories: CategoriesPage(
        onOpenCart: () => _selectTab(AppTab.cart),
        onOpenAccount: () => _selectTab(AppTab.account),
        apiService: widget.apiService,
        localeController: widget.localeController,
        showAppBar: !isDesktop,
      ),
      AppTab.cart: CartPage(
        apiService: widget.apiService,
        localeController: widget.localeController,
        isActive: _currentTab == AppTab.cart,
        onBrowseProducts: () => _selectTab(AppTab.categories),
        onOpenOrders: () => _selectTab(AppTab.orders),
        showAppBar: !isDesktop,
      ),
      AppTab.orders: OrdersPage(
        apiService: widget.apiService,
        localeController: widget.localeController,
        isActive: _currentTab == AppTab.orders,
        onBrowseProducts: () => _selectTab(AppTab.categories),
        onOpenAccount: () => _selectTab(AppTab.account),
        showAppBar: !isDesktop,
      ),
      AppTab.account: AccountPage(
        apiService: widget.apiService,
        localeController: widget.localeController,
        isActive: _currentTab == AppTab.account,
        onOpenOrders: () => _selectTab(AppTab.orders),
        onOpenCart: () => _selectTab(AppTab.cart),
        showAppBar: !isDesktop,
        onSessionChanged: _refreshDesktopProfile,
      ),
    };

    return Scaffold(
      appBar: isDesktop
          ? PreferredSize(
              preferredSize: Size.fromHeight(shellWidth >= 1200 ? 104 : 96),
              child: _DesktopTopNav(
                currentTab: _currentTab,
                activeHomeSection: _homeSection,
                onSelectTab: _selectTab,
                onSelectHomeSection: _openHomeSection,
                localeController: widget.localeController,
                profileFuture: _desktopProfileFuture ?? _loadDesktopProfile(),
                shellWidth: shellWidth,
              ),
            )
          : null,
      body: IndexedStack(
        index: AppTab.values.indexOf(_currentTab),
        children: AppTab.values.map((tab) => screens[tab]!).toList(),
      ),
      bottomNavigationBar: isDesktop
          ? null
          : DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.surfaceRaised,
                    AppColors.surface.withValues(alpha: 0.98),
                  ],
                ),
                border: const Border(top: BorderSide(color: AppColors.border)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0F2D1A12),
                    blurRadius: 20,
                    offset: Offset(0, -8),
                  ),
                ],
              ),
              child: NavigationBar(
                selectedIndex: AppTab.values.indexOf(_currentTab),
                onDestinationSelected: (index) =>
                    _selectTab(AppTab.values[index]),
                destinations: [
                  NavigationDestination(
                    icon: const Icon(Icons.home_outlined),
                    selectedIcon: const Icon(Icons.home),
                    label: l10n.t('nav_home'),
                  ),
                  NavigationDestination(
                    icon: const Icon(Icons.grid_view_outlined),
                    selectedIcon: const Icon(Icons.grid_view),
                    label: l10n.t('nav_categories'),
                  ),
                  NavigationDestination(
                    icon: const _CartBadgeIcon(
                      icon: Icon(Icons.shopping_cart_outlined),
                    ),
                    selectedIcon: const _CartBadgeIcon(
                      icon: Icon(Icons.shopping_cart),
                    ),
                    label: l10n.t('nav_cart'),
                  ),
                  NavigationDestination(
                    icon: const Icon(Icons.receipt_long_outlined),
                    selectedIcon: const Icon(Icons.receipt_long),
                    label: l10n.t('nav_orders'),
                  ),
                  NavigationDestination(
                    icon: const Icon(Icons.person_outline),
                    selectedIcon: const Icon(Icons.person),
                    label: l10n.t('nav_account'),
                  ),
                ],
              ),
            ),
    );
  }
}

class _DesktopTopNav extends StatelessWidget {
  final AppTab currentTab;
  final HomeSection activeHomeSection;
  final ValueChanged<AppTab> onSelectTab;
  final ValueChanged<HomeSection> onSelectHomeSection;
  final AppLocaleController localeController;
  final Future<UserModel?> profileFuture;
  final double shellWidth;

  const _DesktopTopNav({
    required this.currentTab,
    required this.activeHomeSection,
    required this.onSelectTab,
    required this.onSelectHomeSection,
    required this.localeController,
    required this.profileFuture,
    required this.shellWidth,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isFullDesktop = shellWidth >= 1200;
    final horizontalPadding = isFullDesktop ? 28.0 : 22.0;
    final navbarHeight = isFullDesktop ? 94.0 : 86.0;
    final tabItems = <({AppTab tab, String label})>[
      (tab: AppTab.home, label: l10n.t('nav_home')),
      (tab: AppTab.categories, label: l10n.t('nav_categories')),
      (tab: AppTab.orders, label: l10n.t('nav_orders')),
      (tab: AppTab.account, label: l10n.t('nav_account')),
    ];
    final sectionItems = <({HomeSection section, String label})>[
      (section: HomeSection.featured, label: l10n.t('nav_featured')),
      (section: HomeSection.offers, label: l10n.t('nav_offers')),
    ];

    return Material(
      color: AppColors.background,
      elevation: 0,
      child: Container(
        height: navbarHeight,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.surface.withValues(alpha: 0.98),
              AppColors.background,
            ],
          ),
          border: const Border(bottom: BorderSide(color: AppColors.border)),
          boxShadow: AppColors.softShadow,
        ),
        child: SafeArea(
          bottom: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1280),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                child: Row(
                  children: [
                    SizedBox(
                      width: isFullDesktop ? 280 : 230,
                      child: const Align(
                        alignment: Alignment.centerLeft,
                        child: _DesktopBrandBlock(),
                      ),
                    ),
                    SizedBox(width: isFullDesktop ? 24 : 14),
                    Expanded(
                      child: _DesktopCenterNav(
                        tabItems: tabItems,
                        sectionItems: sectionItems,
                        currentTab: currentTab,
                        activeHomeSection: activeHomeSection,
                        onSelectTab: onSelectTab,
                        onSelectHomeSection: onSelectHomeSection,
                        compact: !isFullDesktop,
                      ),
                    ),
                    SizedBox(width: isFullDesktop ? 20 : 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: _DesktopHeaderActions(
                        localeController: localeController,
                        onSelectTab: onSelectTab,
                        profileFuture: profileFuture,
                        compact: !isFullDesktop,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DesktopBrandBlock extends StatelessWidget {
  const _DesktopBrandBlock();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const BrandLogo(
          size: 64,
          padding: EdgeInsets.zero,
          showShadow: false,
          transparentHighlight: false,
        ),
        const SizedBox(width: 14),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.t('app_title'),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      fontSize: 20,
                    ),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                l10n.t('brand_tagline'),
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AppColors.goldMuted,
                      letterSpacing: 0.8,
                      fontSize: 11.5,
                    ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DesktopCenterNav extends StatelessWidget {
  final List<({AppTab tab, String label})> tabItems;
  final List<({HomeSection section, String label})> sectionItems;
  final AppTab currentTab;
  final HomeSection activeHomeSection;
  final ValueChanged<AppTab> onSelectTab;
  final ValueChanged<HomeSection> onSelectHomeSection;
  final bool compact;

  const _DesktopCenterNav({
    required this.tabItems,
    required this.sectionItems,
    required this.currentTab,
    required this.activeHomeSection,
    required this.onSelectTab,
    required this.onSelectHomeSection,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    final navRow = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final item in tabItems) ...[
          _DesktopNavButton(
            label: item.label,
            selected: item.tab == AppTab.home
                ? currentTab == AppTab.home &&
                    activeHomeSection == HomeSection.hero
                : currentTab == item.tab,
            onPressed: () => onSelectTab(item.tab),
            compact: compact,
          ),
          SizedBox(width: compact ? 6 : 10),
        ],
        for (var index = 0; index < sectionItems.length; index++) ...[
          _DesktopNavButton(
            label: sectionItems[index].label,
            selected: currentTab == AppTab.home &&
                activeHomeSection == sectionItems[index].section,
            onPressed: () => onSelectHomeSection(sectionItems[index].section),
            compact: compact,
          ),
          if (index != sectionItems.length - 1)
            SizedBox(width: compact ? 6 : 10),
        ],
      ],
    );

    if (!compact) {
      return Align(
        alignment: Alignment.center,
        child: navRow,
      );
    }

    return Align(
      alignment: Alignment.center,
      child: ClipRect(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          primary: false,
          child: navRow,
        ),
      ),
    );
  }
}

class _DesktopHeaderActions extends StatelessWidget {
  final AppLocaleController localeController;
  final ValueChanged<AppTab> onSelectTab;
  final Future<UserModel?> profileFuture;
  final bool compact;

  const _DesktopHeaderActions({
    required this.localeController,
    required this.onSelectTab,
    required this.profileFuture,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        LanguageToggle(
          controller: localeController,
          compact: compact,
        ),
        SizedBox(width: compact ? 8 : 10),
        IconButton.filledTonal(
          onPressed: () => onSelectTab(AppTab.cart),
          style: IconButton.styleFrom(
            backgroundColor: AppColors.surface,
            foregroundColor: AppColors.primaryDark,
            side: const BorderSide(color: AppColors.border),
          ),
          icon: const _CartBadgeIcon(
            icon: Icon(Icons.shopping_bag_outlined),
          ),
          tooltip: l10n.t('nav_cart'),
        ),
        SizedBox(width: compact ? 8 : 10),
        FutureBuilder<UserModel?>(
          future: profileFuture,
          builder: (context, snapshot) {
            final user = snapshot.data;
            if (user == null || user.id == 0) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  OutlinedButton(
                    onPressed: () => onSelectTab(AppTab.account),
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.symmetric(
                        horizontal: compact ? 12 : 15,
                        vertical: compact ? 11 : 13,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(l10n.t('common_login')),
                  ),
                  SizedBox(width: compact ? 8 : 10),
                  ElevatedButton.icon(
                    onPressed: () => onSelectTab(AppTab.account),
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(
                        horizontal: compact ? 12 : 15,
                        vertical: compact ? 11 : 13,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    icon: const Icon(Icons.person_add_alt_1_rounded),
                    label: Text(l10n.t('common_register')),
                  ),
                ],
              );
            }

            final initials = user.fullName
                .split(' ')
                .where((part) => part.trim().isNotEmpty)
                .take(2)
                .map((part) => part.substring(0, 1).toUpperCase())
                .join();

            return InkWell(
              onTap: () => onSelectTab(AppTab.account),
              borderRadius: BorderRadius.circular(20),
              child: Ink(
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? 8 : 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  gradient: AppColors.surfaceGradient,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border),
                  boxShadow: AppColors.softShadow,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: AppColors.creamSoft,
                      foregroundColor: AppColors.brownDeep,
                      child: Text(
                        initials.isEmpty ? 'R' : initials,
                        style: Theme.of(context)
                            .textTheme
                            .labelLarge
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: compact ? 108 : 150,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            user.fullName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .labelLarge
                                ?.copyWith(
                                  color: AppColors.textDark,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          Text(
                            l10n.t('nav_account'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(color: AppColors.goldMuted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _CartBadgeIcon extends StatelessWidget {
  final Widget icon;

  const _CartBadgeIcon({
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: ApiService.cartCountListenable,
      builder: (context, count, child) {
        if (count <= 0) {
          return child!;
        }
        return Badge(
          label: Text('$count'),
          child: child,
        );
      },
      child: icon,
    );
  }
}

class _DesktopNavButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onPressed;
  final bool compact;

  const _DesktopNavButton({
    required this.label,
    required this.selected,
    required this.onPressed,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        backgroundColor: selected
            ? AppColors.primaryDark
            : AppColors.surface.withValues(alpha: 0.72),
        foregroundColor: selected ? AppColors.white : AppColors.primaryDark,
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 10 : 14,
          vertical: compact ? 11 : 13,
        ),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: selected ? AppColors.primaryDark : AppColors.border,
          ),
        ),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: selected ? AppColors.white : AppColors.brownDeep,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
              fontSize: compact ? 12.5 : 13.5,
            ),
      ),
    );
  }
}

class TabScreenTemplate extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Widget> sections;
  final Widget? body;
  final bool showAppBar;
  final AppLocaleController? localeController;

  const TabScreenTemplate({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.sections = const <Widget>[],
    this.body,
    this.showAppBar = true,
    this.localeController,
  });

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 980;

    return Scaffold(
      appBar: showAppBar
          ? AppBar(
              toolbarHeight: 84,
              flexibleSpace: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppColors.surface.withValues(alpha: 0.96),
                      AppColors.background,
                    ],
                  ),
                  border: const Border(
                    bottom: BorderSide(color: AppColors.border),
                  ),
                ),
              ),
              title: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const BrandLogo(
                        size: 34,
                        padding: EdgeInsets.all(2),
                        showShadow: false,
                        transparentHighlight: true,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              eyebrow,
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                    color: AppColors.goldMuted,
                                    letterSpacing: 1.6,
                                    fontWeight: FontWeight.w700,
                                  ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              title,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                if (localeController != null)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 10),
                    child: Center(
                      child: LanguageToggle(
                        controller: localeController!,
                        compact: true,
                      ),
                    ),
                  ),
                Padding(
                  padding: EdgeInsetsDirectional.only(
                    end: localeController != null ? 14 : 20,
                  ),
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      gradient: AppColors.goldGradient,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: AppColors.softShadow,
                    ),
                    child: Icon(icon, color: AppColors.primaryDark),
                  ),
                ),
              ],
            )
          : null,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1280),
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              isWide ? 24 : 20,
              showAppBar ? 12 : 28,
              isWide ? 24 : 20,
              40,
            ),
            children: [
              _IntroCard(title: title, subtitle: subtitle, icon: icon),
              const SizedBox(height: 20),
              if (body != null) body! else ...sections,
            ],
          ),
        ),
      ),
    );
  }
}

class _IntroCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;

  const _IntroCard({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.surfaceGradient,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: AppColors.goldGradient,
                  boxShadow: AppColors.softShadow,
                ),
                child: Icon(icon, color: AppColors.primaryDark),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontSize: 25,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(subtitle, style: Theme.of(context).textTheme.bodyLarge),
        ],
      ),
    );
  }
}

class ActionPanel extends StatelessWidget {
  final String title;
  final String description;
  final String actionLabel;
  final VoidCallback onPressed;
  final IconData icon;

  const ActionPanel({
    super.key,
    required this.title,
    required this.description,
    required this.actionLabel,
    required this.onPressed,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.surfaceGradient,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.softShadow,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: AppColors.goldGradient,
              borderRadius: BorderRadius.circular(16),
              boxShadow: AppColors.softShadow,
            ),
            child: Icon(icon, color: AppColors.primaryDark),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 6),
                Text(description),
                const SizedBox(height: 14),
                Row(
                  children: [
                    ElevatedButton(
                      onPressed: onPressed,
                      child: Text(actionLabel),
                    ),
                    const SizedBox(width: 10),
                    const Icon(
                      Icons.arrow_forward_rounded,
                      color: AppColors.brown,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class DetailTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final String trailing;
  final IconData icon;

  const DetailTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppColors.surfaceGradient,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.softShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: AppColors.goldGradient,
              borderRadius: BorderRadius.circular(14),
              boxShadow: AppColors.softShadow,
            ),
            child: Icon(icon, color: AppColors.primaryDark, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 4),
                Text(subtitle),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            trailing,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: AppColors.brown,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}
