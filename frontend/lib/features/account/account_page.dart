import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../localization/app_locale_controller.dart';
import '../../localization/app_localizations.dart';
import '../../models/user_model.dart';
import '../../services/api_service.dart';
import '../auth/login_page.dart';
import '../auth/register_page.dart';
import '../navigation/app_shell.dart';
import 'cms_page_viewer.dart';
import 'faqs_page.dart';
import 'support_center_page.dart';
import 'wishlist_page.dart';

class AccountPage extends StatefulWidget {
  final ApiService apiService;
  final AppLocaleController localeController;
  final bool isActive;
  final VoidCallback onOpenOrders;
  final VoidCallback onOpenCart;
  final bool showAppBar;
  final VoidCallback? onSessionChanged;

  const AccountPage({
    super.key,
    required this.apiService,
    required this.localeController,
    required this.isActive,
    required this.onOpenOrders,
    required this.onOpenCart,
    this.showAppBar = true,
    this.onSessionChanged,
  });

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  late Future<UserModel?> _profileFuture;

  @override
  void initState() {
    super.initState();
    _profileFuture = _loadProfile();
  }

  @override
  void didUpdateWidget(covariant AccountPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isActive && widget.isActive) {
      _refreshProfile();
    }
  }

  Future<UserModel?> _loadProfile() async {
    try {
      final hasSession = await widget.apiService.hasAuthSession();
      if (!hasSession) {
        return await widget.apiService.getStoredUser();
      }

      return await widget.apiService.fetchProfile();
    } catch (_) {
      return await widget.apiService.getStoredUser();
    }
  }

  Future<void> _refreshProfile() async {
    setState(() {
      _profileFuture = _loadProfile();
    });
    try {
      await _profileFuture;
    } catch (_) {
      // Let FutureBuilder render the fallback state without logging an
      // additional uncaught async error in Flutter web.
    }
  }

  Future<void> _openLogin() async {
    final didLogin = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => LoginPage(apiService: widget.apiService),
      ),
    );
    if (didLogin == true) {
      await _refreshProfile();
      widget.onSessionChanged?.call();
    }
  }

  Future<void> _openRegister() async {
    final didRegister = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => RegisterPage(apiService: widget.apiService),
      ),
    );
    if (didRegister == true) {
      await _refreshProfile();
      widget.onSessionChanged?.call();
    }
  }

  Future<void> _openEditProfile(UserModel user) async {
    final updated = await showModalBottomSheet<UserModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditProfileSheet(
        user: user,
        apiService: widget.apiService,
      ),
    );
    if (updated != null) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(context.l10n.t('account_profile_update_success'))),
      );
      setState(() {
        _profileFuture = Future<UserModel?>.value(updated);
      });
    }
  }

  Future<void> _showLanguageSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _LanguageSheet(controller: widget.localeController),
    );
  }

  Future<void> _logout() async {
    await widget.apiService.logout();
    if (!mounted) {
      return;
    }
    await _refreshProfile();
    widget.onSessionChanged?.call();
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.t('account_logged_out'))),
    );
  }

  Future<void> _openWishlist() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => WishlistPage(apiService: widget.apiService),
      ),
    );
  }

  Future<void> _openSupportCenter() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SupportCenterPage(apiService: widget.apiService),
      ),
    );
  }

  Future<void> _openFaqs() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FaqsPage(apiService: widget.apiService),
      ),
    );
  }

  Future<void> _openCmsPage(String slug, String title) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CmsPageViewer(
          apiService: widget.apiService,
          slug: slug,
          fallbackTitle: title,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return TabScreenTemplate(
      eyebrow: l10n.t('account_eyebrow'),
      title: l10n.t('account_title'),
      subtitle: l10n.t('account_subtitle'),
      icon: Icons.person_rounded,
      showAppBar: widget.showAppBar,
      localeController: widget.localeController,
      body: FutureBuilder<UserModel?>(
        future: _profileFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            );
          }

          if (snapshot.hasError) {
            return ActionPanel(
              title: l10n.t('account_load_error_title'),
              description: l10n.t('account_load_error_desc'),
              actionLabel: l10n.t('common_retry'),
              onPressed: _refreshProfile,
              icon: Icons.refresh_rounded,
            );
          }

          final user = snapshot.data;
          if (user == null || user.id == 0) {
            return Column(
              children: [
                ActionPanel(
                  title: l10n.t('account_sign_in_title'),
                  description: l10n.t('account_sign_in_desc'),
                  actionLabel: l10n.t('common_login'),
                  onPressed: _openLogin,
                  icon: Icons.login_rounded,
                ),
                ActionPanel(
                  title: l10n.t('account_create_title'),
                  description: l10n.t('account_create_desc'),
                  actionLabel: l10n.t('common_register'),
                  onPressed: _openRegister,
                  icon: Icons.person_add_alt_1_rounded,
                ),
                ActionPanel(
                  title: l10n.t('account_continue_shopping_title'),
                  description: l10n.t('account_continue_shopping_desc'),
                  actionLabel: l10n.t('common_open_cart'),
                  onPressed: widget.onOpenCart,
                  icon: Icons.shopping_cart_outlined,
                ),
                const SizedBox(height: 16),
                _buildSupportAccessSection(showWishlist: false),
              ],
            );
          }

          return Column(
            children: [
              _ProfileHeader(
                user: user,
                onEditPressed: () => _openEditProfile(user),
              ),
              const SizedBox(height: 16),
              _InfoCard(
                title: l10n.t('account_contact_info'),
                child: Column(
                  children: [
                    _InfoRow(
                      icon: Icons.badge_outlined,
                      label: l10n.t('account_name'),
                      value: user.fullName,
                    ),
                    const SizedBox(height: 14),
                    _InfoRow(
                      icon: Icons.alternate_email_rounded,
                      label: l10n.t('account_email'),
                      value: user.email,
                    ),
                    const SizedBox(height: 14),
                    _InfoRow(
                      icon: Icons.phone_outlined,
                      label: l10n.t('account_phone'),
                      value: user.phone?.isNotEmpty == true
                          ? user.phone!
                          : l10n.t('account_no_phone'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _InfoCard(
                title: l10n.t('account_saved_addresses'),
                child: user.addresses.isEmpty
                    ? Text(
                        l10n.t('account_no_addresses'),
                        style: Theme.of(context).textTheme.bodyMedium,
                      )
                    : Column(
                        children: [
                          for (var index = 0;
                              index < user.addresses.length;
                              index++) ...[
                            _AddressTile(address: user.addresses[index]),
                            if (index != user.addresses.length - 1)
                              const Divider(
                                  color: AppColors.border, height: 24),
                          ],
                        ],
                      ),
              ),
              const SizedBox(height: 16),
              _InfoCard(
                title: l10n.t('account_preferred_branch'),
                child: _InfoRow(
                  icon: Icons.storefront_outlined,
                  label:
                      user.preferredBranch?.name ?? l10n.t('account_no_branch'),
                  value: user.preferredBranch == null
                      ? l10n.t('account_no_branch_desc')
                      : '${user.preferredBranch!.city ?? l10n.t('account_branch_city_unavailable')}\n${user.preferredBranch!.address ?? ''}'
                          .trim(),
                ),
              ),
              const SizedBox(height: 16),
              _InfoCard(
                title: l10n.t('account_options'),
                child: Column(
                  children: [
                    _OptionTile(
                      icon: Icons.favorite_border_rounded,
                      title: 'Wishlist',
                      subtitle:
                          'Review your saved products and move them into the cart when ready.',
                      onTap: _openWishlist,
                    ),
                    const Divider(color: AppColors.border, height: 24),
                    _OptionTile(
                      icon: Icons.language_outlined,
                      title: l10n.t('account_language'),
                      subtitle: l10n.t('account_language_desc'),
                      onTap: _showLanguageSheet,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _buildSupportAccessSection(showWishlist: false),
              const SizedBox(height: 16),
              ActionPanel(
                title: l10n.t('account_open_orders_title'),
                description: l10n.t('account_open_orders_desc'),
                actionLabel: l10n.t('common_view_orders'),
                onPressed: widget.onOpenOrders,
                icon: Icons.receipt_long_outlined,
              ),
              ActionPanel(
                title: l10n.t('account_logout_title'),
                description: l10n.t('account_logout_desc'),
                actionLabel: l10n.t('common_logout'),
                onPressed: _logout,
                icon: Icons.logout_rounded,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSupportAccessSection({required bool showWishlist}) {
    return _InfoCard(
      title: 'Help, support, and policies',
      child: Column(
        children: [
          if (showWishlist) ...[
            _OptionTile(
              icon: Icons.favorite_border_rounded,
              title: 'Wishlist',
              subtitle: 'Open your saved products and continue shopping later.',
              onTap: _openWishlist,
            ),
            const Divider(color: AppColors.border, height: 24),
          ],
          _OptionTile(
            icon: Icons.support_agent_outlined,
            title: 'Support & Contact',
            subtitle:
                'View customer care details, WhatsApp support, and social channels.',
            onTap: _openSupportCenter,
          ),
          const Divider(color: AppColors.border, height: 24),
          _OptionTile(
            icon: Icons.quiz_outlined,
            title: 'FAQs',
            subtitle: 'Read frequently asked questions published from admin.',
            onTap: _openFaqs,
          ),
          const Divider(color: AppColors.border, height: 24),
          _OptionTile(
            icon: Icons.privacy_tip_outlined,
            title: 'Privacy Policy',
            subtitle: 'Read how your information is handled.',
            onTap: () => _openCmsPage('privacy-policy', 'Privacy Policy'),
          ),
          const Divider(color: AppColors.border, height: 24),
          _OptionTile(
            icon: Icons.local_shipping_outlined,
            title: 'Delivery Policy',
            subtitle: 'Review delivery timing, coverage, and service terms.',
            onTap: () => _openCmsPage('delivery-policy', 'Delivery Policy'),
          ),
          const Divider(color: AppColors.border, height: 24),
          _OptionTile(
            icon: Icons.assignment_return_outlined,
            title: 'Return / Refund Policy',
            subtitle: 'Understand return and refund conditions before ordering.',
            onTap: () =>
                _openCmsPage('return-refund-policy', 'Return / Refund Policy'),
          ),
          const Divider(color: AppColors.border, height: 24),
          _OptionTile(
            icon: Icons.gavel_outlined,
            title: 'Terms & Conditions',
            subtitle: 'Review the current terms for shopping and fulfillment.',
            onTap: () => _openCmsPage(
              'terms-and-conditions',
              'Terms & Conditions',
            ),
          ),
          const Divider(color: AppColors.border, height: 24),
          _OptionTile(
            icon: Icons.info_outline_rounded,
            title: 'About Us',
            subtitle: 'Read the latest brand and company profile.',
            onTap: () => _openCmsPage('about-us', 'About Us'),
          ),
          const Divider(color: AppColors.border, height: 24),
          _OptionTile(
            icon: Icons.contact_mail_outlined,
            title: 'Contact Us',
            subtitle: 'Open the current contact page managed from admin.',
            onTap: () => _openCmsPage('contact-us', 'Contact Us'),
          ),
        ],
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  final UserModel user;
  final VoidCallback onEditPressed;

  const _ProfileHeader({
    required this.user,
    required this.onEditPressed,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final initials = user.fullName
        .split(' ')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part[0].toUpperCase())
        .join();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.brownDeep, Color(0xFF4B2D21), AppColors.brown],
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A2D1A12),
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.cream,
              borderRadius: BorderRadius.circular(24),
            ),
            alignment: Alignment.center,
            child: Text(
              initials.isEmpty ? 'RA' : initials,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppColors.brownDeep,
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.fullName.isEmpty
                      ? l10n.t('account_title')
                      : user.fullName,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: AppColors.white,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.t('account_profile_ready'),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.creamSoft,
                      ),
                ),
                const SizedBox(height: 14),
                FilledButton(
                  onPressed: onEditPressed,
                  child: Text(l10n.t('account_edit_profile')),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _InfoCard({
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.white, Color(0xFFFFFBF7)],
        ),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x102D1A12),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: AppColors.creamSoft,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: AppColors.brown),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: AppColors.goldMuted,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 6),
              Text(value, style: Theme.of(context).textTheme.bodyLarge),
            ],
          ),
        ),
      ],
    );
  }
}

class _AddressTile extends StatelessWidget {
  final SavedAddressModel address;

  const _AddressTile({required this.address});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: AppColors.creamSoft,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.location_on_outlined, color: AppColors.brown),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    address.label,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  if (address.isDefault) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.creamSoft,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        l10n.t('account_default'),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: AppColors.brown,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '${address.city}, ${address.neighborhood}\n${address.addressLine}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _OptionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _OptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.creamSoft,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: AppColors.brown),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ),
            if (onTap != null)
              const Padding(
                padding: EdgeInsets.only(top: 10),
                child: Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: AppColors.brown,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _LanguageSheet extends StatelessWidget {
  final AppLocaleController controller;

  const _LanguageSheet({required this.controller});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.t('account_language_sheet_title'),
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          _LanguageTile(
            label: l10n.t('account_language_english'),
            selected: controller.locale.languageCode == 'en',
            onTap: () async {
              await controller.setLocale(const Locale('en'));
              if (context.mounted) {
                Navigator.of(context).pop();
              }
            },
          ),
          const SizedBox(height: 12),
          _LanguageTile(
            label: l10n.t('account_language_arabic'),
            selected: controller.locale.languageCode == 'ar',
            onTap: () async {
              await controller.setLocale(const Locale('ar'));
              if (context.mounted) {
                Navigator.of(context).pop();
              }
            },
          ),
        ],
      ),
    );
  }
}

class _LanguageTile extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _LanguageTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Ink(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? AppColors.creamSoft : AppColors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? AppColors.goldMuted : AppColors.border,
          ),
        ),
        child: Row(
          children: [
            Expanded(
                child:
                    Text(label, style: Theme.of(context).textTheme.bodyLarge)),
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected ? AppColors.goldMuted : AppColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}

class _EditProfileSheet extends StatefulWidget {
  final UserModel user;
  final ApiService apiService;

  const _EditProfileSheet({
    required this.user,
    required this.apiService,
  });

  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _fullNameController;
  late final TextEditingController _phoneController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _fullNameController = TextEditingController(text: widget.user.fullName);
    _phoneController = TextEditingController(text: widget.user.phone ?? '');
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSaving = true);
    try {
      final updatedUser = await widget.apiService.updateProfile(
        fullName: _fullNameController.text,
        phone: _phoneController.text,
      );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(updatedUser);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final viewInsets = MediaQuery.of(context).viewInsets;

    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.cream,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.t('account_edit_title'),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _fullNameController,
                validator: (value) {
                  if ((value ?? '').trim().isEmpty) {
                    return l10n.t('validation_full_name_required');
                  }
                  return null;
                },
                decoration: _fieldDecoration(l10n.t('field_full_name')),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                validator: (value) {
                  final phone = (value ?? '').trim();
                  if (phone.isNotEmpty && phone.length < 8) {
                    return l10n.t('validation_phone_invalid');
                  }
                  return null;
                },
                decoration: _fieldDecoration(l10n.t('field_phone')),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  child: Text(
                    _isSaving
                        ? l10n.t('account_saving')
                        : l10n.t('account_save_changes'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _fieldDecoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: AppColors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: AppColors.border),
      ),
    );
  }
}
