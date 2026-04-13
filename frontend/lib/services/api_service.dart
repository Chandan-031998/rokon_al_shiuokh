import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants/api_constants.dart';
import '../models/branch_model.dart';
import '../models/cart_model.dart';
import '../models/category_model.dart';
import '../models/order_model.dart';
import '../models/product_model.dart';
import '../models/user_model.dart';

class ApiService {
  const ApiService();

  static const _guestSessionKey = 'guest_session_id';
  static const _authTokenKey = 'auth_token';
  static const _storedUserKey = 'auth_user_json';
  static const _guestHeader = 'X-Guest-Session-ID';
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  Future<String?> _readAuthToken() {
    return _secureStorage.read(key: _authTokenKey);
  }

  Future<void> _persistAuthSession({
    required String token,
    required UserModel user,
  }) async {
    await _secureStorage.write(key: _authTokenKey, value: token);
    await _secureStorage.write(
      key: _storedUserKey,
      value: jsonEncode(user.toJson()),
    );
  }

  Future<void> _clearAuthSession() async {
    await _secureStorage.delete(key: _authTokenKey);
    await _secureStorage.delete(key: _storedUserKey);
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

  Future<List<CategoryModel>> fetchCategories() async {
    final uri = ApiConstants.endpoint('/categories/');
    final response = await http.get(uri, headers: await _buildHeaders());
    final decoded = await _decodeResponse(response, 'categories');
    if (decoded is! List) {
      throw Exception('Invalid categories payload');
    }

    return decoded
        .whereType<Map<String, dynamic>>()
        .map(CategoryModel.fromJson)
        .toList();
  }

  Future<List<BranchModel>> fetchBranches() async {
    final uri = ApiConstants.endpoint('/branches/');
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

  Future<List<ProductModel>> fetchProducts({
    int? categoryId,
    int? branchId,
    String? query,
    bool featuredOnly = false,
  }) async {
    final uri = featuredOnly
        ? ApiConstants.endpoint('/products/featured')
        : ApiConstants.endpoint(
            '/products/',
            queryParameters: {
              if (categoryId != null) 'category_id': categoryId,
              if (branchId != null) 'branch_id': branchId,
              if ((query ?? '').trim().isNotEmpty) 'q': query!.trim(),
            },
          );

    final response = await http.get(uri, headers: await _buildHeaders());
    final decoded = await _decodeResponse(response, 'products');
    if (decoded is! List) {
      throw Exception('Invalid products payload');
    }

    return decoded
        .whereType<Map<String, dynamic>>()
        .map(ProductModel.fromJson)
        .toList();
  }

  Future<List<ProductModel>> fetchFeaturedProducts() {
    return fetchProducts(featuredOnly: true);
  }

  Future<CartModel> fetchCart() async {
    final uri = ApiConstants.endpoint('/cart/');
    final response = await http.get(uri, headers: await _buildHeaders());
    final decoded = await _decodeResponse(response, 'cart');
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Invalid cart payload');
    }
    return CartModel.fromJson(decoded);
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
    return CartModel.fromJson(decoded);
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
    return CartModel.fromJson(decoded);
  }

  Future<CartModel> removeCartItem(int itemId) async {
    final uri = ApiConstants.endpoint('/cart/items/$itemId');
    final response = await http.delete(uri, headers: await _buildHeaders());
    return CartModel.fromJson(await _decodeObjectResponse(response, 'cart'));
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
    return user;
  }

  Future<UserModel?> getStoredUser() async {
    final raw = await _secureStorage.read(key: _storedUserKey);
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }

    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      return null;
    }
    return UserModel.fromJson(decoded);
  }

  Future<bool> hasAuthSession() async {
    final token = await _readAuthToken();
    return token != null && token.trim().isNotEmpty;
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
    await _secureStorage.write(
      key: _storedUserKey,
      value: jsonEncode(user.toJson()),
    );
    return user;
  }

  Future<void> logout() async {
    await _clearAuthSession();
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
    await _secureStorage.write(
      key: _storedUserKey,
      value: jsonEncode(user.toJson()),
    );
    return user;
  }

  Future<OrderModel> placeOrder({
    required String orderType,
    required int branchId,
    required String notes,
    Map<String, String>? address,
  }) async {
    final uri = ApiConstants.endpoint('/orders/');
    final response = await http.post(
      uri,
      headers: await _buildHeaders(json: true),
      body: jsonEncode({
        'order_type': orderType,
        'branch_id': branchId,
        'notes': notes.trim(),
        if (address != null) 'address': address,
      }),
    );
    final decoded = await _decodeObjectResponse(response, 'order');
    return OrderModel.fromJson(
      (decoded['order'] as Map?)?.cast<String, dynamic>() ??
          const <String, dynamic>{},
    );
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
