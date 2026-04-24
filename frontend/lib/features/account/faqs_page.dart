import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/extensions/localized_content.dart';
import '../../localization/app_locale_controller.dart';
import '../../localization/app_localizations.dart';
import '../../models/faq_model.dart';
import '../../services/api_service.dart';

class FaqsPage extends StatefulWidget {
  final ApiService apiService;
  final AppLocaleController localeController;

  const FaqsPage({
    super.key,
    required this.apiService,
    required this.localeController,
  });

  @override
  State<FaqsPage> createState() => _FaqsPageState();
}

class _FaqsPageState extends State<FaqsPage> {
  late Future<List<FaqModel>> _faqsFuture;

  @override
  void initState() {
    super.initState();
    widget.localeController.addListener(_reload);
    _faqsFuture = _loadFaqs();
  }

  @override
  void didUpdateWidget(covariant FaqsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.localeController != widget.localeController) {
      oldWidget.localeController.removeListener(_reload);
      widget.localeController.addListener(_reload);
      _reload();
    }
  }

  @override
  void dispose() {
    widget.localeController.removeListener(_reload);
    super.dispose();
  }

  Future<List<FaqModel>> _loadFaqs() {
    return widget.apiService.fetchFaqs(
      language: widget.localeController.languageCode,
    );
  }

  void _reload() {
    setState(() {
      _faqsFuture = _loadFaqs();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.t('faqs_page_title'))),
      body: FutureBuilder<List<FaqModel>>(
        future: _faqsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return _FaqStateCard(
              title: l10n.t('faqs_error_title'),
              description: l10n.t('faqs_error_desc'),
              actionLabel: l10n.t('common_retry'),
              onPressed: _reload,
            );
          }

          final faqs = snapshot.data ?? const <FaqModel>[];
          if (faqs.isEmpty) {
            return _FaqStateCard(
              title: l10n.t('faqs_empty_title'),
              description: l10n.t('faqs_empty_desc'),
              actionLabel: l10n.t('common_refresh'),
              onPressed: _reload,
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
            itemCount: faqs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final faq = faqs[index];
              return Container(
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: AppColors.border),
                ),
                child: ExpansionTile(
                  tilePadding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                  childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                  title: Text(
                    faq.localizedQuestion(context.l10n),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        faq.localizedAnswer(context.l10n),
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              height: 1.65,
                            ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _FaqStateCard extends StatelessWidget {
  final String title;
  final String description;
  final String actionLabel;
  final VoidCallback onPressed;

  const _FaqStateCard({
    required this.title,
    required this.description,
    required this.actionLabel,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Semantics(
          liveRegion: true,
          label: '$title. $description',
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 12),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        height: 1.6,
                      ),
                ),
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: onPressed,
                  child: Text(actionLabel),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
