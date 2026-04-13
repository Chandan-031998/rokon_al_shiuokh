import 'package:flutter/material.dart';

import '../../localization/app_localizations.dart';
import '../../services/api_service.dart';
import 'auth_scaffold.dart';

class RegisterPage extends StatefulWidget {
  final ApiService apiService;

  const RegisterPage({
    super.key,
    required this.apiService,
  });

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await widget.apiService.register(
        fullName: _fullNameController.text.trim(),
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim(),
        password: _passwordController.text,
      );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(error.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return AuthScaffold(
      title: l10n.t('register_title'),
      subtitle: l10n.t('register_subtitle'),
      footerPrompt: l10n.t('register_have_account'),
      footerActionLabel: l10n.t('common_login'),
      onFooterAction: () => Navigator.of(context).pop(),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            AuthField(
              controller: _fullNameController,
              label: l10n.t('field_full_name'),
              hintText: l10n.t('field_full_name_hint'),
              validator: (value) {
                if ((value ?? '').trim().isEmpty) {
                  return l10n.t('validation_full_name_required');
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            AuthField(
              controller: _emailController,
              label: l10n.t('field_email'),
              hintText: l10n.t('field_email_hint'),
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                final email = (value ?? '').trim();
                if (email.isEmpty) {
                  return l10n.t('validation_email_required');
                }
                if (!email.contains('@') || !email.contains('.')) {
                  return l10n.t('validation_email_invalid');
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            AuthField(
              controller: _phoneController,
              label: l10n.t('field_phone'),
              hintText: l10n.t('field_optional'),
              keyboardType: TextInputType.phone,
              validator: (value) {
                final phone = (value ?? '').trim();
                if (phone.isNotEmpty && phone.length < 8) {
                  return l10n.t('validation_phone_invalid');
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            AuthField(
              controller: _passwordController,
              label: l10n.t('field_password'),
              hintText: l10n.t('field_password_min_hint'),
              obscureText: true,
              validator: (value) {
                if ((value ?? '').length < 6) {
                  return l10n.t('validation_password_short');
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            AuthField(
              controller: _confirmPasswordController,
              label: l10n.t('field_confirm_password'),
              hintText: l10n.t('field_confirm_password_hint'),
              obscureText: true,
              validator: (value) {
                if (value != _passwordController.text) {
                  return l10n.t('validation_password_mismatch');
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submit,
                child: Text(
                  _isSubmitting
                      ? l10n.t('register_creating')
                      : l10n.t('register_cta'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
