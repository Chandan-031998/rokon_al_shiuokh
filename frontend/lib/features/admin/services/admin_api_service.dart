import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart' as http_parser;

import '../../../core/constants/api_constants.dart';
import '../../../models/branch_model.dart';
import '../../../models/category_model.dart';
import '../../../models/discovery_filter_models.dart';
import '../../../models/order_model.dart';
import '../../../models/product_model.dart';
import '../../../models/search_term_model.dart';
import '../../../models/user_model.dart';
import '../models/admin_dashboard_model.dart';
import '../models/admin_cms_page_model.dart';
import '../models/admin_faq_model.dart';
import '../models/admin_import_result.dart';
import '../models/admin_offer_model.dart';
import '../models/admin_review_model.dart';
import '../models/admin_support_settings_model.dart';

class AdminApiService {
  const AdminApiService();

  static const _tokenKey = 'admin_auth_token';
  static const _userKey = 'admin_auth_user_json';
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  Future<String?> _readToken() => _secureStorage.read(key: _tokenKey);

  Future<void> _persistSession({
    required String token,
    required UserModel user,
  }) async {
    await _secureStorage.write(key: _tokenKey, value: token);
    await _secureStorage.write(key: _userKey, value: jsonEncode(user.toJson()));
  }

  Future<void> clearSession() async {
    await _secureStorage.delete(key: _tokenKey);
    await _secureStorage.delete(key: _userKey);
  }

