import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/brand_logo.dart';
import '../../../../core/widgets/language_toggle.dart';
import '../../../../localization/app_locale_controller.dart';
import '../../../../localization/app_localizations.dart';
import '../admin_session_controller.dart';

class AdminLoginPage extends StatefulWidget {
  final AdminSessionController sessionController;
  final AppLocaleController localeController;

  const AdminLoginPage({
    super.key,
    required this.sessionController,
    required this.localeController,
  });

  @override
  State<AdminLoginPage> createState() => _AdminLoginPageState();
}

class _AdminLoginPageState extends State<AdminLoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _submitting = true);
    try {
      await widget.sessionController.login(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      if (!mounted) {
        return;
      }
      context.go('/admin');
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 1040;
    final l10n = context.l10n;

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: LanguageToggle(
                    controller: widget.localeController,
                    compact: true,
                  ),
                ),
                const SizedBox(height: 18),
                Expanded(
                  child: isWide
                      ? Row(
                          children: [
                            Expanded(child: _BrandPanel(l10n: l10n)),
                            const SizedBox(width: 28),
                            Expanded(child: _LoginCard(form: _buildForm(l10n))),
                          ],
                        )
                      : _LoginCard(form: _buildForm(l10n)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildForm(AppLocalizations l10n) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.t('admin_login_title'),
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 10),
          Text(
            l10n.t('admin_login_subtitle'),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 26),
          TextFormField(
            controller: _emailController,
            decoration: InputDecoration(labelText: l10n.t('field_email')),
            validator: (value) {
              final email = (value ?? '').trim();
              if (email.isEmpty) {
                return l10n.t('validation_email_required');
              }
              if (!email.contains('@')) {
                return l10n.t('validation_email_invalid');
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _passwordController,
            decoration: InputDecoration(labelText: l10n.t('field_password')),
            obscureText: true,
            validator: (value) {
              if ((value ?? '').isEmpty) {
                return l10n.t('validation_password_required');
              }
              return null;
            },
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _submitting ? null : _submit,
              child: Text(
                _submitting
                    ? l10n.t('admin_login_signing_in')
                    : l10n.t('admin_login_cta'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BrandPanel extends StatelessWidget {
  final AppLocalizations l10n;

  const _BrandPanel({required this.l10n});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(36),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.brownDeep,
            Color(0xFF4B2D21),
            AppColors.goldMuted,
          ],
        ),
        borderRadius: BorderRadius.circular(34),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F2D1A12),
            blurRadius: 28,
            offset: Offset(0, 18),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const BrandLogo(
            size: 76,
            padding: EdgeInsets.all(10),
            backgroundColor: Color(0x14FFFFFF),
            borderRadius: BorderRadius.all(Radius.circular(24)),
          ),
          const SizedBox(height: 22),
          Text(
            l10n.t('app_title'),
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  color: AppColors.white,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.t('brand_tagline'),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppColors.gold,
                ),
          ),
          const SizedBox(height: 24),
          Text(
            l10n.t('admin_login_brand_body'),
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppColors.creamSoft,
                ),
          ),
          const Spacer(),
          Text(
            l10n.t('admin_login_brand_footer'),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.creamSoft,
                ),
          ),
        ],
      ),
    );
  }
}

class _LoginCard extends StatelessWidget {
  final Widget form;

  const _LoginCard({
    required this.form,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x142D1A12),
            blurRadius: 24,
            offset: Offset(0, 16),
          ),
        ],
      ),
      child: form,
    );
  }
}
