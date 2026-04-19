import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:rokon_al_shiuokh_app/features/home/home_page.dart';
import 'package:rokon_al_shiuokh_app/features/navigation/app_shell.dart';
import 'package:rokon_al_shiuokh_app/localization/app_locale_controller.dart';
import 'package:rokon_al_shiuokh_app/localization/app_localizations.dart';
import 'package:rokon_al_shiuokh_app/models/branch_model.dart';
import 'package:rokon_al_shiuokh_app/models/cart_item_model.dart';
import 'package:rokon_al_shiuokh_app/models/cart_model.dart';
import 'package:rokon_al_shiuokh_app/models/category_model.dart';
import 'package:rokon_al_shiuokh_app/models/cms_page_model.dart';
import 'package:rokon_al_shiuokh_app/models/offer_model.dart';
import 'package:rokon_al_shiuokh_app/models/product_model.dart';
import 'package:rokon_al_shiuokh_app/models/support_settings_model.dart';
import 'package:rokon_al_shiuokh_app/services/api_service.dart';

class _FakeApiService extends ApiService {
  const _FakeApiService();

  @override
  Future<List<CategoryModel>> fetchCategories({bool forceRefresh = false}) async {
    return const [
      CategoryModel(id: 1, name: 'Coffee', nameAr: 'القهوة', iconKey: 'coffee'),
      CategoryModel(
          id: 2, name: 'Spices', nameAr: 'البهارات', iconKey: 'spices'),
    ];
  }

  @override
  Future<List<BranchModel>> fetchBranches({bool forceRefresh = false}) async {
    return const [
      BranchModel(id: 1, name: 'Mahayil Aseer (Main Branch)'),
      BranchModel(id: 2, name: 'Abha Branch'),
    ];
  }

  @override
  Future<List<ProductModel>> fetchProducts({
    int? categoryId,
    int? branchId,
    String? query,
    List<int> filterValueIds = const <int>[],
    bool featuredOnly = false,
  }) async {
    return const [
      ProductModel(
        id: 1,
        name: 'Premium Arabic Coffee',
        nameAr: 'قهوة عربية فاخرة',
        price: 28,
        categoryId: 1,
        branchId: 1,
        description: '250g pack with cardamom',
        sku: 'COF-250G',
      ),
    ];
  }

  @override
  Future<List<OfferModel>> fetchOffers() async {
    return const [
      OfferModel(
        id: 1,
        title: 'Spring Coffee Offer',
        subtitle: 'Freshly roasted weekly',
      ),
    ];
  }

  @override
  Future<List<CmsPageModel>> fetchCmsPages({String? section}) async {
    return const [
      CmsPageModel(
        id: 1,
        slug: 'delivery-block-main',
        title: 'Delivery Information',
        section: 'delivery_information',
        excerpt: 'Live branch coverage appears here.',
      ),
    ];
  }

  @override
  Future<SupportSettingsModel> fetchSupportSettings() async {
    return const SupportSettingsModel(
      contactPhone: '+966500000000',
      whatsappNumber: '+966500000000',
      whatsappLabel: 'Chat with Support',
    );
  }

  @override
  Future<CartModel> fetchCart() async {
    return const CartModel(
      items: [
        CartItemModel(
          id: 1,
          quantity: 1,
          branchId: 1,
          lineTotal: 28,
          product: ProductModel(
            id: 1,
            name: 'Premium Arabic Coffee',
            nameAr: 'قهوة عربية فاخرة',
            price: 28,
            categoryId: 1,
            branchId: 1,
            description: '250g pack with cardamom',
            sku: 'COF-250G',
          ),
          branch: BranchModel(id: 1, name: 'Mahayil Aseer (Main Branch)'),
        ),
      ],
      subtotal: 28,
      total: 28,
      currency: 'SAR',
    );
  }
}

void main() {
  testWidgets('app renders shell navigation', (WidgetTester tester) async {
    final localeController = AppLocaleController();

    await tester.pumpWidget(
      MaterialApp(
        locale: localeController.locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        home: AppShell(
          apiService: const _FakeApiService(),
          localeController: localeController,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(AppShell), findsOneWidget);
    expect(find.byType(HomePage), findsOneWidget);
  });
}
