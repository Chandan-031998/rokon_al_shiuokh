import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../navigation/app_shell.dart';
import '../splash/splash_screen.dart';
import '../../localization/app_locale_controller.dart';

class CustomerEntry extends StatefulWidget {
  final ApiService apiService;
  final AppLocaleController localeController;
  final AppTab initialTab;

  const CustomerEntry({
    super.key,
    required this.apiService,
    required this.localeController,
    this.initialTab = AppTab.home,
  });

  @override
  State<CustomerEntry> createState() => _CustomerEntryState();
}

class _CustomerEntryState extends State<CustomerEntry> {
  static bool _hasShownSplashThisSession = false;
  late bool _showSplash;

  @override
  void initState() {
    super.initState();
    _showSplash = !_hasShownSplashThisSession;
    if (!_showSplash) {
      return;
    }
    Future<void>.delayed(const Duration(milliseconds: 1800), () {
      if (!mounted) {
        return;
      }
      _hasShownSplashThisSession = true;
      setState(() => _showSplash = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 450),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: _showSplash
          ? const SplashScreen()
          : AppShell(
              apiService: widget.apiService,
              localeController: widget.localeController,
              initialTab: widget.initialTab,
            ),
    );
  }
}
