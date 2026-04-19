import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../models/admin_cms_page_model.dart';
import '../models/admin_faq_model.dart';
import '../models/admin_support_settings_model.dart';
import '../services/admin_api_service.dart';
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
  }) async {
    final changed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _CmsPageEditorDialog(
        apiService: widget.apiService,
        page: page,
        initialSection: initialSection,
      ),
    );
    if (changed == true) {
      await _load();
    }
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
      await _load();
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _openFaqEditor([AdminFaqModel? faq]) async {
    final changed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _FaqEditorDialog(
        apiService: widget.apiService,
        faq: faq,
      ),
    );
    if (changed == true) {
      await _load();
    }
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

  @override
  Widget build(BuildContext context) {
    return AdminPageFrame(
      title: 'Content Management',
      subtitle:
          'Manage hero banners, marketing content, policy pages, FAQs, support details, and social links from the admin panel.',
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
                    _ContentSummary(
                      pages: _pages,
                      faqs: _faqs,
                    ),
                    const SizedBox(height: 20),
                    _CmsGroupPanel(
                      title: 'Homepage Content',
                      actions: [
                        OutlinedButton.icon(
                          onPressed: () =>
                              _openPageEditor(initialSection: 'hero_banner'),
                          icon: const Icon(Icons.add),
                          label: const Text('Hero Banner'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => _openPageEditor(
                            initialSection: 'home_section_banner',
                          ),
                          icon: const Icon(Icons.add),
                          label: const Text('Home Banner'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => _openPageEditor(
                            initialSection: 'marketing_card',
                          ),
                          icon: const Icon(Icons.add),
                          label: const Text('Marketing Card'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => _openPageEditor(
                            initialSection: 'delivery_information',
                          ),
                          icon: const Icon(Icons.add),
                          label: const Text('Delivery Block'),
                        ),
                      ],
                      child: Column(
                        children: [
                          _CmsSectionList(
                            title: 'Hero Banners',
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
                        OutlinedButton.icon(
                          onPressed: () =>
                              _openPageEditor(initialSection: 'policy'),
                          icon: const Icon(Icons.add),
                          label: const Text('Policy Page'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () =>
                              _openPageEditor(initialSection: 'about_us'),
                          icon: const Icon(Icons.add),
                          label: const Text('About Us'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () =>
                              _openPageEditor(initialSection: 'contact_us'),
                          icon: const Icon(Icons.add),
                          label: const Text('Contact Us'),
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

  List<AdminCmsPageModel> _pagesForSection(String section) {
    final items = _pages.where((page) => page.section == section).toList();
    items.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return items;
  }
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
        value:
            '${pages.where((page) => {'policy', 'about_us', 'contact_us'}.contains(page.section)).length}',
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
          childAspectRatio: constraints.maxWidth >= 760 ? 1.9 : 2.8,
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if ((item.imageUrl ?? '').isNotEmpty)
            Container(
              width: 72,
              height: 72,
              margin: const EdgeInsets.only(right: 14),
              decoration: BoxDecoration(
                color: AppColors.creamSoft,
                borderRadius: BorderRadius.circular(16),
                image: DecorationImage(
                  fit: BoxFit.cover,
                  image: NetworkImage(item.imageUrl!),
                ),
              ),
            ),
          Expanded(
            child: Column(
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
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
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Edit'),
                    ),
                    const SizedBox(width: 10),
                    TextButton.icon(
                      onPressed: onDelete,
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Delete'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
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
          Row(
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
              ElevatedButton.icon(
                onPressed: () => onAdd(),
                icon: const Icon(Icons.add),
                label: const Text('Add FAQ'),
              ),
            ],
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
                          Text(faq.answer),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              OutlinedButton(
                                onPressed: () => onEdit(faq),
                                child: const Text('Edit'),
                              ),
                              const SizedBox(width: 10),
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
  late final TextEditingController _hoursController;
  late final TextEditingController _whatsappNumberController;
  late final TextEditingController _whatsappLabelController;
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
    _hoursController =
        TextEditingController(text: widget.settings.supportHours ?? '');
    _whatsappNumberController =
        TextEditingController(text: widget.settings.whatsappNumber ?? '');
    _whatsappLabelController =
        TextEditingController(text: widget.settings.whatsappLabel ?? '');
    _paymentCodLabelController =
        TextEditingController(text: widget.settings.paymentCodLabel ?? '');
    _paymentCardLabelController =
        TextEditingController(text: widget.settings.paymentCardLabel ?? '');
    _paymentBankTransferLabelController = TextEditingController(
      text: widget.settings.paymentBankTransferLabel ?? '',
    );
    _paymentCheckoutNoticeController =
        TextEditingController(text: widget.settings.paymentCheckoutNotice ?? '');
    _paymentCodEnabled = widget.settings.paymentCodEnabled;
    _paymentCardEnabled = widget.settings.paymentCardEnabled;
    _paymentBankTransferEnabled = widget.settings.paymentBankTransferEnabled;
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
  }

  @override
  void dispose() {
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _hoursController.dispose();
    _whatsappNumberController.dispose();
    _whatsappLabelController.dispose();
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
        'support_hours': _hoursController.text.trim(),
        'whatsapp_number': _whatsappNumberController.text.trim(),
        'whatsapp_label': _whatsappLabelController.text.trim(),
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
              decoration: const InputDecoration(labelText: 'Contact Address'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _hoursController,
              decoration: const InputDecoration(labelText: 'Support Hours'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _whatsappNumberController,
              decoration: const InputDecoration(labelText: 'WhatsApp Number'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _whatsappLabelController,
              decoration: const InputDecoration(labelText: 'WhatsApp Label'),
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

  const _CmsPageEditorDialog({
    required this.apiService,
    this.page,
    this.initialSection,
  });

  @override
  State<_CmsPageEditorDialog> createState() => _CmsPageEditorDialogState();
}

class _CmsPageEditorDialogState extends State<_CmsPageEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _slugController;
  late final TextEditingController _titleController;
  late final TextEditingController _excerptController;
  late final TextEditingController _bodyController;
  late final TextEditingController _imageUrlController;
  late final TextEditingController _ctaLabelController;
  late final TextEditingController _ctaUrlController;
  late final TextEditingController _sortOrderController;
  String _section = 'hero_banner';
  bool _isActive = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final page = widget.page;
    _slugController = TextEditingController(text: page?.slug ?? '');
    _titleController = TextEditingController(text: page?.title ?? '');
    _excerptController = TextEditingController(text: page?.excerpt ?? '');
    _bodyController = TextEditingController(text: page?.body ?? '');
    _imageUrlController = TextEditingController(text: page?.imageUrl ?? '');
    _ctaLabelController = TextEditingController(text: page?.ctaLabel ?? '');
    _ctaUrlController = TextEditingController(text: page?.ctaUrl ?? '');
    _sortOrderController =
        TextEditingController(text: '${page?.sortOrder ?? 0}');
    _section = page?.section ?? widget.initialSection ?? 'hero_banner';
    _isActive = page?.isActive ?? true;
  }

  @override
  void dispose() {
    _slugController.dispose();
    _titleController.dispose();
    _excerptController.dispose();
    _bodyController.dispose();
    _imageUrlController.dispose();
    _ctaLabelController.dispose();
    _ctaUrlController.dispose();
    _sortOrderController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _saving = true);
    try {
      final payload = {
        'slug': _slugController.text.trim(),
        'title': _titleController.text.trim(),
        'section': _section,
        'excerpt': _excerptController.text.trim(),
        'body': _bodyController.text.trim(),
        'image_url': _imageUrlController.text.trim(),
        'cta_label': _ctaLabelController.text.trim(),
        'cta_url': _ctaUrlController.text.trim(),
        'sort_order': int.tryParse(_sortOrderController.text.trim()) ?? 0,
        'is_active': _isActive,
      };
      if (widget.page == null) {
        await widget.apiService.createCmsPage(payload);
      } else {
        await widget.apiService.updateCmsPage(widget.page!.id, payload);
      }
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
    return AlertDialog(
      title: Text(widget.page == null ? 'Add Content Item' : 'Edit Content Item'),
      content: SizedBox(
        width: 760,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
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
                TextFormField(
                  controller: _slugController,
                  decoration: const InputDecoration(labelText: 'Slug'),
                  validator: (value) =>
                      (value ?? '').trim().isEmpty ? 'Slug is required.' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(labelText: 'Title'),
                  validator: (value) =>
                      (value ?? '').trim().isEmpty ? 'Title is required.' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _excerptController,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Excerpt'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _bodyController,
                  maxLines: 7,
                  decoration: const InputDecoration(labelText: 'Body'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _imageUrlController,
                  decoration: const InputDecoration(labelText: 'Image URL'),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _ctaLabelController,
                        decoration:
                            const InputDecoration(labelText: 'CTA Label'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _ctaUrlController,
                        decoration: const InputDecoration(labelText: 'CTA URL'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _sortOrderController,
                  decoration: const InputDecoration(labelText: 'Sort Order'),
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
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Saving...' : 'Save'),
        ),
      ],
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
  late final TextEditingController _answerController;
  late final TextEditingController _sortOrderController;
  bool _isActive = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final faq = widget.faq;
    _questionController = TextEditingController(text: faq?.question ?? '');
    _answerController = TextEditingController(text: faq?.answer ?? '');
    _sortOrderController = TextEditingController(text: '${faq?.sortOrder ?? 0}');
    _isActive = faq?.isActive ?? true;
  }

  @override
  void dispose() {
    _questionController.dispose();
    _answerController.dispose();
    _sortOrderController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _saving = true);
    try {
      final payload = {
        'question': _questionController.text.trim(),
        'answer': _answerController.text.trim(),
        'sort_order': int.tryParse(_sortOrderController.text.trim()) ?? 0,
        'is_active': _isActive,
      };
      if (widget.faq == null) {
        await widget.apiService.createFaq(payload);
      } else {
        await widget.apiService.updateFaq(widget.faq!.id, payload);
      }
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
    return AlertDialog(
      title: Text(widget.faq == null ? 'Add FAQ' : 'Edit FAQ'),
      content: SizedBox(
        width: 680,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _questionController,
                decoration: const InputDecoration(labelText: 'Question'),
                validator: (value) => (value ?? '').trim().isEmpty
                    ? 'Question is required.'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _answerController,
                maxLines: 5,
                decoration: const InputDecoration(labelText: 'Answer'),
                validator: (value) => (value ?? '').trim().isEmpty
                    ? 'Answer is required.'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _sortOrderController,
                decoration: const InputDecoration(labelText: 'Sort Order'),
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
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Saving...' : 'Save'),
        ),
      ],
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
