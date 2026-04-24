import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants/api_constants.dart';
import '../models/branch_model.dart';
import '../models/cart_model.dart';
import '../models/category_model.dart';
import '../models/cms_page_model.dart';
import '../models/discovery_filter_models.dart';
import '../models/faq_model.dart';
import '../models/offer_model.dart';
import '../models/order_model.dart';
import '../models/product_detail_model.dart';
import '../models/product_model.dart';
import '../models/review_model.dart';
import '../models/search_term_model.dart';
import '../models/support_settings_model.dart';
import '../models/user_model.dart';
import '../models/wishlist_item_model.dart';

class ApiService {
  const ApiService();

  static const Duration _publicCacheTtl = Duration(minutes: 3);

  static const _guestSessionKey = 'guest_session_id';
  static const _authTokenKey = 'auth_token';
  static const _storedUserKey = 'auth_user_json';
  static const _guestHeader = 'X-Guest-Session-ID';
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();
  static final ValueNotifier<int> cartCountListenable = ValueNotifier<int>(0);
  static final ValueNotifier<Set<int>> wishlistIdsListenable =
      ValueNotifier<Set<int>>(<int>{});
  static final Map<String, List<CategoryModel>> _cachedCategories = {};
  static final Map<String, DateTime> _cachedCategoriesAt = {};
  static final Map<String, Future<List<CategoryModel>>> _pendingCategories = {};
  static final Map<String, List<BranchModel>> _cachedBranches = {};
  static final Map<String, DateTime> _cachedBranchesAt = {};
  static final Map<String, Future<List<BranchModel>>> _pendingBranches = {};
  static final Map<String, List<ProductModel>> _cachedFeaturedProducts = {};
  static final Map<String, DateTime> _cachedFeaturedProductsAt = {};
  static final Map<String, Future<List<ProductModel>>>
      _pendingFeaturedProducts = {};

  Future<String?> _readAuthToken() async {
    try {
      return await _secureStorage.read(key: _authTokenKey);
    } catch (_) {
      return null;
    }
  }

