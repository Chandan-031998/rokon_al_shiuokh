import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppLocaleController extends ChangeNotifier {
  static const _localeKey = 'app_locale_code';
  static const _regionKey = 'app_region_code';

  Locale _locale = const Locale('en');
  String _regionCode = 'sa';
  final ValueNotifier<Locale> localeListenable =
      ValueNotifier<Locale>(const Locale('en'));

  Locale get locale => _locale;
  String get languageCode => _locale.languageCode;
  String get regionCode => _regionCode;
  bool get isArabic => _locale.languageCode == 'ar';
  String get currencyCode => _regionCode == 'ae' ? 'AED' : 'SAR';

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    var updated = false;
    final code = prefs.getString(_localeKey)?.trim();
    if (code == 'ar' || code == 'en') {
      _locale = Locale(code!);
      localeListenable.value = _locale;
      updated = true;
    }
    final region = prefs.getString(_regionKey)?.trim().toLowerCase();
    if (region == 'sa' || region == 'ae') {
      _regionCode = region!;
      updated = true;
    }
    if (updated) {
      notifyListeners();
    }
  }

  Future<void> setLocale(Locale locale) async {
    if (_locale.languageCode == locale.languageCode) {
      return;
    }

    _locale = Locale(locale.languageCode);
    localeListenable.value = _locale;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localeKey, locale.languageCode);
    notifyListeners();
  }

  Future<void> setRegionCode(String regionCode) async {
    final normalized = regionCode.trim().toLowerCase();
    if (normalized != 'sa' && normalized != 'ae') {
      return;
    }
    if (_regionCode == normalized) {
      return;
    }

    _regionCode = normalized;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_regionKey, normalized);
    notifyListeners();
  }

  @override
  void dispose() {
    localeListenable.dispose();
    super.dispose();
  }
}
