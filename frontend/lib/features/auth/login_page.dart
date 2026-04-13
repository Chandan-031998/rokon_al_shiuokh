import 'package:flutter/material.dart';

import '../../localization/app_localizations.dart';
import '../../services/api_service.dart';
import 'auth_scaffold.dart';
import 'register_page.dart';

class LoginPage extends StatefulWidget {
  final ApiService apiService;

  const LoginPage({
    super.key,
    required this.apiService,
  });

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isSubmitting = false;

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

    setState(() => _isSubmitting = true);
    try {
      await widget.apiService.login(
        email: _emailController.text.trim(),
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

  Future<void> _openRegister() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => RegisterPage(apiService: widget.apiService),
      ),
    );
    if (!mounted || created != true) {
      return;
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return AuthScaffold(
      title: l10n.t('login_title'),
      subtitle: l10n.t('login_subtitle'),
      footerPrompt: l10n.t('login_need_account'),
      footerActionLabel: l10n.t('common_register'),
      onFooterAction: _openRegister,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
              controller: _passwordController,
              label: l10n.t('field_password'),
              hintText: l10n.t('field_password_hint'),
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
                onPressed: _isSubmitting ? null : _submit,
                child: Text(
                  _isSubmitting
                      ? l10n.t('login_signing_in')
                      : l10n.t('login_cta'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