  Future<String?> _readSecureValue(String key) async {
    try {
      return await _secureStorage.read(key: key);
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeSecureValue(String key, String value) async {
    try {
      await _secureStorage.write(key: key, value: value);
    } catch (_) {
      // Ignore web secure-storage/platform failures and let the app fall back
      // to guest-safe UI states.
    }
  }

  Future<void> _deleteSecureValue(String key) async {
    try {
      await _secureStorage.delete(key: key);
    } catch (_) {
      // Ignore storage cleanup failures.
    }
  }

  Future<void> _persistAuthSession({
    required String token,
    required UserModel user,
  }) async {
    await _writeSecureValue(_authTokenKey, token);
    await _writeSecureValue(_storedUserKey, jsonEncode(user.toJson()));
  }

  Future<void> _clearAuthSession() async {
    await _deleteSecureValue(_authTokenKey);
    await _deleteSecureValue(_storedUserKey);
  }

  Future<Map<String, dynamic>> _decodeObjectResponse(
    http.Response response,
    String label,
  ) async {
    final decoded = await _decodeResponse(response, label);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Invalid $label payload');
    }
    return decoded;
  }

  Exception _apiExceptionFromResponse(
    http.Response response,
    String fallbackMessage,
  ) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        final error = (decoded['error'] as String?)?.trim();
        if (error != null && error.isNotEmpty) {
          return Exception(error);
        }
      }
    } catch (_) {
      // Ignore decode failures and return the fallback below.
    }

    return Exception(fallbackMessage);
  }

  Future<Map<String, String>> _buildHeaders({
    bool json = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final authToken = (await _readAuthToken())?.trim();
    final headers = <String, String>{};
    if (json) {
      headers['Content-Type'] = 'application/json';
    }

    if (authToken != null && authToken.isNotEmpty) {
      headers['Authorization'] = 'Bearer $authToken';
      return headers;
    }

    final guestSessionId = await _getGuestSessionId(prefs);
    headers[_guestHeader] = guestSessionId;
    return headers;
  }

  Future<String> _getGuestSessionId([SharedPreferences? prefs]) async {
    final resolvedPrefs = prefs ?? await SharedPreferences.getInstance();
    final existing = resolvedPrefs.getString(_guestSessionKey)?.trim();
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }

    final random = Random();
    // TODO: Replace local guest session generation if anonymous auth is added.
    final timestamp = DateTime.now().microsecondsSinceEpoch.toRadixString(16);
    final entropy = (random.nextDouble() * 0xFFFFFFFF)
        .floor()
        .toRadixString(16)
        .padLeft(8, '0');
    final sessionId = 'guest_${timestamp}_$entropy';
    await resolvedPrefs.setString(_guestSessionKey, sessionId);
    return sessionId;
  }

  Future<dynamic> _decodeResponse(http.Response response, String label) async {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _apiExceptionFromResponse(response, 'Failed to load $label');
    }

    return jsonDecode(response.body);
  }

  bool _isFresh(DateTime? timestamp) {
    if (timestamp == null) {
      return false;
    }
    return DateTime.now().difference(timestamp) < _publicCacheTtl;
  }

  void clearPublicCatalogCache() {
    _cachedCategories.clear();
    _cachedCategoriesAt.clear();
    _pendingCategories.clear();
    _cachedBranches.clear();
    _cachedBranchesAt.clear();
    _pendingBranches.clear();
    _cachedFeaturedProducts.clear();
    _cachedFeaturedProductsAt.clear();
    _pendingFeaturedProducts.clear();
  }

  Future<void> refreshCartCount() async {
    try {
      final cart = await fetchCart();
      _setCartCount(cart.totalQuantity);
    } catch (_) {
      _setCartCount(0);
    }
  }

  void _setCartCount(int count) {
    if (cartCountListenable.value != count) {
      cartCountListenable.value = count;
    }
  }

  void _setWishlistIds(Set<int> ids) {
    wishlistIdsListenable.value = Set<int>.unmodifiable(ids);
  }

  Future<List<CategoryModel>> fetchCategories({
    bool forceRefresh = false,
    String? language,
  }) async {
    final cacheKey = 'categories:${(language ?? 'en').trim().toLowerCase()}';
    if (!forceRefresh &&
        _cachedCategories.containsKey(cacheKey) &&
        _isFresh(_cachedCategoriesAt[cacheKey])) {
      return _cachedCategories[cacheKey]!;
    }
    if (!forceRefresh && _pendingCategories.containsKey(cacheKey)) {
      return _pendingCategories[cacheKey]!;
    }

    final pending = _fetchCategoriesNetwork(language: language);
    _pendingCategories[cacheKey] = pending;
    try {
      final categories = List<CategoryModel>.unmodifiable(await pending);
      _cachedCategories[cacheKey] = categories;
      _cachedCategoriesAt[cacheKey] = DateTime.now();
      return categories;
    } finally {
      if (identical(_pendingCategories[cacheKey], pending)) {
        _pendingCategories.remove(cacheKey);
      }
    }
  }

  Future<List<CategoryModel>> _fetchCategoriesNetwork(
      {String? language}) async {
    final uri = ApiConstants.endpoint(
      '/categories/',
      queryParameters: {
        if ((language ?? '').trim().isNotEmpty) 'language': language!.trim(),
      },
    );
    final response = await http.get(uri, headers: await _buildHeaders());
    final decoded = await _decodeResponse(response, 'categories');
    final rawItems = switch (decoded) {
      List<dynamic> items => items,
      Map<String, dynamic> object when object['items'] is List<dynamic> =>
        object['items'] as List<dynamic>,
      _ => throw Exception('Invalid categories payload'),
    };

    return rawItems
        .whereType<Map<String, dynamic>>()
        .map(CategoryModel.fromJson)
        .toList();
  }

  Future<List<BranchModel>> fetchBranches({
    bool forceRefresh = false,
    String? regionCode,
  }) async {
    final cacheKey = 'branches:${(regionCode ?? 'all').trim().toLowerCase()}';
    if (!forceRefresh &&
        _cachedBranches.containsKey(cacheKey) &&
        _isFresh(_cachedBranchesAt[cacheKey])) {
      return _cachedBranches[cacheKey]!;
    }
    if (!forceRefresh && _pendingBranches.containsKey(cacheKey)) {
      return _pendingBranches[cacheKey]!;
    }

    final pending = _fetchBranchesNetwork(regionCode: regionCode);
    _pendingBranches[cacheKey] = pending;
    try {
      final branches = List<BranchModel>.unmodifiable(await pending);
      _cachedBranches[cacheKey] = branches;
      _cachedBranchesAt[cacheKey] = DateTime.now();
      return branches;
    } finally {
      if (identical(_pendingBranches[cacheKey], pending)) {
        _pendingBranches.remove(cacheKey);
      }
    }
  }

  Future<List<BranchModel>> _fetchBranchesNetwork({String? regionCode}) async {
    final uri = ApiConstants.endpoint(
      '/branches/',
      queryParameters: {
        if ((regionCode ?? '').trim().isNotEmpty)
          'region_code': regionCode!.trim(),
      },
    );
    final response = await http.get(uri, headers: await _buildHeaders());
    final decoded = await _decodeResponse(response, 'branches');
    final rawItems = switch (decoded) {
      List<dynamic> items => items,
      Map<String, dynamic> object when object['items'] is List<dynamic> =>
        object['items'] as List<dynamic>,
      _ => throw Exception('Invalid branches payload'),
    };

    final seenIds = <int>{};
    final branches = <BranchModel>[];
    for (final item in rawItems.whereType<Map<String, dynamic>>()) {
      final branch = BranchModel.fromJson(item);
      if (branch.id <= 0 ||
          branch.name.isEmpty ||
          seenIds.contains(branch.id)) {
        continue;
      }
      seenIds.add(branch.id);
      branches.add(branch);
    }

    return branches;
  }

  Future<List<CmsPageModel>> fetchCmsPages({
    String? section,
    String? language,
    String? regionCode,
  }) async {
    final uri = ApiConstants.endpoint(
      '/content/pages',
      queryParameters: {
        if ((section ?? '').trim().isNotEmpty) 'section': section!.trim(),
        if ((language ?? '').trim().isNotEmpty) 'language': language!.trim(),
        if ((regionCode ?? '').trim().isNotEmpty)
          'region_code': regionCode!.trim(),
      },
    );
    final response = await http.get(uri, headers: await _buildHeaders());
    final decoded = await _decodeObjectResponse(response, 'content pages');
    final items = decoded['items'];
    if (items is! List) {
      throw Exception('Invalid content pages payload');
    }
    return items
        .whereType<Map<String, dynamic>>()
        .map(CmsPageModel.fromJson)
        .toList();
  }

  Future<CmsPageModel?> fetchCmsPageBySlug(
    String slug, {
    String? language,
    String? regionCode,
  }) async {
    final uri = ApiConstants.endpoint(
      '/content/pages/$slug',
      queryParameters: {
        if ((language ?? '').trim().isNotEmpty) 'language': language!.trim(),
        if ((regionCode ?? '').trim().isNotEmpty)
          'region_code': regionCode!.trim(),
      },
    );
    final response = await http.get(uri, headers: await _buildHeaders());
    final decoded = await _decodeObjectResponse(response, 'content page');
    final page = decoded['page'];
    if (page is! Map<String, dynamic>) {
      return null;
    }
    return CmsPageModel.fromJson(page);
  }

  Future<List<FaqModel>> fetchFaqs({String? language}) async {
    final uri = ApiConstants.endpoint(
      '/content/faqs',
      queryParameters: {
        if ((language ?? '').trim().isNotEmpty) 'language': language!.trim(),
      },
    );
    final response = await http.get(uri, headers: await _buildHeaders());
    final decoded = await _decodeObjectResponse(response, 'faqs');
    final items = decoded['items'];
    if (items is! List) {
      throw Exception('Invalid faqs payload');
    }
    return items
        .whereType<Map<String, dynamic>>()
        .map(FaqModel.fromJson)
        .toList();
  }

  Future<SupportSettingsModel> fetchSupportSettings({
    String? language,
    String? regionCode,
  }) async {
    final uri = ApiConstants.endpoint(
      '/content/support',
      queryParameters: {
        if ((language ?? '').trim().isNotEmpty) 'language': language!.trim(),
        if ((regionCode ?? '').trim().isNotEmpty)
          'region_code': regionCode!.trim(),
      },
    );
    final response = await http.get(uri, headers: await _buildHeaders());
    final decoded = await _decodeObjectResponse(response, 'support settings');
    return SupportSettingsModel.fromJson(
      (decoded['settings'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
  }

  Future<List<OfferModel>> fetchOffers({
    String? language,
    String? regionCode,
  }) async {
    final uri = ApiConstants.endpoint(
      '/content/offers',
      queryParameters: {
        if ((language ?? '').trim().isNotEmpty) 'language': language!.trim(),
        if ((regionCode ?? '').trim().isNotEmpty)
          'region_code': regionCode!.trim(),
      },
    );
    final response = await http.get(uri, headers: await _buildHeaders());
    final decoded = await _decodeObjectResponse(response, 'offers');
    final items = decoded['items'];
    if (items is! List) {
      throw Exception('Invalid offers payload');
    }
    return items
        .whereType<Map<String, dynamic>>()
        .map(OfferModel.fromJson)
        .toList();
  }

  Future<List<ProductModel>> fetchProducts({
    int? categoryId,
    int? branchId,
    String? language,
    String? regionCode,
    String? query,
    List<int> filterValueIds = const <int>[],
    bool featuredOnly = false,
  }) async {
    final uri = featuredOnly
        ? ApiConstants.endpoint('/products/featured')
        : ApiConstants.endpoint(
            '/products/',
            queryParameters: {
              if (categoryId != null) 'category_id': categoryId,
              if (branchId != null) 'branch_id': branchId,
              if ((language ?? '').trim().isNotEmpty)
                'language': language!.trim(),
              if ((regionCode ?? '').trim().isNotEmpty)
                'region_code': regionCode!.trim(),
              if ((query ?? '').trim().isNotEmpty) 'q': query!.trim(),
              if (filterValueIds.isNotEmpty)
                'filter_value_ids': filterValueIds.join(','),
            },
          );

    final response = await http.get(uri, headers: await _buildHeaders());
    final decoded = await _decodeResponse(response, 'products');
    final rawItems = switch (decoded) {
      List<dynamic> items => items,
      Map<String, dynamic> object when object['items'] is List<dynamic> =>
        object['items'] as List<dynamic>,
      _ => throw Exception('Invalid products payload'),
    };

    return rawItems
        .whereType<Map<String, dynamic>>()
        .map(ProductModel.fromJson)
        .toList();
  }

  Future<List<ProductModel>> fetchFeaturedProducts({
    bool forceRefresh = false,
    String? language,
    String? regionCode,
  }) async {
    final cacheKey =
        'featured:${(language ?? 'en').trim().toLowerCase()}:${(regionCode ?? 'all').trim().toLowerCase()}';
    if (!forceRefresh &&
        _cachedFeaturedProducts.containsKey(cacheKey) &&
        _isFresh(_cachedFeaturedProductsAt[cacheKey])) {
      return _cachedFeaturedProducts[cacheKey]!;
    }
    if (!forceRefresh && _pendingFeaturedProducts.containsKey(cacheKey)) {
      return _pendingFeaturedProducts[cacheKey]!;
    }

    final pending = fetchProducts(
      featuredOnly: true,
      language: language,
      regionCode: regionCode,
    );
    _pendingFeaturedProducts[cacheKey] = pending;
    try {
      final products = List<ProductModel>.unmodifiable(await pending);
      _cachedFeaturedProducts[cacheKey] = products;
      _cachedFeaturedProductsAt[cacheKey] = DateTime.now();
      return products;
    } finally {
      if (identical(_pendingFeaturedProducts[cacheKey], pending)) {
        _pendingFeaturedProducts.remove(cacheKey);
      }
    }
  }

  Future<ProductDetailModel> fetchProductDetail(
    int productId, {
    String? language,
    String? regionCode,
  }) async {
    final uri = ApiConstants.endpoint(
      '/products/$productId',
      queryParameters: {
        if ((language ?? '').trim().isNotEmpty) 'language': language!.trim(),
        if ((regionCode ?? '').trim().isNotEmpty)
          'region_code': regionCode!.trim(),
      },
    );
    final response = await http.get(uri, headers: await _buildHeaders());
    final decoded = await _decodeObjectResponse(response, 'product details');
    return ProductDetailModel.fromJson(decoded);
  }

  Future<List<ProductModel>> searchDiscoveryProducts({
    required String query,
    int? categoryId,
    int? branchId,
    String? language,
    String? regionCode,
    List<int> filterValueIds = const <int>[],
  }) async {
    final uri = ApiConstants.endpoint(
      '/discovery/search',
      queryParameters: {
        'q': query.trim(),
        if (categoryId != null) 'category_id': categoryId,
        if (branchId != null) 'branch_id': branchId,
        if ((language ?? '').trim().isNotEmpty) 'language': language!.trim(),
        if ((regionCode ?? '').trim().isNotEmpty)
          'region_code': regionCode!.trim(),
        if (filterValueIds.isNotEmpty)
          'filter_value_ids': filterValueIds.join(','),
      },
    );
    final response = await http.get(uri, headers: await _buildHeaders());
    final decoded = await _decodeObjectResponse(response, 'discovery search');
    final items = decoded['items'];
    if (items is! List) {
      throw Exception('Invalid discovery search payload');
    }
    return items
        .whereType<Map<String, dynamic>>()
        .map(ProductModel.fromJson)
        .toList();
  }

  Future<List<ProductModel>> fetchCategoryDiscoveryProducts(
    int categoryId, {
    int? branchId,
    String? language,
    String? regionCode,
    String? query,
    List<int> filterValueIds = const <int>[],
  }) async {
    final uri = ApiConstants.endpoint(
      '/discovery/categories/$categoryId/products',
      queryParameters: {
        if (branchId != null) 'branch_id': branchId,
        if ((language ?? '').trim().isNotEmpty) 'language': language!.trim(),
        if ((regionCode ?? '').trim().isNotEmpty)
          'region_code': regionCode!.trim(),
        if ((query ?? '').trim().isNotEmpty) 'q': query!.trim(),
        if (filterValueIds.isNotEmpty)
          'filter_value_ids': filterValueIds.join(','),
      },
    );
    final response = await http.get(uri, headers: await _buildHeaders());
    final decoded = await _decodeObjectResponse(
      response,
      'category discovery products',
    );
    final items = decoded['items'];
    if (items is! List) {
      throw Exception('Invalid category discovery payload');
    }
    return items
        .whereType<Map<String, dynamic>>()
        .map(ProductModel.fromJson)
        .toList();
  }

  Future<List<SearchTermModel>> fetchPopularSearchTerms({
    String? type,
  }) async {
    final uri = ApiConstants.endpoint(
      '/discovery/popular-searches',
      queryParameters: {
        if ((type ?? '').trim().isNotEmpty) 'type': type!.trim(),
      },
    );
    final response = await http.get(uri, headers: await _buildHeaders());
    final decoded = await _decodeObjectResponse(response, 'popular searches');
    final items = decoded['items'];
    if (items is! List) {
      throw Exception('Invalid popular searches payload');
    }
    return items
        .whereType<Map<String, dynamic>>()
        .map(SearchTermModel.fromJson)
        .toList();
  }

  Future<List<DiscoveryFilterGroupModel>> fetchDiscoveryFilters({
    int? categoryId,
    int? branchId,
    String? language,
    String? regionCode,
    String? query,
  }) async {
    final uri = ApiConstants.endpoint(
      '/discovery/filters',
      queryParameters: {
        if (categoryId != null) 'category_id': categoryId,
        if (branchId != null) 'branch_id': branchId,
        if ((language ?? '').trim().isNotEmpty) 'language': language!.trim(),
        if ((regionCode ?? '').trim().isNotEmpty)
          'region_code': regionCode!.trim(),
        if ((query ?? '').trim().isNotEmpty) 'q': query!.trim(),
      },
    );
    final response = await http.get(uri, headers: await _buildHeaders());
    final decoded = await _decodeObjectResponse(response, 'discovery filters');
    final items = decoded['items'];
    if (items is! List) {
      throw Exception('Invalid discovery filters payload');
    }
    return items
        .whereType<Map<String, dynamic>>()
        .map(DiscoveryFilterGroupModel.fromJson)
        .toList();
  }

  Future<List<ReviewModel>> fetchProductReviews(int productId) async {
    final uri = ApiConstants.endpoint('/reviews/product/$productId');
    final response = await http.get(uri, headers: await _buildHeaders());
    final decoded = await _decodeObjectResponse(response, 'reviews');
    final items = decoded['items'];
    if (items is! List) {
      throw Exception('Invalid reviews payload');
    }
    return items
        .whereType<Map<String, dynamic>>()
        .map(ReviewModel.fromJson)
        .toList();
  }

  Future<ReviewModel> submitReview({
    required int productId,
    required int rating,
    int? orderId,
    String? title,
    String? body,
  }) async {
    final uri = ApiConstants.endpoint('/reviews/');
    final response = await http.post(
      uri,
      headers: await _buildHeaders(json: true),
      body: jsonEncode({
        'product_id': productId,
        'rating': rating,
        if (orderId != null) 'order_id': orderId,
        if ((title ?? '').trim().isNotEmpty) 'title': title!.trim(),
        if ((body ?? '').trim().isNotEmpty) 'body': body!.trim(),
      }),
    );
    final decoded = await _decodeObjectResponse(response, 'review');
    return ReviewModel.fromJson(
      (decoded['review'] as Map?)?.cast<String, dynamic>() ??
          const <String, dynamic>{},
    );
  }

  Future<List<WishlistItemModel>> fetchWishlist() async {
    final uri = ApiConstants.endpoint('/wishlist/');
    final response = await http.get(uri, headers: await _buildHeaders());
    final decoded = await _decodeObjectResponse(response, 'wishlist');
    final items = decoded['items'];
    if (items is! List) {
      throw Exception('Invalid wishlist payload');
    }
    final wishlistItems = items
        .whereType<Map<String, dynamic>>()
        .map(WishlistItemModel.fromJson)
        .toList();
    _setWishlistIds(wishlistItems.map((item) => item.productId).toSet());
    return wishlistItems;
  }

  Future<WishlistItemModel?> addWishlistItem(int productId) async {
    final uri = ApiConstants.endpoint('/wishlist/$productId');
    final response = await http.post(uri, headers: await _buildHeaders());
    final decoded = await _decodeObjectResponse(response, 'wishlist');
    final item = decoded['item'];
    if (item is! Map<String, dynamic>) {
      return null;
    }
    final wishlistItem = WishlistItemModel.fromJson(item);
    final updatedIds = Set<int>.from(wishlistIdsListenable.value)
      ..add(wishlistItem.productId);
    _setWishlistIds(updatedIds);
    return wishlistItem;
  }

  Future<void> removeWishlistItem(int productId) async {
    final uri = ApiConstants.endpoint('/wishlist/$productId');
    final response = await http.delete(uri, headers: await _buildHeaders());
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _apiExceptionFromResponse(
          response, 'Failed to remove wishlist item');
    }
    final updatedIds = Set<int>.from(wishlistIdsListenable.value)
      ..remove(productId);
    _setWishlistIds(updatedIds);
  }

  Future<void> refreshWishlistIds() async {
    if (!await hasAuthSession()) {
      _setWishlistIds(<int>{});
      return;
    }

    try {
      await fetchWishlist();
    } catch (_) {
      _setWishlistIds(<int>{});
    }
  }

  Future<CartModel> fetchCart() async {
    final uri = ApiConstants.endpoint('/cart/');
    final response = await http.get(uri, headers: await _buildHeaders());
    final decoded = await _decodeResponse(response, 'cart');
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Invalid cart payload');
    }
    final cart = CartModel.fromJson(decoded);
    _setCartCount(cart.totalQuantity);
    return cart;
  }

  Future<CartModel> addToCart({
    required int productId,
    int quantity = 1,
    int? branchId,
  }) async {
    final uri = ApiConstants.endpoint('/cart/items');
    final response = await http.post(
      uri,
      headers: await _buildHeaders(json: true),
      body: jsonEncode({
        'product_id': productId,
        'quantity': quantity,
        if (branchId != null) 'branch_id': branchId,
      }),
    );
    final decoded = await _decodeResponse(response, 'cart');
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Invalid cart payload');
    }
    final cart = CartModel.fromJson(decoded);
    _setCartCount(cart.totalQuantity);
    return cart;
  }

  Future<CartModel> updateCartItem({
    required int itemId,
    required int quantity,
    int? branchId,
  }) async {
    final uri = ApiConstants.endpoint('/cart/items/$itemId');
    final response = await http.patch(
      uri,
      headers: await _buildHeaders(json: true),
      body: jsonEncode({
        'quantity': quantity,
        if (branchId != null) 'branch_id': branchId,
      }),
    );
    final decoded = await _decodeResponse(response, 'cart');
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Invalid cart payload');
    }
    final cart = CartModel.fromJson(decoded);
    _setCartCount(cart.totalQuantity);
    return cart;
  }

  Future<CartModel> removeCartItem(int itemId) async {
    final uri = ApiConstants.endpoint('/cart/items/$itemId');
    final response = await http.delete(uri, headers: await _buildHeaders());
    final cart = CartModel.fromJson(
      await _decodeObjectResponse(response, 'cart'),
    );
    _setCartCount(cart.totalQuantity);
    return cart;
  }

  Future<UserModel> register({
    required String fullName,
    required String email,
    required String password,
    String? phone,
  }) async {
    final uri = ApiConstants.endpoint('/auth/register');
    final response = await http.post(
      uri,
      headers: await _buildHeaders(json: true),
      body: jsonEncode({
        'full_name': fullName,
        'email': email,
        'password': password,
        if ((phone ?? '').trim().isNotEmpty) 'phone': phone!.trim(),
      }),
    );
    final decoded = await _decodeObjectResponse(response, 'auth');
    final token = (decoded['access_token'] as String? ?? '').trim();
    final user = UserModel.fromJson(
      (decoded['user'] as Map?)?.cast<String, dynamic>() ??
          const <String, dynamic>{},
    );
    if (token.isEmpty || user.id == 0) {
      throw Exception('Invalid authentication payload');
    }
    await _persistAuthSession(token: token, user: user);
    return user;
  }

  Future<UserModel> login({
    required String email,
    required String password,
  }) async {
    final uri = ApiConstants.endpoint('/auth/login');
    final response = await http.post(
      uri,
      headers: await _buildHeaders(json: true),
      body: jsonEncode({
        'email': email.trim(),
        'password': password,
      }),
    );
    final decoded = await _decodeObjectResponse(response, 'auth');
    final token = (decoded['access_token'] as String? ?? '').trim();
    final user = UserModel.fromJson(
      (decoded['user'] as Map?)?.cast<String, dynamic>() ??
          const <String, dynamic>{},
    );
    if (token.isEmpty || user.id == 0) {
      throw Exception('Invalid authentication payload');
    }
    await _persistAuthSession(token: token, user: user);
    await refreshWishlistIds();
    return user;
  }

  Future<UserModel?> getStoredUser() async {
    try {
      final raw = await _readSecureValue(_storedUserKey);
      if (raw == null || raw.trim().isEmpty) {
        return null;
      }

      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      final user = UserModel.fromJson(decoded);
      return user.id == 0 ? null : user;
    } catch (_) {
      return null;
    }
  }

  Future<bool> hasAuthSession() async {
    try {
      final token = await _readAuthToken();
      return token != null && token.trim().isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<UserModel> fetchProfile() async {
    final uri = ApiConstants.endpoint('/auth/profile');
    final response = await http.get(uri, headers: await _buildHeaders());
    if (response.statusCode == 401) {
      await _clearAuthSession();
    }
    final decoded = await _decodeObjectResponse(response, 'profile');
    final user = UserModel.fromJson(
      (decoded['user'] as Map?)?.cast<String, dynamic>() ??
          const <String, dynamic>{},
    );
    if (user.id == 0) {
      throw Exception('Invalid profile payload');
    }
    await _writeSecureValue(_storedUserKey, jsonEncode(user.toJson()));
    return user;
  }

  Future<void> logout() async {
    await _clearAuthSession();
    _setCartCount(0);
    _setWishlistIds(<int>{});
  }

  Future<UserModel> updateProfile({
    required String fullName,
    required String phone,
  }) async {
    final uri = ApiConstants.endpoint('/auth/profile');
    final response = await http.patch(
      uri,
      headers: await _buildHeaders(json: true),
      body: jsonEncode({
        'full_name': fullName.trim(),
        'phone': phone.trim(),
      }),
    );
    final decoded = await _decodeObjectResponse(response, 'profile');
    final user = UserModel.fromJson(
      (decoded['user'] as Map?)?.cast<String, dynamic>() ??
          const <String, dynamic>{},
    );
    if (user.id == 0) {
      throw Exception('Invalid profile payload');
    }
    await _writeSecureValue(_storedUserKey, jsonEncode(user.toJson()));
    return user;
  }

  Future<OrderModel> placeOrder({
    required String orderType,
    required int branchId,
    required String paymentMethod,
    required String notes,
    int? addressId,
    Map<String, String>? address,
  }) async {
    final uri = ApiConstants.endpoint('/orders/');
    final response = await http.post(
      uri,
      headers: await _buildHeaders(json: true),
      body: jsonEncode({
        'order_type': orderType,
        'branch_id': branchId,
        'payment_method': paymentMethod,
        'notes': notes.trim(),
        if (addressId != null) 'address_id': addressId,
        if (address != null) 'address': address,
      }),
    );
    final decoded = await _decodeObjectResponse(response, 'order');
    final order = OrderModel.fromJson(
      (decoded['order'] as Map?)?.cast<String, dynamic>() ??
          const <String, dynamic>{},
    );
    _setCartCount(0);
    return order;
  }

  Future<List<OrderModel>> fetchOrders() async {
    final uri = ApiConstants.endpoint('/orders/');
    final response = await http.get(uri, headers: await _buildHeaders());
    final decoded = await _decodeObjectResponse(response, 'orders');
    final items = decoded['items'];
    if (items is! List) {
      throw Exception('Invalid orders payload');
    }
    return items
        .whereType<Map<String, dynamic>>()
        .map(OrderModel.fromJson)
        .toList();
  }

  Future<OrderModel> fetchOrderDetails(int orderId) async {
    final uri = ApiConstants.endpoint('/orders/$orderId');
    final response = await http.get(uri, headers: await _buildHeaders());
    final decoded = await _decodeObjectResponse(response, 'order');
    return OrderModel.fromJson(
      (decoded['order'] as Map?)?.cast<String, dynamic>() ??
          const <String, dynamic>{},
    );
  }
}
