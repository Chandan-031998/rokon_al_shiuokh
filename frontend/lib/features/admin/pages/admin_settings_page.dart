import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../admin_session_controller.dart';
import '../widgets/admin_page_frame.dart';

class AdminSettingsPage extends StatelessWidget {
  final AdminSessionController sessionController;

  const AdminSettingsPage({
    super.key,
    required this.sessionController,
  });

  @override
  Widget build(BuildContext context) {
    final user = sessionController.user;

    return AdminPageFrame(
      title: 'Settings',
      subtitle: 'Operational admin information and session controls for the current environment.',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Current Admin', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            Text(user?.fullName ?? 'Admin'),
            Text(user?.email ?? ''),
            const SizedBox(height: 18),
            Text('Platform Notes', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            const Text(
              'This admin panel is intended for desktop and tablet operations. '
              'Keep credentials restricted to admin users only.',
            ),
            const SizedBox(height: 18),
            Text('Pending Enhancements', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            const Text(
              'TODO: Add configurable admin preferences, notification rules, and printable order templates here.',
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: sessionController.logout,
              icon: const Icon(Icons.logout),
              label: const Text('Logout'),
            ),
          ],
        ),
      ),
    );
  }
}
