import 'package:flutter/foundation.dart';

import '../../models/user_model.dart';
import 'services/admin_api_service.dart';

class AdminSessionController extends ChangeNotifier {
  final AdminApiService apiService;

  AdminSessionController({
    this.apiService = const AdminApiService(),
  });

  bool _isLoaded = false;
  bool _isBusy = false;
  UserModel? _user;

  bool get isLoaded => _isLoaded;
  bool get isBusy => _isBusy;
  UserModel? get user => _user;
  bool get isAuthenticated => _user?.role == 'admin';

  Future<void> load() async {
    _isBusy = true;
    notifyListeners();
    try {
      _user = await apiService.getStoredUser();
      if (await apiService.hasSession()) {
        _user = await apiService.fetchMe();
      }
    } catch (_) {
      await apiService.clearSession();
      _user = null;
    } finally {
      _isLoaded = true;
      _isBusy = false;
      notifyListeners();
    }
  }

  Future<void> login({
    required String email,
    required String password,
  }) async {
    _isBusy = true;
    notifyListeners();
    try {
      _user = await apiService.login(email: email, password: password);
    } finally {
      _isLoaded = true;
      _isBusy = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    await apiService.clearSession();
    _user = null;
    _isLoaded = true;
    notifyListeners();
  }
}
