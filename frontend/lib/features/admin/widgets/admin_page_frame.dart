import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';

class AdminPageFrame extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  final List<Widget> actions;

  const AdminPageFrame({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.actions = const <Widget>[],
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 980;

        return ListView(
          padding: EdgeInsets.fromLTRB(
            compact ? 20 : 28,
            compact ? 22 : 28,
            compact ? 20 : 28,
            compact ? 28 : 36,
          ),
          children: [
            if (compact) ...[
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textMuted,
                        ),
                  ),
                  if (actions.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    Wrap(spacing: 12, runSpacing: 12, children: actions),
                  ],
                ],
              ),
            ] else ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          subtitle,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: AppColors.textMuted,
                              ),
                        ),
                      ],
                    ),
                  ),
                  if (actions.isNotEmpty) ...[
                    const SizedBox(width: 20),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: Align(
                        alignment: Alignment.topRight,
                        child: Wrap(
                          alignment: WrapAlignment.end,
                          spacing: 12,
                          runSpacing: 12,
                          children: actions,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
            const SizedBox(height: 24),
            child,
          ],
        );
      },
    );
  }
}
