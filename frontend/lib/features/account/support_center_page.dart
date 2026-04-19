import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants/app_colors.dart';
import '../../models/support_settings_model.dart';
import '../../services/api_service.dart';
import 'faqs_page.dart';

class SupportCenterPage extends StatefulWidget {
  final ApiService apiService;

  const SupportCenterPage({
    super.key,
    required this.apiService,
  });

  @override
  State<SupportCenterPage> createState() => _SupportCenterPageState();
}

class _SupportCenterPageState extends State<SupportCenterPage> {
  late Future<SupportSettingsModel> _settingsFuture;

  @override
  void initState() {
    super.initState();
    _settingsFuture = widget.apiService.fetchSupportSettings();
  }

  void _reload() {
    setState(() {
      _settingsFuture = widget.apiService.fetchSupportSettings();
    });
  }

  Future<void> _copyText(String label, String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label copied to clipboard.')),
    );
  }

  String _whatsAppLink(String value) {
    final normalized = value.replaceAll(RegExp(r'[^0-9]'), '');
    return normalized.isEmpty ? value : 'https://wa.me/$normalized';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Support & Contact')),
      body: FutureBuilder<SupportSettingsModel>(
        future: _settingsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return _SupportStateCard(
              title: 'Unable to load support details',
              description:
                  'The latest contact and support information could not be retrieved right now.',
              actionLabel: 'Retry',
              onPressed: _reload,
            );
          }

          final settings = snapshot.data ?? const SupportSettingsModel();
          final socialRows = <({String label, String? value})>[
            (label: 'Facebook', value: settings.facebookUrl),
            (label: 'Instagram', value: settings.instagramUrl),
            (label: 'Twitter / X', value: settings.twitterUrl),
            (label: 'TikTok', value: settings.tiktokUrl),
            (label: 'Snapchat', value: settings.snapchatUrl),
            (label: 'YouTube', value: settings.youtubeUrl),
          ].where((row) => (row.value ?? '').trim().isNotEmpty).toList();

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
            children: [
              _SupportPanel(
                title: 'Support channels',
                icon: Icons.support_agent_outlined,
                children: [
                  if ((settings.contactPhone ?? '').trim().isNotEmpty)
                    _ContactRow(
                      icon: Icons.phone_outlined,
                      label: 'Phone',
                      value: settings.contactPhone!,
                      onCopy: () =>
                          _copyText('Phone number', settings.contactPhone!),
                    ),
                  if ((settings.contactEmail ?? '').trim().isNotEmpty)
                    _ContactRow(
                      icon: Icons.email_outlined,
                      label: 'Email',
                      value: settings.contactEmail!,
                      onCopy: () =>
                          _copyText('Email', settings.contactEmail!),
                    ),
                  if ((settings.whatsappNumber ?? '').trim().isNotEmpty)
                    _ContactRow(
                      icon: Icons.chat_bubble_outline_rounded,
                      label:
                          settings.whatsappLabel?.trim().isNotEmpty == true
                              ? settings.whatsappLabel!
                              : 'WhatsApp',
                      value: _whatsAppLink(settings.whatsappNumber!),
                      onCopy: () => _copyText(
                        'WhatsApp link',
                        _whatsAppLink(settings.whatsappNumber!),
                      ),
                    ),
                  if ((settings.supportHours ?? '').trim().isNotEmpty)
                    _ContactRow(
                      icon: Icons.schedule_outlined,
                      label: 'Support hours',
                      value: settings.supportHours!,
                    ),
                  if ((settings.contactAddress ?? '').trim().isNotEmpty)
                    _ContactRow(
                      icon: Icons.location_on_outlined,
                      label: 'Address',
                      value: settings.contactAddress!,
                      onCopy: () =>
                          _copyText('Address', settings.contactAddress!),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              _SupportPanel(
                title: 'Self-service help',
                icon: Icons.menu_book_outlined,
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.quiz_outlined),
                    title: const Text('Frequently asked questions'),
                    subtitle: const Text(
                      'Read the latest answers managed from the admin panel.',
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => FaqsPage(apiService: widget.apiService),
                        ),
                      );
                    },
                  ),
                ],
              ),
              if (socialRows.isNotEmpty) ...[
                const SizedBox(height: 16),
                _SupportPanel(
                  title: 'Social channels',
                  icon: Icons.campaign_outlined,
                  children: [
                    for (final row in socialRows)
                      _ContactRow(
                        icon: Icons.link_rounded,
                        label: row.label,
                        value: row.value!,
                        onCopy: () => _copyText(row.label, row.value!),
                      ),
                  ],
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _SupportPanel extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _SupportPanel({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.creamSoft,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: AppColors.brownDeep),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onCopy;

  const _ContactRow({
    required this.icon,
    required this.label,
    required this.value,
    this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.creamSoft,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: AppColors.brown, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.goldMuted,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        height: 1.5,
                      ),
                ),
              ],
            ),
          ),
          if (onCopy != null)
            IconButton(
              onPressed: onCopy,
              icon: const Icon(Icons.copy_rounded),
              tooltip: 'Copy',
            ),
        ],
      ),
    );
  }
}

class _SupportStateCard extends StatelessWidget {
  final String title;
  final String description;
  final String actionLabel;
  final VoidCallback onPressed;

  const _SupportStateCard({
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