  Future<UserModel?> getStoredUser() async {
    final raw = await _secureStorage.read(key: _userKey);
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      return null;
    }
    return UserModel.fromJson(decoded);
  }

  Future<bool> hasSession() async {
    final token = await _readToken();
    return token != null && token.trim().isNotEmpty;
  }

  Future<Map<String, String>> _headers({bool json = false}) async {
    final token = (await _readToken())?.trim();
    final headers = <String, String>{};
    if (json) {
      headers['Content-Type'] = 'application/json';
    }
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  Future<Map<String, dynamic>> _decodeObject(
      http.Response response, String label) async {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _apiException(response, 'Failed to load $label');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Invalid $label payload');
    }
    return decoded;
  }

  Future<List<Map<String, dynamic>>> _decodeItems(
      http.Response response, String label) async {
    final decoded = await _decodeObject(response, label);
    final items = decoded['items'];
    if (items is! List) {
      throw Exception('Invalid $label payload');
    }
    return items.whereType<Map<String, dynamic>>().toList();
  }

  Exception _apiException(http.Response response, String fallback) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        final error = (decoded['error'] as String?)?.trim();
        if (error != null && error.isNotEmpty) {
          return Exception(error);
        }
      }
    } catch (_) {
      // Ignore malformed error payloads.
    }
    return Exception(fallback);
  }

  Future<UserModel> login({
    required String email,
    required String password,
  }) async {
    final uri = ApiConstants.endpoint('/admin/auth/login');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email.trim(),
        'password': password,
      }),
    );
    final decoded = await _decodeObject(response, 'admin auth');
    final token = (decoded['access_token'] as String? ?? '').trim();
    final user = UserModel.fromJson(
      (decoded['user'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
    if (token.isEmpty || user.role != 'admin') {
      throw Exception('Invalid admin session.');
    }
    await _persistSession(token: token, user: user);
    return user;
  }

  Future<UserModel> fetchMe() async {
    final uri = ApiConstants.endpoint('/admin/auth/me');
    final response = await http.get(uri, headers: await _headers());
    if (response.statusCode == 401 || response.statusCode == 403) {
      await clearSession();
    }
    final decoded = await _decodeObject(response, 'admin profile');
    final user = UserModel.fromJson(
      (decoded['user'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
    if (user.role != 'admin') {
      throw Exception('Admin access is required.');
    }
    await _secureStorage.write(key: _userKey, value: jsonEncode(user.toJson()));
    return user;
  }

  Future<AdminDashboardSummary> fetchDashboardSummary() async {
    final uri = ApiConstants.endpoint('/admin/dashboard/summary');
    final response = await http.get(uri, headers: await _headers());
    final decoded = await _decodeObject(response, 'dashboard');
    return AdminDashboardSummary.fromJson(
      (decoded['summary'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
  }

  Future<List<ProductModel>> fetchProducts({
    String? search,
    int? categoryId,
    int? branchId,
  }) async {
    final uri = ApiConstants.endpoint(
      '/admin/products',
      queryParameters: {
        if ((search ?? '').trim().isNotEmpty) 'search': search!.trim(),
        if (categoryId != null) 'category_id': categoryId,
        if (branchId != null) 'branch_id': branchId,
      },
    );
    final response = await http.get(uri, headers: await _headers());
    final items = await _decodeItems(response, 'products');
    return items.map(ProductModel.fromJson).toList();
  }

  Future<ProductModel> createProduct(Map<String, dynamic> payload) async {
    final uri = ApiConstants.endpoint('/admin/products');
    final response = await http.post(
      uri,
      headers: await _headers(json: true),
      body: jsonEncode(payload),
    );
    final decoded = await _decodeObject(response, 'product');
    return ProductModel.fromJson(
      (decoded['product'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
  }

  Future<ProductModel> updateProduct(
      int productId, Map<String, dynamic> payload) async {
    final uri = ApiConstants.endpoint('/admin/products/$productId');
    final response = await http.patch(
      uri,
      headers: await _headers(json: true),
      body: jsonEncode(payload),
    );
    final decoded = await _decodeObject(response, 'product');
    return ProductModel.fromJson(
      (decoded['product'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
  }

  Future<void> deleteProduct(int productId) async {
    final uri = ApiConstants.endpoint('/admin/products/$productId');
    final response = await http.delete(uri, headers: await _headers());
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _apiException(response, 'Failed to delete product');
    }
  }

  Future<List<CategoryModel>> fetchCategories() async {
    final uri = ApiConstants.endpoint('/admin/categories');
    final response = await http.get(uri, headers: await _headers());
    final items = await _decodeItems(response, 'categories');
    return items.map(CategoryModel.fromJson).toList();
  }

  Future<CategoryModel> createCategory(Map<String, dynamic> payload) async {
    final uri = ApiConstants.endpoint('/admin/categories');
    final response = await http.post(
      uri,
      headers: await _headers(json: true),
      body: jsonEncode(payload),
    );
    final decoded = await _decodeObject(response, 'category');
    return CategoryModel.fromJson(
      (decoded['category'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
  }

  Future<CategoryModel> updateCategory(
      int categoryId, Map<String, dynamic> payload) async {
    final uri = ApiConstants.endpoint('/admin/categories/$categoryId');
    final response = await http.patch(
      uri,
      headers: await _headers(json: true),
      body: jsonEncode(payload),
    );
    final decoded = await _decodeObject(response, 'category');
    return CategoryModel.fromJson(
      (decoded['category'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
  }

  Future<void> deleteCategory(int categoryId) async {
    final uri = ApiConstants.endpoint('/admin/categories/$categoryId');
    final response = await http.delete(uri, headers: await _headers());
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _apiException(response, 'Failed to delete category');
    }
  }

  Future<List<BranchModel>> fetchBranches() async {
    final uri = ApiConstants.endpoint('/admin/branches');
    final response = await http.get(uri, headers: await _headers());
    final items = await _decodeItems(response, 'branches');
    return items.map(BranchModel.fromJson).toList();
  }

  Future<BranchModel> createBranch(Map<String, dynamic> payload) async {
    final uri = ApiConstants.endpoint('/admin/branches');
    final response = await http.post(
      uri,
      headers: await _headers(json: true),
      body: jsonEncode(payload),
    );
    final decoded = await _decodeObject(response, 'branch');
    return BranchModel.fromJson(
      (decoded['branch'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
  }

  Future<BranchModel> updateBranch(
      int branchId, Map<String, dynamic> payload) async {
    final uri = ApiConstants.endpoint('/admin/branches/$branchId');
    final response = await http.patch(
      uri,
      headers: await _headers(json: true),
      body: jsonEncode(payload),
    );
    final decoded = await _decodeObject(response, 'branch');
    return BranchModel.fromJson(
      (decoded['branch'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
  }

  Future<void> deleteBranch(int branchId) async {
    final uri = ApiConstants.endpoint('/admin/branches/$branchId');
    final response = await http.delete(uri, headers: await _headers());
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _apiException(response, 'Failed to delete branch');
    }
  }

  Future<List<OrderModel>> fetchOrders({
    String? search,
    String? status,
    int? branchId,
    String? dateFrom,
    String? dateTo,
  }) async {
    final uri = ApiConstants.endpoint(
      '/admin/orders',
      queryParameters: {
        if ((search ?? '').trim().isNotEmpty) 'search': search!.trim(),
        if ((status ?? '').trim().isNotEmpty) 'status': status!.trim(),
        if (branchId != null) 'branch_id': branchId,
        if ((dateFrom ?? '').trim().isNotEmpty) 'date_from': dateFrom!.trim(),
        if ((dateTo ?? '').trim().isNotEmpty) 'date_to': dateTo!.trim(),
      },
    );
    final response = await http.get(uri, headers: await _headers());
    final items = await _decodeItems(response, 'orders');
    return items.map(OrderModel.fromJson).toList();
  }

  Future<OrderModel> fetchOrder(int orderId) async {
    final uri = ApiConstants.endpoint('/admin/orders/$orderId');
    final response = await http.get(uri, headers: await _headers());
    final decoded = await _decodeObject(response, 'order');
    return OrderModel.fromJson(
      (decoded['order'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
  }

  Future<OrderModel> updateOrder(
      int orderId, Map<String, dynamic> payload) async {
    final uri = ApiConstants.endpoint('/admin/orders/$orderId');
    final response = await http.patch(
      uri,
      headers: await _headers(json: true),
      body: jsonEncode(payload),
    );
    final decoded = await _decodeObject(response, 'order');
    return OrderModel.fromJson(
      (decoded['order'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
  }

  Future<List<UserModel>> fetchCustomers({String? search}) async {
    final uri = ApiConstants.endpoint(
      '/admin/customers',
      queryParameters: {
        if ((search ?? '').trim().isNotEmpty) 'search': search!.trim(),
      },
    );
    final response = await http.get(uri, headers: await _headers());
    final items = await _decodeItems(response, 'customers');
    return items.map(UserModel.fromJson).toList();
  }

  Future<UserModel> fetchCustomer(int customerId) async {
    final uri = ApiConstants.endpoint('/admin/customers/$customerId');
    final response = await http.get(uri, headers: await _headers());
    final decoded = await _decodeObject(response, 'customer');
    return UserModel.fromJson(
      (decoded['customer'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
  }

  Future<List<OrderModel>> fetchDeliveries({
    String? search,
    String? status,
    int? branchId,
  }) async {
    final uri = ApiConstants.endpoint(
      '/admin/deliveries',
      queryParameters: {
        if ((search ?? '').trim().isNotEmpty) 'search': search!.trim(),
        if ((status ?? '').trim().isNotEmpty) 'status': status!.trim(),
        if (branchId != null) 'branch_id': branchId,
      },
    );
    final response = await http.get(uri, headers: await _headers());
    final items = await _decodeItems(response, 'deliveries');
    return items.map(OrderModel.fromJson).toList();
  }

  Future<OrderModel> updateDelivery(
      int orderId, Map<String, dynamic> payload) async {
    final uri = ApiConstants.endpoint('/admin/deliveries/$orderId');
    final response = await http.patch(
      uri,
      headers: await _headers(json: true),
      body: jsonEncode(payload),
    );
    final decoded = await _decodeObject(response, 'delivery');
    return OrderModel.fromJson(
      (decoded['order'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
  }

  Future<OrderModel> fetchDelivery(int orderId) async {
    final uri = ApiConstants.endpoint('/admin/deliveries/$orderId');
    final response = await http.get(uri, headers: await _headers());
    final decoded = await _decodeObject(response, 'delivery');
    return OrderModel.fromJson(
      (decoded['order'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
  }

  Future<List<AdminReviewModel>> fetchReviews({
    int? productId,
    int? rating,
    String? status,
  }) async {
    final uri = ApiConstants.endpoint(
      '/admin/reviews',
      queryParameters: {
        if (productId != null) 'product_id': productId,
        if (rating != null) 'rating': rating,
        if ((status ?? '').trim().isNotEmpty) 'status': status!.trim(),
      },
    );
    final response = await http.get(uri, headers: await _headers());
    final items = await _decodeItems(response, 'reviews');
    return items.map(AdminReviewModel.fromJson).toList();
  }

  Future<AdminReviewModel> fetchReview(int reviewId) async {
    final uri = ApiConstants.endpoint('/admin/reviews/$reviewId');
    final response = await http.get(uri, headers: await _headers());
    final decoded = await _decodeObject(response, 'review');
    return AdminReviewModel.fromJson(
      (decoded['review'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
  }

  Future<AdminReviewModel> updateReview(
      int reviewId, Map<String, dynamic> payload) async {
    final uri = ApiConstants.endpoint('/admin/reviews/$reviewId');
    final response = await http.patch(
      uri,
      headers: await _headers(json: true),
      body: jsonEncode(payload),
    );
    final decoded = await _decodeObject(response, 'review');
    return AdminReviewModel.fromJson(
      (decoded['review'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
  }

  Future<void> deleteReview(int reviewId) async {
    final uri = ApiConstants.endpoint('/admin/reviews/$reviewId');
    final response = await http.delete(uri, headers: await _headers());
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _apiException(response, 'Failed to delete review');
    }
  }

  Future<List<AdminOfferModel>> fetchOffers() async {
    final uri = ApiConstants.endpoint('/admin/offers');
    final response = await http.get(uri, headers: await _headers());
    final items = await _decodeItems(response, 'offers');
    return items.map(AdminOfferModel.fromJson).toList();
  }

  Future<List<ProductModel>> fetchDiscoveryProducts({
    String? search,
    bool? hidden,
  }) async {
    final uri = ApiConstants.endpoint(
      '/admin/discovery/products',
      queryParameters: {
        if ((search ?? '').trim().isNotEmpty) 'search': search!.trim(),
        if (hidden != null) 'hidden': hidden,
      },
    );
    final response = await http.get(uri, headers: await _headers());
    final items = await _decodeItems(response, 'discovery products');
    return items.map(ProductModel.fromJson).toList();
  }

  Future<ProductModel> updateDiscoveryProduct(
    int productId,
    Map<String, dynamic> payload,
  ) async {
    final uri = ApiConstants.endpoint('/admin/discovery/products/$productId');
    final response = await http.patch(
      uri,
      headers: await _headers(json: true),
      body: jsonEncode(payload),
    );
    final decoded = await _decodeObject(response, 'discovery product');
    return ProductModel.fromJson(
      (decoded['product'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
  }

  Future<List<SearchTermModel>> fetchSearchTerms() async {
    final uri = ApiConstants.endpoint('/admin/discovery/search-terms');
    final response = await http.get(uri, headers: await _headers());
    final items = await _decodeItems(response, 'search terms');
    return items.map(SearchTermModel.fromJson).toList();
  }

  Future<SearchTermModel> createSearchTerm(Map<String, dynamic> payload) async {
    final uri = ApiConstants.endpoint('/admin/discovery/search-terms');
    final response = await http.post(
      uri,
      headers: await _headers(json: true),
      body: jsonEncode(payload),
    );
    final decoded = await _decodeObject(response, 'search term');
    return SearchTermModel.fromJson(
      (decoded['term'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
  }

  Future<SearchTermModel> updateSearchTerm(
    int termId,
    Map<String, dynamic> payload,
  ) async {
    final uri = ApiConstants.endpoint('/admin/discovery/search-terms/$termId');
    final response = await http.patch(
      uri,
      headers: await _headers(json: true),
      body: jsonEncode(payload),
    );
    final decoded = await _decodeObject(response, 'search term');
    return SearchTermModel.fromJson(
      (decoded['term'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
  }

  Future<void> deleteSearchTerm(int termId) async {
    final uri = ApiConstants.endpoint('/admin/discovery/search-terms/$termId');
    final response = await http.delete(uri, headers: await _headers());
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _apiException(response, 'Failed to delete search term');
    }
  }

  Future<List<DiscoveryFilterGroupModel>> fetchFilterGroups() async {
    final uri = ApiConstants.endpoint('/admin/discovery/filter-groups');
    final response = await http.get(uri, headers: await _headers());
    final items = await _decodeItems(response, 'filter groups');
    return items.map(DiscoveryFilterGroupModel.fromJson).toList();
  }

  Future<DiscoveryFilterGroupModel> createFilterGroup(
    Map<String, dynamic> payload,
  ) async {
    final uri = ApiConstants.endpoint('/admin/discovery/filter-groups');
    final response = await http.post(
      uri,
      headers: await _headers(json: true),
      body: jsonEncode(payload),
    );
    final decoded = await _decodeObject(response, 'filter group');
    return DiscoveryFilterGroupModel.fromJson(
      (decoded['group'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
  }

  Future<DiscoveryFilterGroupModel> updateFilterGroup(
    int groupId,
    Map<String, dynamic> payload,
  ) async {
    final uri = ApiConstants.endpoint('/admin/discovery/filter-groups/$groupId');
    final response = await http.patch(
      uri,
      headers: await _headers(json: true),
      body: jsonEncode(payload),
    );
    final decoded = await _decodeObject(response, 'filter group');
    return DiscoveryFilterGroupModel.fromJson(
      (decoded['group'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
  }

  Future<void> deleteFilterGroup(int groupId) async {
    final uri = ApiConstants.endpoint('/admin/discovery/filter-groups/$groupId');
    final response = await http.delete(uri, headers: await _headers());
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _apiException(response, 'Failed to delete filter group');
    }
  }

  Future<List<DiscoveryFilterValueModel>> fetchFilterValues({
    int? groupId,
  }) async {
    final uri = ApiConstants.endpoint(
      '/admin/discovery/filter-values',
      queryParameters: {
        if (groupId != null) 'group_id': groupId,
      },
    );
    final response = await http.get(uri, headers: await _headers());
    final items = await _decodeItems(response, 'filter values');
    return items.map(DiscoveryFilterValueModel.fromJson).toList();
  }

  Future<DiscoveryFilterValueModel> createFilterValue(
    Map<String, dynamic> payload,
  ) async {
    final uri = ApiConstants.endpoint('/admin/discovery/filter-values');
    final response = await http.post(
      uri,
      headers: await _headers(json: true),
      body: jsonEncode(payload),
    );
    final decoded = await _decodeObject(response, 'filter value');
    return DiscoveryFilterValueModel.fromJson(
      (decoded['value'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
  }

  Future<DiscoveryFilterValueModel> updateFilterValue(
    int valueId,
    Map<String, dynamic> payload,
  ) async {
    final uri = ApiConstants.endpoint('/admin/discovery/filter-values/$valueId');
    final response = await http.patch(
      uri,
      headers: await _headers(json: true),
      body: jsonEncode(payload),
    );
    final decoded = await _decodeObject(response, 'filter value');
    return DiscoveryFilterValueModel.fromJson(
      (decoded['value'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
  }

  Future<void> deleteFilterValue(int valueId) async {
    final uri = ApiConstants.endpoint('/admin/discovery/filter-values/$valueId');
    final response = await http.delete(uri, headers: await _headers());
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _apiException(response, 'Failed to delete filter value');
    }
  }

  Future<List<AdminCmsPageModel>> fetchCmsPages({
    String? section,
    String? search,
  }) async {
    final uri = ApiConstants.endpoint(
      '/admin/cms/pages',
      queryParameters: {
        if ((section ?? '').trim().isNotEmpty) 'section': section!.trim(),
        if ((search ?? '').trim().isNotEmpty) 'search': search!.trim(),
      },
    );
    final response = await http.get(uri, headers: await _headers());
    final items = await _decodeItems(response, 'cms pages');
    return items.map(AdminCmsPageModel.fromJson).toList();
  }

  Future<AdminCmsPageModel> createCmsPage(Map<String, dynamic> payload) async {
    final uri = ApiConstants.endpoint('/admin/cms/pages');
    final response = await http.post(
      uri,
      headers: await _headers(json: true),
      body: jsonEncode(payload),
    );
    final decoded = await _decodeObject(response, 'cms page');
    return AdminCmsPageModel.fromJson(
      (decoded['page'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
  }

  Future<AdminCmsPageModel> updateCmsPage(
      int pageId, Map<String, dynamic> payload) async {
    final uri = ApiConstants.endpoint('/admin/cms/pages/$pageId');
    final response = await http.patch(
      uri,
      headers: await _headers(json: true),
      body: jsonEncode(payload),
    );
    final decoded = await _decodeObject(response, 'cms page');
    return AdminCmsPageModel.fromJson(
      (decoded['page'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
  }

  Future<void> deleteCmsPage(int pageId) async {
    final uri = ApiConstants.endpoint('/admin/cms/pages/$pageId');
    final response = await http.delete(uri, headers: await _headers());
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _apiException(response, 'Failed to delete CMS page');
    }
  }

  Future<List<AdminFaqModel>> fetchFaqs() async {
    final uri = ApiConstants.endpoint('/admin/faqs');
    final response = await http.get(uri, headers: await _headers());
    final items = await _decodeItems(response, 'faqs');
    return items.map(AdminFaqModel.fromJson).toList();
  }

  Future<AdminFaqModel> createFaq(Map<String, dynamic> payload) async {
    final uri = ApiConstants.endpoint('/admin/faqs');
    final response = await http.post(
      uri,
      headers: await _headers(json: true),
      body: jsonEncode(payload),
    );
    final decoded = await _decodeObject(response, 'faq');
    return AdminFaqModel.fromJson(
      (decoded['faq'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
  }

  Future<AdminFaqModel> updateFaq(int faqId, Map<String, dynamic> payload) async {
    final uri = ApiConstants.endpoint('/admin/faqs/$faqId');
    final response = await http.patch(
      uri,
      headers: await _headers(json: true),
      body: jsonEncode(payload),
    );
    final decoded = await _decodeObject(response, 'faq');
    return AdminFaqModel.fromJson(
      (decoded['faq'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
  }

  Future<void> deleteFaq(int faqId) async {
    final uri = ApiConstants.endpoint('/admin/faqs/$faqId');
    final response = await http.delete(uri, headers: await _headers());
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _apiException(response, 'Failed to delete FAQ');
    }
  }

  Future<AdminSupportSettingsModel> fetchSupportSettings() async {
    final uri = ApiConstants.endpoint('/admin/support/settings');
    final response = await http.get(uri, headers: await _headers());
    final decoded = await _decodeObject(response, 'support settings');
    return AdminSupportSettingsModel.fromJson(
      (decoded['settings'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
  }

  Future<AdminSupportSettingsModel> updateSupportSettings(
      Map<String, dynamic> payload) async {
    final uri = ApiConstants.endpoint('/admin/support/settings');
    final response = await http.put(
      uri,
      headers: await _headers(json: true),
      body: jsonEncode(payload),
    );
    final decoded = await _decodeObject(response, 'support settings');
    return AdminSupportSettingsModel.fromJson(
      (decoded['settings'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
  }

  Future<AdminOfferModel> createOffer(Map<String, dynamic> payload) async {
    final uri = ApiConstants.endpoint('/admin/offers');
    final response = await http.post(
      uri,
      headers: await _headers(json: true),
      body: jsonEncode(payload),
    );
    final decoded = await _decodeObject(response, 'offer');
    return AdminOfferModel.fromJson(
      (decoded['offer'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
  }

  Future<AdminOfferModel> updateOffer(
      int offerId, Map<String, dynamic> payload) async {
    final uri = ApiConstants.endpoint('/admin/offers/$offerId');
    final response = await http.patch(
      uri,
      headers: await _headers(json: true),
      body: jsonEncode(payload),
    );
    final decoded = await _decodeObject(response, 'offer');
    return AdminOfferModel.fromJson(
      (decoded['offer'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
  }

  Future<void> deleteOffer(int offerId) async {
    final uri = ApiConstants.endpoint('/admin/offers/$offerId');
    final response = await http.delete(uri, headers: await _headers());
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _apiException(response, 'Failed to delete offer');
    }
  }

  Future<String> uploadProductImage({
    required Uint8List bytes,
    required String filename,
    required String contentType,
  }) async {
    final uri = ApiConstants.endpoint('/uploads/product-image');
    final request = http.MultipartRequest('POST', uri)
      ..headers.addAll(await _headers())
      ..files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: filename,
          contentType: _mediaType(contentType),
        ),
      );
    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    final decoded = await _decodeObject(response, 'upload');
    final url = (decoded['url'] as String? ?? '').trim();
    if (url.isEmpty) {
      throw Exception('Upload did not return a valid URL.');
    }
    return url;
  }

  Future<AdminImportResult> importProducts({
    required Uint8List bytes,
    required String filename,
  }) async {
    final uri = ApiConstants.endpoint('/admin/import/products');
    final request = http.MultipartRequest('POST', uri)
      ..headers.addAll(await _headers())
      ..files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: filename,
        ),
      );
    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    final decoded = await _decodeObject(response, 'import');
    return AdminImportResult.fromJson(
      (decoded['result'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
  }
}

http_parser.MediaType _mediaType(String contentType) {
  final parts = contentType.split('/');
  if (parts.length != 2) {
    return http_parser.MediaType('application', 'octet-stream');
  }
  return http_parser.MediaType(parts.first, parts.last);
}
