import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants/app_colors.dart';
import '../../core/extensions/localized_content.dart';
import '../../core/widgets/premium_network_image.dart';
import '../../models/cms_page_model.dart';
import '../../localization/app_localizations.dart';
import '../../services/api_service.dart';

class CmsPageViewer extends StatefulWidget {
  final ApiService apiService;
  final String slug;
  final String fallbackTitle;

  const CmsPageViewer({
    super.key,
    required this.apiService,
    required this.slug,
    required this.fallbackTitle,
  });

  @override
  State<CmsPageViewer> createState() => _CmsPageViewerState();
}

class _CmsPageViewerState extends State<CmsPageViewer> {
  late Future<CmsPageModel?> _pageFuture;

  @override
  void initState() {
    super.initState();
    _pageFuture = widget.apiService.fetchCmsPageBySlug(widget.slug);
  }

  void _reload() {
    setState(() {
      _pageFuture = widget.apiService.fetchCmsPageBySlug(widget.slug);
    });
  }

  Future<void> _copyActionLink(String url) async {
    await Clipboard.setData(ClipboardData(text: url));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Link copied to clipboard.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.fallbackTitle)),
      body: FutureBuilder<CmsPageModel?>(
        future: _pageFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return _PageStateCard(
              title: 'Unable to load this page',
              description:
                  'The latest admin-managed content could not be retrieved. Retry to refresh this page.',
              actionLabel: 'Retry',
              onPressed: _reload,
            );
          }

          final page = snapshot.data;
          if (page == null || page.id == 0) {
            return _PageStateCard(
              title: widget.fallbackTitle,
              description:
                  'This page has not been published yet. It will appear here once content is added in the admin panel.',
              actionLabel: 'Refresh',
              onPressed: _reload,
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
            children: [
              if ((page.imageUrl ?? '').trim().isNotEmpty) ...[
                PremiumNetworkImage(
                  imageUrl: page.imageUrl,
                  height: 220,
                  borderRadius: BorderRadius.circular(28),
                  fallbackIcon: Icons.article_outlined,
                  semanticLabel: page.localizedTitle(context.l10n),
                ),
                const SizedBox(height: 18),
              ],
              Text(
                page.localizedTitle(context.l10n),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: AppColors.brownDeep,
                    ),
              ),
              if ((page.localizedExcerpt(context.l10n) ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  page.localizedExcerpt(context.l10n)!,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppColors.goldMuted,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(
                  ((page.localizedBody(context.l10n) ?? '').trim().isEmpty)
                      ? 'Content for this page is currently empty.'
                      : page.localizedBody(context.l10n)!,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        height: 1.7,
                      ),
                ),
              ),
              if ((page.localizedCtaLabel(context.l10n) ?? '').trim().isNotEmpty &&
                  (page.ctaUrl ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: () => _copyActionLink(page.ctaUrl!),
                  icon: const Icon(Icons.link_rounded),
                  label: Text(page.localizedCtaLabel(context.l10n)!),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _PageStateCard extends StatelessWidget {
  final String title;
  final String description;
  final String actionLabel;
  final VoidCallback onPressed;

  const _PageStateCard({
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
              borderRadius: BorderRadius.circular(28),
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
