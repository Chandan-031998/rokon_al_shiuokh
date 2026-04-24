import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/premium_network_image.dart';
import '../models/admin_cms_page_model.dart';
import '../models/admin_faq_model.dart';
import '../models/admin_support_settings_model.dart';
import '../services/admin_api_service.dart';
import '../utils/admin_image_picker.dart';
import '../widgets/admin_page_frame.dart';

class AdminContentPage extends StatefulWidget {
  final AdminApiService apiService;

  const AdminContentPage({
    super.key,
    required this.apiService,
  });

  @override
  State<AdminContentPage> createState() => _AdminContentPageState();
}

class _AdminContentPageState extends State<AdminContentPage> {
  bool _loading = true;
  String? _error;
  List<AdminCmsPageModel> _pages = const [];
  List<AdminFaqModel> _faqs = const [];
  AdminSupportSettingsModel _support = const AdminSupportSettingsModel();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        widget.apiService.fetchCmsPages(),
        widget.apiService.fetchFaqs(),
        widget.apiService.fetchSupportSettings(),
      ]);
      if (!mounted) {
        return;
      }
      setState(() {
        _pages = results[0] as List<AdminCmsPageModel>;
        _faqs = results[1] as List<AdminFaqModel>;
        _support = results[2] as AdminSupportSettingsModel;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _openPageEditor({
    AdminCmsPageModel? page,
    String? initialSection,
    _CmsPagePreset? preset,
  }) async {
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _CmsPageEditorDialog(
        apiService: widget.apiService,
        page: page,
        initialSection: initialSection,
        preset: preset,
      ),
    );
    if (result == null || !mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result == 'created'
              ? 'Content item added successfully.'
              : 'Content item updated successfully.',
        ),
      ),
    );
    await _load();
  }

  Future<void> _deletePage(AdminCmsPageModel page) async {
    final confirmed = await _confirmDelete(
      title: 'Delete Content Item',
      message: 'Delete "${page.title}"?',
    );
    if (confirmed != true) {
      return;
    }
    try {
      await widget.apiService.deleteCmsPage(page.id);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Content item deleted successfully.')),
      );
      await _load();
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _openFaqEditor([AdminFaqModel? faq]) async {
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _FaqEditorDialog(
        apiService: widget.apiService,
        faq: faq,
      ),
    );
    if (result == null || !mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result == 'created'
              ? 'FAQ added successfully.'
              : 'FAQ updated successfully.',
        ),
      ),
    );
    await _load();
  }

  Future<void> _deleteFaq(AdminFaqModel faq) async {
    final confirmed = await _confirmDelete(
      title: 'Delete FAQ',
      message: 'Delete "${faq.question}"?',
    );
    if (confirmed != true) {
      return;
    }
    try {
      await widget.apiService.deleteFaq(faq.id);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('FAQ deleted successfully.')),
      );
      await _load();
    } catch (error) {
      _showError(error);
    }
  }

  Future<bool?> _confirmDelete({
    required String title,
    required String message,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showError(Object error) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error.toString().replaceFirst('Exception: ', '')),
      ),
    );
  }

  List<AdminCmsPageModel> _pagesForSection(String section) {
    final items = _pages.where((page) => page.section == section).toList();
    items.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return items;
  }

  @override
  Widget build(BuildContext context) {
    return AdminPageFrame(
      title: 'Content Management',
      subtitle:
          'Manage hero banners, delivery information, policy pages, FAQs, and support details from the admin panel.',
      actions: [
        OutlinedButton.icon(
          onPressed: _load,
          icon: const Icon(Icons.refresh),
          label: const Text('Refresh'),
        ),
        ElevatedButton.icon(
          onPressed: () => _openPageEditor(initialSection: 'hero_banner'),
          icon: const Icon(Icons.add_photo_alternate_outlined),
          label: const Text('Add Content Item'),
        ),
      ],
      child: _loading
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(64),
                child: CircularProgressIndicator(),
              ),
            )
          : _error != null
              ? _ContentError(message: _error!, onRetry: _load)
              : Column(
                  children: [
                    _ContentSummary(pages: _pages, faqs: _faqs),
                    const SizedBox(height: 20),
                    _CmsGroupPanel(
                      title: 'Homepage Content',
                      actions: [
                        _ActionChipButton(
                          label: 'Add Hero Slide',
                          onPressed: () =>
                              _openPageEditor(initialSection: 'hero_banner'),
                        ),
                        _ActionChipButton(
                          label: 'Home Banner',
                          onPressed: () => _openPageEditor(
                            initialSection: 'home_section_banner',
                          ),
                        ),
                        _ActionChipButton(
                          label: 'Marketing Card',
                          onPressed: () => _openPageEditor(
                            initialSection: 'marketing_card',
                          ),
                        ),
                        _ActionChipButton(
                          label: 'Delivery Block',
                          onPressed: () => _openPageEditor(
                            initialSection: 'delivery_information',
                          ),
                        ),
                      ],
                      child: Column(
                        children: [
                          _CmsSectionList(
                            title: 'Hero Banner Slides',
                            items: _pagesForSection('hero_banner'),
                            onEdit: (page) => _openPageEditor(page: page),
                            onDelete: _deletePage,
                          ),
                          const SizedBox(height: 14),
                          _CmsSectionList(
                            title: 'Home Section Banners',
                            items: _pagesForSection('home_section_banner'),
                            onEdit: (page) => _openPageEditor(page: page),
                            onDelete: _deletePage,
                          ),
                          const SizedBox(height: 14),
                          _CmsSectionList(
                            title: 'Marketing Cards',
                            items: _pagesForSection('marketing_card'),
                            onEdit: (page) => _openPageEditor(page: page),
                            onDelete: _deletePage,
                          ),
                          const SizedBox(height: 14),
                          _CmsSectionList(
                            title: 'Delivery Information Blocks',
                            items: _pagesForSection('delivery_information'),
                            onEdit: (page) => _openPageEditor(page: page),
                            onDelete: _deletePage,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    _CmsGroupPanel(
                      title: 'Policy And Brand Pages',
                      actions: [
                        _ActionChipButton(
                          label: 'Privacy Policy',
                          onPressed: () => _openPageEditor(
                            initialSection: 'policy',
                            preset: const _CmsPagePreset(
                              section: 'policy',
                              slug: 'privacy-policy',
                              titleEn: 'Privacy Policy',
                              titleAr: 'سياسة الخصوصية',
                            ),
                          ),
                        ),
                        _ActionChipButton(
                          label: 'Refund Policy',
                          onPressed: () => _openPageEditor(
                            initialSection: 'policy',
                            preset: const _CmsPagePreset(
                              section: 'policy',
                              slug: 'return-refund-policy',
                              titleEn: 'Return & Refund Policy',
                              titleAr: 'سياسة الاسترجاع والاسترداد',
                            ),
                          ),
                        ),
                        _ActionChipButton(
                          label: 'Delivery Policy',
                          onPressed: () => _openPageEditor(
                            initialSection: 'policy',
                            preset: const _CmsPagePreset(
                              section: 'policy',
                              slug: 'delivery-policy',
                              titleEn: 'Delivery Policy',
                              titleAr: 'سياسة التوصيل',
                            ),
                          ),
                        ),
                        _ActionChipButton(
                          label: 'Terms & Conditions',
                          onPressed: () => _openPageEditor(
                            initialSection: 'policy',
                            preset: const _CmsPagePreset(
                              section: 'policy',
                              slug: 'terms-and-conditions',
                              titleEn: 'Terms & Conditions',
                              titleAr: 'الشروط والأحكام',
                            ),
                          ),
                        ),
                        _ActionChipButton(
                          label: 'About Us',
                          onPressed: () => _openPageEditor(
                            initialSection: 'about_us',
                            preset: const _CmsPagePreset(
                              section: 'about_us',
                              slug: 'about-us',
                              titleEn: 'About Us',
                              titleAr: 'من نحن',
                            ),
                          ),
                        ),
                        _ActionChipButton(
                          label: 'Contact Us',
                          onPressed: () => _openPageEditor(
                            initialSection: 'contact_us',
                            preset: const _CmsPagePreset(
                              section: 'contact_us',
                              slug: 'contact-us',
                              titleEn: 'Contact Us',
                              titleAr: 'اتصل بنا',
                            ),
                          ),
                        ),
                      ],
                      child: Column(
                        children: [
                          _CmsSectionList(
                            title: 'Policy Pages',
                            items: _pagesForSection('policy'),
                            onEdit: (page) => _openPageEditor(page: page),
                            onDelete: _deletePage,
                          ),
                          const SizedBox(height: 14),
                          _CmsSectionList(
                            title: 'About Us',
                            items: _pagesForSection('about_us'),
                            onEdit: (page) => _openPageEditor(page: page),
                            onDelete: _deletePage,
                          ),
                          const SizedBox(height: 14),
                          _CmsSectionList(
                            title: 'Contact Us',
                            items: _pagesForSection('contact_us'),
                            onEdit: (page) => _openPageEditor(page: page),
                            onDelete: _deletePage,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        if (constraints.maxWidth < 980) {
                          return Column(
                            children: [
                              _FaqPanel(
                                faqs: _faqs,
                                onAdd: _openFaqEditor,
                                onEdit: (faq) => _openFaqEditor(faq),
                                onDelete: _deleteFaq,
                              ),
                              const SizedBox(height: 20),
                              _SupportSettingsPanel(
                                apiService: widget.apiService,
                                settings: _support,
                                onSaved: _load,
                              ),
                            ],
                          );
                        }
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _FaqPanel(
                                faqs: _faqs,
                                onAdd: _openFaqEditor,
                                onEdit: (faq) => _openFaqEditor(faq),
                                onDelete: _deleteFaq,
                              ),
                            ),
                            const SizedBox(width: 20),
                            Expanded(
                              child: _SupportSettingsPanel(
                                apiService: widget.apiService,
                                settings: _support,
                                onSaved: _load,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
    );
  }
}

class _ActionChipButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _ActionChipButton({
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.add),
      label: Text(label),
    );
  }
}

class _CmsPagePreset {
  final String section;
  final String slug;
  final String titleEn;
  final String titleAr;

  const _CmsPagePreset({
    required this.section,
    required this.slug,
    required this.titleEn,
    required this.titleAr,
  });
}

class _ContentSummary extends StatelessWidget {
  final List<AdminCmsPageModel> pages;
  final List<AdminFaqModel> faqs;

  const _ContentSummary({
    required this.pages,
    required this.faqs,
  });

  @override
  Widget build(BuildContext context) {
    final metrics = <({String label, String value, IconData icon})>[
      (
        label: 'Active content blocks',
        value: '${pages.where((page) => page.isActive).length}',
        icon: Icons.view_quilt_outlined,
      ),
      (
        label: 'Policy & brand pages',
        value: '${pages.where((page) => {
              'policy',
              'about_us',
              'contact_us'
            }.contains(page.section)).length}',
        icon: Icons.policy_outlined,
      ),
      (
        label: 'FAQ entries',
        value: '${faqs.where((faq) => faq.isActive).length}',
        icon: Icons.quiz_outlined,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1180
            ? 3
            : constraints.maxWidth >= 760
                ? 2
                : 1;
        return GridView.count(
          crossAxisCount: columns,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: constraints.maxWidth >= 760 ? 1.9 : 2.6,
          children: [
            for (final item in metrics)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceSoft,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Icon(item.icon, color: AppColors.primaryDark),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.value,
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 4),
                          Text(item.label),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

class _CmsGroupPanel extends StatelessWidget {
  final String title;
  final List<Widget> actions;
  final Widget child;

  const _CmsGroupPanel({
    required this.title,
    required this.actions,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 860) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 14),
                    Wrap(spacing: 10, runSpacing: 10, children: actions),
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Flexible(
                    child: Wrap(
                      alignment: WrapAlignment.end,
                      spacing: 10,
                      runSpacing: 10,
                      children: actions,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}

class _CmsSectionList extends StatelessWidget {
  final String title;
  final List<AdminCmsPageModel> items;
  final ValueChanged<AdminCmsPageModel> onEdit;
  final ValueChanged<AdminCmsPageModel> onDelete;

  const _CmsSectionList({
    required this.title,
    required this.items,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          if (items.isEmpty)
            Text(
              'No items yet.',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.textMuted),
            )
          else
            Column(
              children: [
                for (final item in items)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _CmsItemCard(
                      item: item,
                      onEdit: () => onEdit(item),
                      onDelete: () => onDelete(item),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _CmsItemCard extends StatelessWidget {
  final AdminCmsPageModel item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _CmsItemCard({
    required this.item,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(18),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stacked = constraints.maxWidth < 640;
          final image = (item.imageUrl ?? '').isNotEmpty
              ? Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: AppColors.creamSoft,
                    borderRadius: BorderRadius.circular(16),
                    image: DecorationImage(
                      fit: BoxFit.cover,
                      image: NetworkImage(item.imageUrl!),
                    ),
                  ),
                )
              : null;

          final content = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      item.title,
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: item.isActive
                          ? AppColors.accentLightGold
                          : AppColors.border,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      item.isActive ? 'Active' : 'Inactive',
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(color: AppColors.primaryDark),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '${item.slug}  |  sort ${item.sortOrder}',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.textMuted),
              ),
              if ((item.excerpt ?? '').isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  item.excerpt!,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  OutlinedButton.icon(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Edit'),
                  ),
                  TextButton.icon(
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Delete'),
                  ),
                ],
              ),
            ],
          );

          if (stacked) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (image != null) ...[
                  image,
                  const SizedBox(height: 12),
                ],
                content,
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (image != null) ...[
                image,
                const SizedBox(width: 14),
              ],
              Expanded(child: content),
            ],
          );
        },
      ),
    );
  }
}

class _FaqPanel extends StatelessWidget {
  final List<AdminFaqModel> faqs;
  final Future<void> Function([AdminFaqModel? faq]) onAdd;
  final ValueChanged<AdminFaqModel> onEdit;
  final ValueChanged<AdminFaqModel> onDelete;

  const _FaqPanel({
    required this.faqs,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 520) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'FAQ Management',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => onAdd(),
                        icon: const Icon(Icons.add),
                        label: const Text('Add FAQ'),
                      ),
                    ),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(
                    child: Text(
                      'FAQ Management',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () => onAdd(),
                    icon: const Icon(Icons.add),
                    label: const Text('Add FAQ'),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 18),
          if (faqs.isEmpty)
            Text(
              'No FAQ entries yet.',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.textMuted),
            )
          else
            Column(
              children: [
                for (final faq in faqs)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  faq.question,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleSmall
                                      ?.copyWith(fontWeight: FontWeight.w800),
                                ),
                              ),
                              Text(
                                'sort ${faq.sortOrder}',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: AppColors.textMuted),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if ((faq.questionAr ?? '').isNotEmpty) ...[
                            Text(
                              faq.questionAr!,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 8),
                          ],
                          Text(faq.answer),
                          if ((faq.answerAr ?? '').isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(faq.answerAr!),
                          ],
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              OutlinedButton(
                                onPressed: () => onEdit(faq),
                                child: const Text('Edit'),
                              ),
                              TextButton(
                                onPressed: () => onDelete(faq),
                                child: const Text('Delete'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _SupportSettingsPanel extends StatefulWidget {
  final AdminApiService apiService;
  final AdminSupportSettingsModel settings;
  final Future<void> Function() onSaved;

  const _SupportSettingsPanel({
    required this.apiService,
    required this.settings,
    required this.onSaved,
  });

  @override
  State<_SupportSettingsPanel> createState() => _SupportSettingsPanelState();
}

class _SupportSettingsPanelState extends State<_SupportSettingsPanel> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  late final TextEditingController _addressController;
  late final TextEditingController _addressArController;
  late final TextEditingController _hoursController;
  late final TextEditingController _hoursArController;
  late final TextEditingController _whatsappNumberController;
  late final TextEditingController _whatsappLabelController;
  late final TextEditingController _whatsappLabelArController;
  late final TextEditingController _paymentCodLabelController;
  late final TextEditingController _paymentCardLabelController;
  late final TextEditingController _paymentBankTransferLabelController;
  late final TextEditingController _paymentCheckoutNoticeController;
  late final TextEditingController _facebookController;
  late final TextEditingController _instagramController;
  late final TextEditingController _twitterController;
  late final TextEditingController _tiktokController;
  late final TextEditingController _snapchatController;
  late final TextEditingController _youtubeController;
  bool _paymentCodEnabled = true;
  bool _paymentCardEnabled = false;
  bool _paymentBankTransferEnabled = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _emailController =
        TextEditingController(text: widget.settings.contactEmail ?? '');
    _phoneController =
        TextEditingController(text: widget.settings.contactPhone ?? '');
    _addressController =
        TextEditingController(text: widget.settings.contactAddress ?? '');
    _addressArController =
        TextEditingController(text: widget.settings.contactAddressAr ?? '');
    _hoursController =
        TextEditingController(text: widget.settings.supportHours ?? '');
    _hoursArController =
        TextEditingController(text: widget.settings.supportHoursAr ?? '');
    _whatsappNumberController =
        TextEditingController(text: widget.settings.whatsappNumber ?? '');
    _whatsappLabelController =
        TextEditingController(text: widget.settings.whatsappLabel ?? '');
    _whatsappLabelArController =
        TextEditingController(text: widget.settings.whatsappLabelAr ?? '');
    _paymentCodLabelController =
        TextEditingController(text: widget.settings.paymentCodLabel ?? '');
    _paymentCardLabelController =
        TextEditingController(text: widget.settings.paymentCardLabel ?? '');
    _paymentBankTransferLabelController = TextEditingController(
      text: widget.settings.paymentBankTransferLabel ?? '',
    );
    _paymentCheckoutNoticeController = TextEditingController(
        text: widget.settings.paymentCheckoutNotice ?? '');
    _facebookController =
        TextEditingController(text: widget.settings.facebookUrl ?? '');
    _instagramController =
        TextEditingController(text: widget.settings.instagramUrl ?? '');
    _twitterController =
        TextEditingController(text: widget.settings.twitterUrl ?? '');
    _tiktokController =
        TextEditingController(text: widget.settings.tiktokUrl ?? '');
    _snapchatController =
        TextEditingController(text: widget.settings.snapchatUrl ?? '');
    _youtubeController =
        TextEditingController(text: widget.settings.youtubeUrl ?? '');
    _paymentCodEnabled = widget.settings.paymentCodEnabled;
    _paymentCardEnabled = widget.settings.paymentCardEnabled;
    _paymentBankTransferEnabled = widget.settings.paymentBankTransferEnabled;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _addressArController.dispose();
    _hoursController.dispose();
    _hoursArController.dispose();
    _whatsappNumberController.dispose();
    _whatsappLabelController.dispose();
    _whatsappLabelArController.dispose();
    _paymentCodLabelController.dispose();
    _paymentCardLabelController.dispose();
    _paymentBankTransferLabelController.dispose();
    _paymentCheckoutNoticeController.dispose();
    _facebookController.dispose();
    _instagramController.dispose();
    _twitterController.dispose();
    _tiktokController.dispose();
    _snapchatController.dispose();
    _youtubeController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await widget.apiService.updateSupportSettings({
        'contact_email': _emailController.text.trim(),
        'contact_phone': _phoneController.text.trim(),
        'contact_address': _addressController.text.trim(),
        'contact_address_ar': _addressArController.text.trim(),
        'support_hours': _hoursController.text.trim(),
        'support_hours_ar': _hoursArController.text.trim(),
        'whatsapp_number': _whatsappNumberController.text.trim(),
        'whatsapp_label': _whatsappLabelController.text.trim(),
        'whatsapp_label_ar': _whatsappLabelArController.text.trim(),
        'payment_cod_enabled': _paymentCodEnabled,
        'payment_card_enabled': _paymentCardEnabled,
        'payment_bank_transfer_enabled': _paymentBankTransferEnabled,
        'payment_cod_label': _paymentCodLabelController.text.trim(),
        'payment_card_label': _paymentCardLabelController.text.trim(),
        'payment_bank_transfer_label':
            _paymentBankTransferLabelController.text.trim(),
        'payment_checkout_notice': _paymentCheckoutNoticeController.text.trim(),
        'facebook_url': _facebookController.text.trim(),
        'instagram_url': _instagramController.text.trim(),
        'twitter_url': _twitterController.text.trim(),
        'tiktok_url': _tiktokController.text.trim(),
        'snapchat_url': _snapchatController.text.trim(),
        'youtube_url': _youtubeController.text.trim(),
      });
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Support settings saved.')),
      );
      await widget.onSaved();
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
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AppColors.border),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Support And Contact Settings',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 18),
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Contact Email'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phoneController,
              decoration: const InputDecoration(labelText: 'Contact Phone'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _addressController,
              maxLines: 2,
              decoration:
                  const InputDecoration(labelText: 'Contact Address (English)'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _addressArController,
              maxLines: 2,
              decoration:
                  const InputDecoration(labelText: 'Contact Address (Arabic)'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _hoursController,
              decoration:
                  const InputDecoration(labelText: 'Support Hours (English)'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _hoursArController,
              decoration:
                  const InputDecoration(labelText: 'Support Hours (Arabic)'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _whatsappNumberController,
              decoration: const InputDecoration(labelText: 'WhatsApp Number'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _whatsappLabelController,
              decoration:
                  const InputDecoration(labelText: 'WhatsApp Label (English)'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _whatsappLabelArController,
              decoration:
                  const InputDecoration(labelText: 'WhatsApp Label (Arabic)'),
            ),
            const SizedBox(height: 12),
            Text(
              'Checkout Payment Settings',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            SwitchListTile.adaptive(
              value: _paymentCodEnabled,
              onChanged: (value) => setState(() => _paymentCodEnabled = value),
              title: const Text('Enable Cash on Delivery'),
              contentPadding: EdgeInsets.zero,
            ),
            TextFormField(
              controller: _paymentCodLabelController,
              decoration:
                  const InputDecoration(labelText: 'Cash on Delivery Label'),
            ),
            const SizedBox(height: 12),
            SwitchListTile.adaptive(
              value: _paymentCardEnabled,
              onChanged: (value) => setState(() => _paymentCardEnabled = value),
              title: const Text('Enable Card Payment'),
              contentPadding: EdgeInsets.zero,
            ),
            TextFormField(
              controller: _paymentCardLabelController,
              decoration: const InputDecoration(labelText: 'Card Label'),
            ),
            const SizedBox(height: 12),
            SwitchListTile.adaptive(
              value: _paymentBankTransferEnabled,
              onChanged: (value) =>
                  setState(() => _paymentBankTransferEnabled = value),
              title: const Text('Enable Bank Transfer'),
              contentPadding: EdgeInsets.zero,
            ),
            TextFormField(
              controller: _paymentBankTransferLabelController,
              decoration:
                  const InputDecoration(labelText: 'Bank Transfer Label'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _paymentCheckoutNoticeController,
              minLines: 2,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Checkout Payment Notice',
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _facebookController,
              decoration: const InputDecoration(labelText: 'Facebook URL'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _instagramController,
              decoration: const InputDecoration(labelText: 'Instagram URL'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _twitterController,
              decoration: const InputDecoration(labelText: 'Twitter / X URL'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _tiktokController,
              decoration: const InputDecoration(labelText: 'TikTok URL'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _snapchatController,
              decoration: const InputDecoration(labelText: 'Snapchat URL'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _youtubeController,
              decoration: const InputDecoration(labelText: 'YouTube URL'),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: _saving ? null : _save,
                icon: const Icon(Icons.save_outlined),
                label: Text(_saving ? 'Saving...' : 'Save Settings'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CmsPageEditorDialog extends StatefulWidget {
  final AdminApiService apiService;
  final AdminCmsPageModel? page;
  final String? initialSection;
  final _CmsPagePreset? preset;

  const _CmsPageEditorDialog({
    required this.apiService,
    this.page,
    this.initialSection,
    this.preset,
  });

  @override
  State<_CmsPageEditorDialog> createState() => _CmsPageEditorDialogState();
}

class _CmsPageEditorDialogState extends State<_CmsPageEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _slugController;
  late final TextEditingController _titleController;
  late final TextEditingController _titleArController;
  late final TextEditingController _excerptController;
  late final TextEditingController _excerptArController;
  late final TextEditingController _bodyController;
  late final TextEditingController _bodyArController;
  late final TextEditingController _imageUrlController;
  late final TextEditingController _ctaLabelController;
  late final TextEditingController _ctaLabelArController;
  late final TextEditingController _ctaUrlController;
  late final TextEditingController _eyebrowController;
  late final TextEditingController _eyebrowArController;
  late final TextEditingController _secondaryLabelController;
  late final TextEditingController _secondaryLabelArController;
  late final TextEditingController _metricController;
  late final TextEditingController _metricArController;
  late final TextEditingController _sortOrderController;
  String _section = 'hero_banner';
  String? _regionCode;
  bool _isActive = true;
  bool _uploadingImage = false;
  bool _saving = false;

  static const Set<String> _repeatableSections = {
    'hero_banner',
    'home_section_banner',
    'marketing_card',
    'delivery_information',
  };

  @override
  void initState() {
    super.initState();
    final page = widget.page;
    final metadata = page?.metadataJson ?? const <String, dynamic>{};
    _slugController =
        TextEditingController(text: page?.slug ?? widget.preset?.slug ?? '');
    _titleController = TextEditingController(
      text: page?.titleEn ?? page?.title ?? widget.preset?.titleEn ?? '',
    );
    _titleArController = TextEditingController(
      text: page?.titleAr ??
          widget.preset?.titleAr ??
          _metadataText(metadata, 'title_ar'),
    );
    _excerptController = TextEditingController(
      text: page?.excerptEn ?? page?.excerpt ?? '',
    );
    _excerptArController = TextEditingController(
      text: page?.excerptAr ?? _metadataText(metadata, 'excerpt_ar'),
    );
    _bodyController = TextEditingController(
      text: page?.bodyEn ?? page?.body ?? '',
    );
    _bodyArController = TextEditingController(
      text: page?.bodyAr ?? _metadataText(metadata, 'body_ar'),
    );
    _imageUrlController = TextEditingController(text: page?.imageUrl ?? '');
    _ctaLabelController = TextEditingController(text: page?.ctaLabel ?? '');
    _ctaLabelArController = TextEditingController(
      text: _metadataText(metadata, 'cta_label_ar'),
    );
    _ctaUrlController = TextEditingController(text: page?.ctaUrl ?? '');
    _eyebrowController = TextEditingController(
      text: _metadataText(metadata, 'eyebrow'),
    );
    _eyebrowArController = TextEditingController(
      text: _metadataText(metadata, 'eyebrow_ar'),
    );
    _secondaryLabelController = TextEditingController(
      text: _metadataText(metadata, 'secondary_label'),
    );
    _secondaryLabelArController = TextEditingController(
      text: _metadataText(metadata, 'secondary_label_ar'),
    );
    _metricController = TextEditingController(
      text: _metadataText(metadata, 'metric'),
    );
    _metricArController = TextEditingController(
      text: _metadataText(metadata, 'metric_ar'),
    );
    _sortOrderController =
        TextEditingController(text: '${page?.sortOrder ?? 0}');
    _section = page?.section ??
        widget.preset?.section ??
        widget.initialSection ??
        'hero_banner';
    _regionCode = page?.regionCode;
    _isActive = page?.isActive ?? true;
  }

  @override
  void dispose() {
    _slugController.dispose();
    _titleController.dispose();
    _titleArController.dispose();
    _excerptController.dispose();
    _excerptArController.dispose();
    _bodyController.dispose();
    _bodyArController.dispose();
    _imageUrlController.dispose();
    _ctaLabelController.dispose();
    _ctaLabelArController.dispose();
    _ctaUrlController.dispose();
    _eyebrowController.dispose();
    _eyebrowArController.dispose();
    _secondaryLabelController.dispose();
    _secondaryLabelArController.dispose();
    _metricController.dispose();
    _metricArController.dispose();
    _sortOrderController.dispose();
    super.dispose();
  }

  Future<void> _dismiss([String? result]) async {
    FocusManager.instance.primaryFocus?.unfocus();
    await Future<void>.delayed(Duration.zero);
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop(result);
  }

  Future<void> _pickImage() async {
    if (_uploadingImage) {
      return;
    }
    final selected = await pickAdminImage();
    if (selected == null) {
      return;
    }

    setState(() => _uploadingImage = true);
    try {
      final uploadedUrl = await widget.apiService.uploadProductImage(
        bytes: selected.bytes,
        filename: selected.filename,
        contentType: selected.contentType,
      );
      if (!mounted) {
        return;
      }
      setState(() => _imageUrlController.text = uploadedUrl);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Image uploaded successfully.')),
      );
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
        setState(() => _uploadingImage = false);
      }
    }
  }

  String _resolvedSlug() {
    if (!_repeatableSections.contains(_section)) {
      return _slugController.text.trim();
    }
    final existingSlug = widget.page?.slug.trim() ?? '';
    if (existingSlug.isNotEmpty) {
      return existingSlug;
    }

    final titleSource = _titleController.text.trim().isNotEmpty
        ? _titleController.text.trim()
        : _section.replaceAll('_', ' ');
    final baseSlug = _slugify(titleSource);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return '$baseSlug-$timestamp';
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _saving = true);
    try {
      final metadata = Map<String, dynamic>.from(
        widget.page?.metadataJson ?? const <String, dynamic>{},
      );
      _writeMetadata(metadata, 'title_ar', _titleArController.text);
      _writeMetadata(metadata, 'excerpt_ar', _excerptArController.text);
      _writeMetadata(metadata, 'body_ar', _bodyArController.text);
      _writeMetadata(metadata, 'cta_label_ar', _ctaLabelArController.text);
      _writeMetadata(metadata, 'eyebrow', _eyebrowController.text);
      _writeMetadata(metadata, 'eyebrow_ar', _eyebrowArController.text);
      _writeMetadata(
        metadata,
        'secondary_label',
        _secondaryLabelController.text,
      );
      _writeMetadata(
        metadata,
        'secondary_label_ar',
        _secondaryLabelArController.text,
      );
      _writeMetadata(metadata, 'metric', _metricController.text);
      _writeMetadata(metadata, 'metric_ar', _metricArController.text);

      final resolvedSlug = _resolvedSlug();
      final payload = {
        'slug': resolvedSlug,
        'title': _titleController.text.trim(),
        'title_en': _titleController.text.trim(),
        'title_ar': _titleArController.text.trim(),
        'section': _section,
        'excerpt': _excerptController.text.trim(),
        'excerpt_en': _excerptController.text.trim(),
        'excerpt_ar': _excerptArController.text.trim(),
        'body': _bodyController.text.trim(),
        'body_en': _bodyController.text.trim(),
        'body_ar': _bodyArController.text.trim(),
        'image_url': _imageUrlController.text.trim(),
        'cta_label': _ctaLabelController.text.trim(),
        'cta_url': _ctaUrlController.text.trim(),
        'region_code': _regionCode,
        'metadata_json': metadata,
        'sort_order': int.tryParse(_sortOrderController.text.trim()) ?? 0,
        'is_active': _isActive,
      };
      if (widget.page == null) {
        await widget.apiService.createCmsPage(payload);
      } else {
        await widget.apiService.updateCmsPage(widget.page!.id, payload);
      }
      await _dismiss(widget.page == null ? 'created' : 'updated');
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
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final supportsHeroMetadata = _section == 'hero_banner';
    final autoSlugSection = _repeatableSections.contains(_section);
    final isBannerSection = {
      'hero_banner',
      'home_section_banner',
      'marketing_card',
    }.contains(_section);
    final isPolicyLikeSection = {
      'policy',
      'about_us',
      'contact_us',
    }.contains(_section);
    final titleLabel =
        isBannerSection ? 'Banner Title (English)' : 'Title (English)';
    final titleArLabel =
        isBannerSection ? 'Banner Title (Arabic)' : 'Title (Arabic)';
    final subtitleLabel = isBannerSection
        ? 'Banner Subtitle (English)'
        : 'Subtitle / Excerpt (English)';
    final subtitleArLabel =
        isBannerSection ? 'Banner Subtitle (Arabic)' : 'Excerpt (Arabic)';
    final bodyLabel = isPolicyLikeSection
        ? 'Page Content (English)'
        : 'Supporting Content (English)';
    final bodyArLabel =
        isPolicyLikeSection ? 'Page Content (Arabic)' : 'Body (Arabic)';
    final imageLabel = isBannerSection ? 'Banner Image' : 'Image';
    final ctaLabel = isBannerSection ? 'CTA Label (English)' : 'CTA Label';
    final ctaUrlLabel = isBannerSection ? 'Target Link' : 'CTA URL';
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 760,
          maxHeight: media.size.height * 0.88,
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.page == null
                          ? 'Add Content Item'
                          : 'Edit Content Item',
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                    ),
                  ),
                  IconButton(
                    onPressed: _saving ? null : () => _dismiss(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: _section,
                        decoration: const InputDecoration(labelText: 'Section'),
                        items: const [
                          DropdownMenuItem(
                            value: 'hero_banner',
                            child: Text('Hero Banner'),
                          ),
                          DropdownMenuItem(
                            value: 'home_section_banner',
                            child: Text('Home Section Banner'),
                          ),
                          DropdownMenuItem(
                            value: 'marketing_card',
                            child: Text('Marketing Card'),
                          ),
                          DropdownMenuItem(
                            value: 'delivery_information',
                            child: Text('Delivery Information'),
                          ),
                          DropdownMenuItem(
                            value: 'policy',
                            child: Text('Policy Page'),
                          ),
                          DropdownMenuItem(
                            value: 'about_us',
                            child: Text('About Us'),
                          ),
                          DropdownMenuItem(
                            value: 'contact_us',
                            child: Text('Contact Us'),
                          ),
                        ],
                        onChanged: (value) =>
                            setState(() => _section = value ?? _section),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String?>(
                        initialValue: _regionCode,
                        decoration: const InputDecoration(
                            labelText: 'Storefront Region'),
                        items: const [
                          DropdownMenuItem<String?>(
                            value: null,
                            child: Text('All regions'),
                          ),
                          DropdownMenuItem<String?>(
                            value: 'sa',
                            child: Text('Saudi Arabia (SA)'),
                          ),
                          DropdownMenuItem<String?>(
                            value: 'ae',
                            child: Text('United Arab Emirates (AE)'),
                          ),
                        ],
                        onChanged: (value) =>
                            setState(() => _regionCode = value),
                      ),
                      const SizedBox(height: 12),
                      if (autoSlugSection) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceRaised,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Slider item mode',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Each banner slide gets its own internal slug automatically. Add multiple slides and control the homepage slider order with Sort Order.',
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ] else ...[
                        TextFormField(
                          controller: _slugController,
                          decoration: const InputDecoration(labelText: 'Slug'),
                          validator: (value) => (value ?? '').trim().isEmpty
                              ? 'Slug is required.'
                              : null,
                        ),
                        const SizedBox(height: 12),
                      ],
                      TextFormField(
                        controller: _titleController,
                        decoration: InputDecoration(labelText: titleLabel),
                        validator: (value) => (value ?? '').trim().isEmpty
                            ? 'Title is required.'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _titleArController,
                        decoration: InputDecoration(labelText: titleArLabel),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _excerptController,
                        maxLines: 2,
                        decoration: InputDecoration(labelText: subtitleLabel),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _excerptArController,
                        maxLines: 2,
                        decoration: InputDecoration(labelText: subtitleArLabel),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _bodyController,
                        maxLines: 7,
                        decoration: InputDecoration(labelText: bodyLabel),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _bodyArController,
                        maxLines: 7,
                        decoration: InputDecoration(labelText: bodyArLabel),
                      ),
                      const SizedBox(height: 12),
                      _ImageUploadField(
                        label: imageLabel,
                        imageUrl: _imageUrlController.text.trim(),
                        uploading: _uploadingImage,
                        onUpload: _pickImage,
                        onRemove: _imageUrlController.text.trim().isEmpty
                            ? null
                            : () => setState(() => _imageUrlController.clear()),
                      ),
                      const SizedBox(height: 12),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final stacked = constraints.maxWidth < 560;
                          final ctaLabelField = TextFormField(
                            controller: _ctaLabelController,
                            decoration: InputDecoration(labelText: ctaLabel),
                          );
                          final ctaUrlField = TextFormField(
                            controller: _ctaUrlController,
                            decoration: InputDecoration(labelText: ctaUrlLabel),
                          );
                          if (stacked) {
                            return Column(
                              children: [
                                ctaLabelField,
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _ctaLabelArController,
                                  decoration: const InputDecoration(
                                    labelText: 'CTA Label (Arabic)',
                                  ),
                                ),
                                const SizedBox(height: 12),
                                ctaUrlField,
                              ],
                            );
                          }
                          return Row(
                            children: [
                              Expanded(child: ctaLabelField),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: _ctaLabelArController,
                                  decoration: const InputDecoration(
                                    labelText: 'CTA Label (Arabic)',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(child: ctaUrlField),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      if (supportsHeroMetadata) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceRaised,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Hero banner display metadata',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Use these fields for the eyebrow, secondary action label, and metric pill shown on the homepage slider.',
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _eyebrowController,
                                decoration: const InputDecoration(
                                  labelText: 'Eyebrow',
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _eyebrowArController,
                                decoration: const InputDecoration(
                                  labelText: 'Eyebrow (Arabic)',
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _secondaryLabelController,
                                decoration: const InputDecoration(
                                  labelText: 'Secondary Action Label',
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _secondaryLabelArController,
                                decoration: const InputDecoration(
                                  labelText: 'Secondary Action Label (Arabic)',
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _metricController,
                                decoration: const InputDecoration(
                                  labelText: 'Metric Pill Label',
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _metricArController,
                                decoration: const InputDecoration(
                                  labelText: 'Metric Pill Label (Arabic)',
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      TextFormField(
                        controller: _sortOrderController,
                        decoration:
                            const InputDecoration(labelText: 'Sort Order'),
                        keyboardType: TextInputType.number,
                      ),
                      SwitchListTile(
                        value: _isActive,
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Active'),
                        onChanged: (value) => setState(() => _isActive = value),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final stacked = constraints.maxWidth < 420;
                  final cancelButton = TextButton(
                    onPressed: _saving ? null : () => _dismiss(),
                    child: const Text('Cancel'),
                  );
                  final saveButton = ElevatedButton(
                    onPressed: _saving ? null : _save,
                    child: Text(_saving ? 'Saving...' : 'Save'),
                  );
                  if (stacked) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        cancelButton,
                        const SizedBox(height: 10),
                        saveButton,
                      ],
                    );
                  }
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      cancelButton,
                      const SizedBox(width: 12),
                      saveButton,
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _metadataText(Map<String, dynamic> metadata, String key) {
  final value = metadata[key]?.toString().trim();
  return value == null || value.isEmpty ? '' : value;
}

void _writeMetadata(Map<String, dynamic> metadata, String key, String value) {
  final normalized = value.trim();
  if (normalized.isEmpty) {
    metadata.remove(key);
    return;
  }
  metadata[key] = normalized;
}

String _slugify(String value) {
  final normalized = value.trim().toLowerCase();
  final buffer = StringBuffer();
  var previousWasSeparator = false;

  for (final rune in normalized.runes) {
    final character = String.fromCharCode(rune);
    final isLetter = rune >= 97 && rune <= 122;
    final isDigit = rune >= 48 && rune <= 57;
    if (isLetter || isDigit) {
      buffer.write(character);
      previousWasSeparator = false;
      continue;
    }
    if (!previousWasSeparator) {
      buffer.write('-');
      previousWasSeparator = true;
    }
  }

  final collapsed = buffer.toString().replaceAll(RegExp('-+'), '-');
  final trimmed = collapsed.replaceFirst(RegExp('^-+'), '').replaceFirst(
        RegExp('-+\$'),
        '',
      );
  return trimmed.isEmpty ? 'content-item' : trimmed;
}

class _ImageUploadField extends StatelessWidget {
  final String label;
  final String imageUrl;
  final bool uploading;
  final VoidCallback onUpload;
  final VoidCallback? onRemove;

  const _ImageUploadField({
    required this.label,
    required this.imageUrl,
    required this.uploading,
    required this.onUpload,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage = imageUrl.trim().isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            hasImage
                ? 'Uploaded image will be used on the storefront immediately after saving.'
                : 'Upload an image instead of pasting a manual URL.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textMuted,
                  height: 1.45,
                ),
          ),
          const SizedBox(height: 14),
          if (hasImage) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: PremiumNetworkImage(
                imageUrl: imageUrl,
                borderRadius: BorderRadius.circular(18),
                height: 180,
                width: double.infinity,
                fallbackIcon: Icons.image_outlined,
              ),
            ),
            const SizedBox(height: 14),
          ],
          LayoutBuilder(
            builder: (context, constraints) {
              final stacked = constraints.maxWidth < 460;
              final uploadButton = OutlinedButton.icon(
                onPressed: uploading ? null : onUpload,
                icon: uploading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        hasImage
                            ? Icons.refresh_rounded
                            : Icons.upload_file_rounded,
                      ),
                label: Text(
                  uploading
                      ? 'Uploading...'
                      : hasImage
                          ? 'Replace Image'
                          : 'Upload Image',
                ),
              );
              final removeButton = OutlinedButton.icon(
                onPressed: uploading ? null : onRemove,
                icon: const Icon(Icons.delete_outline),
                label: const Text('Remove'),
              );
              if (stacked) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    uploadButton,
                    if (hasImage && onRemove != null) ...[
                      const SizedBox(height: 10),
                      removeButton,
                    ],
                  ],
                );
              }
              return Row(
                children: [
                  uploadButton,
                  if (hasImage && onRemove != null) ...[
                    const SizedBox(width: 12),
                    removeButton,
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _FaqEditorDialog extends StatefulWidget {
  final AdminApiService apiService;
  final AdminFaqModel? faq;

  const _FaqEditorDialog({
    required this.apiService,
    this.faq,
  });

  @override
  State<_FaqEditorDialog> createState() => _FaqEditorDialogState();
}

class _FaqEditorDialogState extends State<_FaqEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _questionController;
  late final TextEditingController _questionArController;
  late final TextEditingController _answerController;
  late final TextEditingController _answerArController;
  late final TextEditingController _sortOrderController;
  bool _isActive = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final faq = widget.faq;
    _questionController = TextEditingController(text: faq?.question ?? '');
    _questionArController = TextEditingController(text: faq?.questionAr ?? '');
    _answerController = TextEditingController(text: faq?.answer ?? '');
    _answerArController = TextEditingController(text: faq?.answerAr ?? '');
    _sortOrderController =
        TextEditingController(text: '${faq?.sortOrder ?? 0}');
    _isActive = faq?.isActive ?? true;
  }

  @override
  void dispose() {
    _questionController.dispose();
    _questionArController.dispose();
    _answerController.dispose();
    _answerArController.dispose();
    _sortOrderController.dispose();
    super.dispose();
  }

  Future<void> _dismiss([String? result]) async {
    FocusManager.instance.primaryFocus?.unfocus();
    await Future<void>.delayed(Duration.zero);
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop(result);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _saving = true);
    try {
      final payload = {
        'question': _questionController.text.trim(),
        'question_ar': _questionArController.text.trim(),
        'answer': _answerController.text.trim(),
        'answer_ar': _answerArController.text.trim(),
        'sort_order': int.tryParse(_sortOrderController.text.trim()) ?? 0,
        'is_active': _isActive,
      };
      if (widget.faq == null) {
        await widget.apiService.createFaq(payload);
      } else {
        await widget.apiService.updateFaq(widget.faq!.id, payload);
      }
      await _dismiss(widget.faq == null ? 'created' : 'updated');
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
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 680,
          maxHeight: media.size.height * 0.82,
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.faq == null ? 'Add FAQ' : 'Edit FAQ',
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                    ),
                  ),
                  IconButton(
                    onPressed: _saving ? null : () => _dismiss(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _questionController,
                        decoration: const InputDecoration(
                          labelText: 'Question (English)',
                        ),
                        validator: (value) => (value ?? '').trim().isEmpty
                            ? 'Question is required.'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _questionArController,
                        decoration: const InputDecoration(
                          labelText: 'Question (Arabic)',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _answerController,
                        maxLines: 5,
                        decoration: const InputDecoration(
                          labelText: 'Answer (English)',
                        ),
                        validator: (value) => (value ?? '').trim().isEmpty
                            ? 'Answer is required.'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _answerArController,
                        maxLines: 5,
                        decoration: const InputDecoration(
                          labelText: 'Answer (Arabic)',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _sortOrderController,
                        decoration:
                            const InputDecoration(labelText: 'Sort Order'),
                        keyboardType: TextInputType.number,
                      ),
                      SwitchListTile(
                        value: _isActive,
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Active'),
                        onChanged: (value) => setState(() => _isActive = value),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final stacked = constraints.maxWidth < 420;
                  final cancelButton = TextButton(
                    onPressed: _saving ? null : () => _dismiss(),
                    child: const Text('Cancel'),
                  );
                  final saveButton = ElevatedButton(
                    onPressed: _saving ? null : _save,
                    child: Text(_saving ? 'Saving...' : 'Save'),
                  );
                  if (stacked) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        cancelButton,
                        const SizedBox(height: 10),
                        saveButton,
                      ],
                    );
                  }
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      cancelButton,
                      const SizedBox(width: 12),
                      saveButton,
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContentError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ContentError({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Unable to load content management data.',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(message),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
