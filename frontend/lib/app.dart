import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';

import 'core/theme/app_theme.dart';
import 'features/admin/admin_session_controller.dart';
import 'features/admin/pages/admin_branches_page.dart';
import 'features/admin/pages/admin_categories_page.dart';
import 'features/admin/pages/admin_content_page.dart';
import 'features/admin/pages/admin_customers_page.dart';
import 'features/admin/pages/admin_dashboard_page.dart';
import 'features/admin/pages/admin_deliveries_page.dart';
import 'features/admin/pages/admin_import_page.dart';
import 'features/admin/pages/admin_login_page.dart';
import 'features/admin/pages/admin_offers_page.dart';
import 'features/admin/pages/admin_orders_page.dart';
import 'features/admin/pages/admin_products_page.dart';
import 'features/admin/pages/admin_reviews_page.dart';
import 'features/admin/pages/admin_settings_page.dart';
import 'features/admin/services/admin_api_service.dart';
import 'features/admin/widgets/admin_shell.dart';
import 'features/customer/customer_entry.dart';
import 'features/navigation/app_shell.dart';
import 'localization/app_locale_controller.dart';
import 'localization/app_localizations.dart';
import 'services/api_service.dart';
import 'core/constants/app_colors.dart';

class RokonApp extends StatefulWidget {
  final ApiService apiService;

  const RokonApp({
    super.key,
    this.apiService = const ApiService(),
  });

  @override
  State<RokonApp> createState() => _RokonAppState();
}

class _RokonAppState extends State<RokonApp> {
  late final AppLocaleController _localeController;
  late final AdminSessionController _adminSessionController;
  late final AdminApiService _adminApiService;
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _localeController = AppLocaleController();
    _adminApiService = const AdminApiService();
    _adminSessionController =
        AdminSessionController(apiService: _adminApiService);
    _localeController.load();
    _adminSessionController.load();
    _router = GoRouter(
      initialLocation: _initialLocation(),
      refreshListenable: _adminSessionController,
      redirect: (context, state) {
        final isAdminPath = state.uri.path.startsWith('/admin');
        if (!isAdminPath) {
          return null;
        }

        final isLoginRoute = state.uri.path == '/admin/login';
        final intendedAdminPath = state.uri.path == '/admin/login'
            ? state.uri.queryParameters['from']
            : state.uri.path;
        if (!_adminSessionController.isLoaded) {
          return isLoginRoute ? null : '/admin/login';
        }

        final isAuthenticated = _adminSessionController.isAuthenticated;
        if (!isAuthenticated && !isLoginRoute) {
          return Uri(
            path: '/admin/login',
            queryParameters: {
              'from': intendedAdminPath,
            },
          ).toString();
        }
        if (isAuthenticated && isLoginRoute) {
          if (intendedAdminPath != null &&
              intendedAdminPath.startsWith('/admin') &&
              intendedAdminPath != '/admin/login') {
            return intendedAdminPath;
          }
          return '/admin';
        }
        return null;
      },
      routes: [
        _customerRoute(path: '/', initialTab: AppTab.home),
        _customerRoute(path: '/categories', initialTab: AppTab.categories),
        _customerRoute(path: '/cart', initialTab: AppTab.cart),
        _customerRoute(path: '/orders', initialTab: AppTab.orders),
        _customerRoute(path: '/account', initialTab: AppTab.account),
        GoRoute(
          path: '/admin/login',
          builder: (context, state) => AdminLoginPage(
            sessionController: _adminSessionController,
            localeController: _localeController,
          ),
        ),
        ShellRoute(
          builder: (context, state, child) => AdminShell(
            sessionController: _adminSessionController,
            localeController: _localeController,
            child: child,
          ),
          routes: [
            GoRoute(
              path: '/admin',
              builder: (context, state) =>
                  AdminDashboardPage(apiService: _adminApiService),
            ),
            GoRoute(
              path: '/admin/products',
              builder: (context, state) =>
                  AdminProductsPage(apiService: _adminApiService),
            ),
            GoRoute(
              path: '/admin/categories',
              builder: (context, state) =>
                  AdminCategoriesPage(apiService: _adminApiService),
            ),
            GoRoute(
              path: '/admin/orders',
              builder: (context, state) =>
                  AdminOrdersPage(apiService: _adminApiService),
            ),
            GoRoute(
              path: '/admin/customers',
              builder: (context, state) =>
                  AdminCustomersPage(apiService: _adminApiService),
            ),
            GoRoute(
              path: '/admin/branches',
              builder: (context, state) =>
                  AdminBranchesPage(apiService: _adminApiService),
            ),
            GoRoute(
              path: '/admin/deliveries',
              builder: (context, state) =>
                  AdminDeliveriesPage(apiService: _adminApiService),
            ),
            GoRoute(
              path: '/admin/offers',
              builder: (context, state) =>
                  AdminOffersPage(apiService: _adminApiService),
            ),
            GoRoute(
              path: '/admin/content',
              builder: (context, state) =>
                  AdminContentPage(apiService: _adminApiService),
            ),
            GoRoute(
              path: '/admin/reviews',
              builder: (context, state) =>
                  AdminReviewsPage(apiService: _adminApiService),
            ),
            GoRoute(
              path: '/admin/import',
              builder: (context, state) =>
                  AdminImportPage(apiService: _adminApiService),
            ),
            GoRoute(
              path: '/admin/settings',
              builder: (context, state) => AdminSettingsPage(
                sessionController: _adminSessionController,
                apiService: _adminApiService,
              ),
            ),
          ],
        ),
      ],
      errorBuilder: (context, state) => _RouteErrorPage(state: state),
    );
  }

  GoRoute _customerRoute({
    required String path,
    required AppTab initialTab,
  }) {
    return GoRoute(
      path: path,
      builder: (context, state) => CustomerEntry(
        apiService: widget.apiService,
        localeController: _localeController,
        initialTab: initialTab,
      ),
    );
  }

  String _initialLocation() {
    final uri = Uri.base;
    final path = uri.path.isEmpty ? '/' : uri.path;
    const customerPaths = <String>{
      '/',
      '/categories',
      '/cart',
      '/orders',
      '/account',
    };
    if (path.startsWith('/admin') || customerPaths.contains(path)) {
      return path;
    }
    return '/';
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _localeController,
      builder: (context, _) {
        return MaterialApp.router(
          debugShowCheckedModeBanner: false,
          onGenerateTitle: (context) => context.l10n.t('app_title'),
          locale: _localeController.locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          builder: (context, child) {
            final isArabic = _localeController.locale.languageCode == 'ar';
            return Directionality(
              textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
              child: child ?? const SizedBox.shrink(),
            );
          },
          theme: AppTheme.lightTheme,
          routerConfig: _router,
        );
      },
    );
  }

  @override
  void dispose() {
    _localeController.dispose();
    _adminSessionController.dispose();
    super.dispose();
  }
}

class _RouteErrorPage extends StatelessWidget {
  final GoRouterState state;

  const _RouteErrorPage({required this.state});

  @override
  Widget build(BuildContext context) {
    final isAdminRoute = state.uri.path.startsWith('/admin');
    final target = isAdminRoute ? '/admin/login' : '/';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: AppColors.border),
              ),
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Unable to open this page.',
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      state.error?.toString() ??
                          'The requested route is unavailable.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () => context.go(target),
                      child:
                          Text(isAdminRoute ? 'Open admin login' : 'Go home'),
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
