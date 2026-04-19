import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../models/product_model.dart';
import '../models/admin_review_model.dart';
import '../services/admin_api_service.dart';
import '../widgets/admin_page_frame.dart';

class AdminReviewsPage extends StatefulWidget {
  final AdminApiService apiService;

  const AdminReviewsPage({
    super.key,
    required this.apiService,
  });

  @override
  State<AdminReviewsPage> createState() => _AdminReviewsPageState();
}

class _AdminReviewsPageState extends State<AdminReviewsPage> {
  int? _productId;
  int? _rating;
  String? _status;
  bool _loading = true;
  bool _productsLoading = true;
  String? _error;
  List<AdminReviewModel> _reviews = const [];
  List<ProductModel> _products = const [];

  static const _statuses = <String>['pending', 'approved', 'rejected'];
  static const _ratings = <int>[5, 4, 3, 2, 1];

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
        widget.apiService.fetchReviews(
          productId: _productId,
          rating: _rating,
          status: _status,
        ),
        widget.apiService.fetchProducts(),
      ]);
      if (!mounted) {
        return;
      }
      setState(() {
        _reviews = results[0] as List<AdminReviewModel>;
        _products = results[1] as List<ProductModel>;
        _loading = false;
        _productsLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
        _loading = false;
        _productsLoading = false;
      });
    }
  }

  int _countByStatus(String status) {
    return _reviews.where((review) => review.moderationStatus == status).length;
  }

  Future<void> _openDetail(AdminReviewModel review) async {
    final changed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _ReviewDetailDialog(
        apiService: widget.apiService,
        reviewId: review.id,
      ),
    );
    if (changed == true) {
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminPageFrame(
      title: 'Reviews Moderation',
      subtitle:
          'Moderate customer reviews, keep product ratings clean, and preserve verified purchase credibility.',
      actions: [
        OutlinedButton.icon(
          onPressed: _load,
          icon: const Icon(Icons.refresh),
          label: const Text('Refresh'),
        ),
      ],
      child: Column(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 980;
              final filterCard = Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: AppColors.softPanelGradient,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.border),
                  boxShadow: AppColors.softShadow,
                ),
                child: compact
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: _buildFilterFields(compact: compact),
                      )
                    : Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        crossAxisAlignment: WrapCrossAlignment.end,
                        children: _buildFilterFields(compact: compact),
                      ),
              );

              final metricCards = Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  _MetricCard(
                    label: 'Pending',
                    value: _countByStatus('pending'),
                    helper: 'Awaiting moderation',
                    accent: AppColors.accentGold,
                    icon: Icons.pending_actions_outlined,
                  ),
                  _MetricCard(
                    label: 'Approved',
                    value: _countByStatus('approved'),
                    helper: 'Visible on storefront',
                    accent: const Color(0xFF4C8A5A),
                    icon: Icons.verified_outlined,
                  ),
                  _MetricCard(
                    label: 'Rejected',
                    value: _countByStatus('rejected'),
                    helper: 'Hidden from storefront',
                    accent: const Color(0xFF9A4D45),
                    icon: Icons.gpp_bad_outlined,
                  ),
                ]
                    .map(
                      (card) => SizedBox(
                        width: compact ? double.infinity : 240,
                        child: card,
                      ),
                    )
                    .toList(),
              );

              return Column(
                children: [
                  filterCard,
                  const SizedBox(height: 18),
                  metricCards,
                ],
              );
            },
          ),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.border),
              boxShadow: AppColors.softShadow,
            ),
            child: _loading
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(48),
                      child: CircularProgressIndicator(),
                    ),
                  )
                : _error != null
                    ? _ReviewsError(message: _error!, onRetry: _load)
                    : _reviews.isEmpty
                        ? const _EmptyReviewsState()
                        : SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              dataRowMinHeight: 72,
                              dataRowMaxHeight: 88,
                              columns: const [
                                DataColumn(label: Text('Product')),
                                DataColumn(label: Text('Customer')),
                                DataColumn(label: Text('Rating')),
                                DataColumn(label: Text('Status')),
                                DataColumn(label: Text('Verified')),
                                DataColumn(label: Text('Created')),
                                DataColumn(label: Text('Actions')),
                              ],
                              rows: _reviews
                                  .map(
                                    (review) => DataRow(
                                      cells: [
                                        DataCell(
                                          ConstrainedBox(
                                            constraints:
                                                const BoxConstraints(maxWidth: 220),
                                            child: Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  review.productName ??
                                                      'Product #${review.productId}',
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                                if ((review.title ?? '')
                                                    .trim()
                                                    .isNotEmpty)
                                                  Text(
                                                    review.title!,
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .bodySmall,
                                                  ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        DataCell(
                                          ConstrainedBox(
                                            constraints:
                                                const BoxConstraints(maxWidth: 210),
                                            child: Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(review.customerName ?? '-'),
                                                Text(
                                                  review.customerEmail ?? '-',
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .bodySmall,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        DataCell(_StarRating(rating: review.rating)),
                                        DataCell(
                                          _StatusPill(
                                            status: review.moderationStatus,
                                          ),
                                        ),
                                        DataCell(
                                          Icon(
                                            review.isVerifiedPurchase
                                                ? Icons.check_circle
                                                : Icons.remove_circle_outline,
                                            size: 18,
                                            color: review.isVerifiedPurchase
                                                ? const Color(0xFF4C8A5A)
                                                : AppColors.muted,
                                          ),
                                        ),
                                        DataCell(Text(_formatDate(review.createdAt))),
                                        DataCell(
                                          TextButton(
                                            onPressed: () => _openDetail(review),
                                            child: const Text('Review'),
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                  .toList(),
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildFilterFields({required bool compact}) {
    return [
      SizedBox(
        width: compact ? double.infinity : 320,
        child: DropdownButtonFormField<int?>(
          initialValue: _productId,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Product',
            prefixIcon: Icon(Icons.inventory_2_outlined),
          ),
          items: [
            const DropdownMenuItem<int?>(
              value: null,
              child: Text('All products'),
            ),
            ..._products.map(
              (product) => DropdownMenuItem<int?>(
                value: product.id,
                child: Text(product.name),
              ),
            ),
          ],
          onChanged: _productsLoading
              ? null
              : (value) => setState(() => _productId = value),
        ),
      ),
      SizedBox(
        width: compact ? double.infinity : 180,
        child: DropdownButtonFormField<int?>(
          initialValue: _rating,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Rating',
            prefixIcon: Icon(Icons.star_outline),
          ),
          items: [
            const DropdownMenuItem<int?>(
              value: null,
              child: Text('All ratings'),
            ),
            ..._ratings.map(
              (rating) => DropdownMenuItem<int?>(
                value: rating,
                child: Text('$rating stars'),
              ),
            ),
          ],
          onChanged: (value) => setState(() => _rating = value),
        ),
      ),
      SizedBox(
        width: compact ? double.infinity : 220,
        child: DropdownButtonFormField<String?>(
          initialValue: _status,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Status',
            prefixIcon: Icon(Icons.rule_folder_outlined),
          ),
          items: [
            const DropdownMenuItem<String?>(
              value: null,
              child: Text('All statuses'),
            ),
            ..._statuses.map(
              (status) => DropdownMenuItem<String?>(
                value: status,
                child: Text(_labelForStatus(status)),
              ),
            ),
          ],
          onChanged: (value) => setState(() => _status = value),
        ),
      ),
      ElevatedButton.icon(
        onPressed: _load,
        icon: const Icon(Icons.filter_alt_outlined),
        label: const Text('Apply'),
      ),
      TextButton(
        onPressed: () {
          setState(() {
            _productId = null;
            _rating = null;
            _status = null;
          });
          _load();
        },
        child: const Text('Reset'),
      ),
    ];
  }
}

class _ReviewDetailDialog extends StatefulWidget {
  final AdminApiService apiService;
  final int reviewId;

  const _ReviewDetailDialog({
    required this.apiService,
    required this.reviewId,
  });

  @override
  State<_ReviewDetailDialog> createState() => _ReviewDetailDialogState();
}

class _ReviewDetailDialogState extends State<_ReviewDetailDialog> {
  final _notesController = TextEditingController();
  AdminReviewModel? _review;
  bool _loading = true;
  bool _saving = false;
  bool _changed = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final review = await widget.apiService.fetchReview(widget.reviewId);
      if (!mounted) {
        return;
      }
      _notesController.text = review.moderationNotes ?? '';
      setState(() {
        _review = review;
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

  Future<void> _updateReview(String status) async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final updated = await widget.apiService.updateReview(
        widget.reviewId,
        {
          'moderation_status': status,
          'moderation_notes': _notesController.text.trim(),
        },
      );
      if (!mounted) {
        return;
      }
      _notesController.text = updated.moderationNotes ?? '';
      setState(() {
        _review = updated;
        _saving = false;
        _changed = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Review marked as ${_labelForStatus(status)}.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
        _saving = false;
      });
    }
  }

  Future<void> _deleteReview() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.apiService.deleteReview(widget.reviewId);
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _loading
              ? const SizedBox(
                  height: 320,
                  child: Center(child: CircularProgressIndicator()),
                )
              : _error != null && _review == null
                  ? _ReviewsError(message: _error!, onRetry: _load)
                  : _buildContent(context),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final review = _review;
    if (review == null) {
      return const SizedBox.shrink();
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      review.productName ?? 'Product #${review.productId}',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      review.customerName ?? review.customerEmail ?? 'Customer',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: AppColors.primaryDark,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      review.customerEmail ?? 'No email available',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.textMuted,
                          ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: _saving
                    ? null
                    : () => Navigator.of(context).pop(_changed),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _StatusPill(status: review.moderationStatus),
              _InfoChip(
                icon: Icons.star_outline,
                label: '${review.rating} / 5 rating',
              ),
              _InfoChip(
                icon: review.isVerifiedPurchase
                    ? Icons.verified_outlined
                    : Icons.shield_outlined,
                label: review.isVerifiedPurchase
                    ? 'Verified purchase'
                    : 'Unverified purchase',
              ),
              if (review.orderId != null)
                _InfoChip(
                  icon: Icons.receipt_long_outlined,
                  label: 'Order #${review.orderId}',
                ),
              _InfoChip(
                icon: Icons.schedule_outlined,
                label: _formatDate(review.createdAt),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if ((review.title ?? '').trim().isNotEmpty) ...[
            Text(
              review.title!,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 10),
          ],
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
            ),
            child: Text(
              (review.body ?? '').trim().isEmpty
                  ? 'No review body was submitted for this rating.'
                  : review.body!,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    height: 1.5,
                    color: AppColors.textDark,
                  ),
            ),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _notesController,
            enabled: !_saving,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Moderation notes',
              hintText:
                  'Capture why this review was approved, rejected, or escalated.',
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: const TextStyle(
                color: Color(0xFF9A4D45),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.spaceBetween,
            children: [
              OutlinedButton.icon(
                onPressed: _saving ? null : _deleteReview,
                icon: const Icon(Icons.delete_outline),
                label: const Text('Delete'),
              ),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  TextButton(
                    onPressed: _saving
                        ? null
                        : () => Navigator.of(context).pop(_changed),
                    child: const Text('Close'),
                  ),
                  ElevatedButton.icon(
                    onPressed: _saving ? null : () => _updateReview('rejected'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF9A4D45),
                      foregroundColor: Colors.white,
                    ),
                    icon: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.block_outlined),
                    label: const Text('Reject'),
                  ),
                  ElevatedButton.icon(
                    onPressed: _saving ? null : () => _updateReview('approved'),
                    icon: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check_circle_outline),
                    label: const Text('Approve'),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final int value;
  final String helper;
  final Color accent;
  final IconData icon;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.helper,
    required this.accent,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: accent),
          ),
          const SizedBox(height: 18),
          Text(
            '$value',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            helper,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textMuted,
                ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String status;

  const _StatusPill({
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final palette = switch (status) {
      'approved' => (background: const Color(0xFFE4F3E7), foreground: const Color(0xFF2D6A3B)),
      'rejected' => (background: const Color(0xFFF8E3E0), foreground: const Color(0xFF93463E)),
      _ => (background: const Color(0xFFF8EFD9), foreground: const Color(0xFF916A22)),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: palette.background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _labelForStatus(status),
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: palette.foreground,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.primaryDark),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

class _StarRating extends StatelessWidget {
  final int rating;

  const _StarRating({
    required this.rating,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        5,
        (index) => Icon(
          index < rating ? Icons.star_rounded : Icons.star_border_rounded,
          size: 18,
          color: AppColors.accentGold,
        ),
      ),
    );
  }
}

class _ReviewsError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ReviewsError({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.error_outline,
            color: Color(0xFF9A4D45),
            size: 42,
          ),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 16),
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

class _EmptyReviewsState extends StatelessWidget {
  const _EmptyReviewsState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              gradient: AppColors.goldGradient,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(Icons.rate_review_outlined, color: Colors.white),
          ),
          const SizedBox(height: 16),
          Text(
            'No reviews match the current filters.',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            'Adjust the product, rating, or status filters to inspect another moderation queue.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textMuted,
                ),
          ),
        ],
      ),
    );
  }
}

String _labelForStatus(String status) {
  switch (status) {
    case 'approved':
      return 'Approved';
    case 'rejected':
      return 'Rejected';
    default:
      return 'Pending';
  }
}

String _formatDate(String? value) {
  if (value == null || value.trim().isEmpty) {
    return '-';
  }
  final parsed = DateTime.tryParse(value);
  if (parsed == null) {
    return value;
  }
  final month = parsed.month.toString().padLeft(2, '0');
  final day = parsed.day.toString().padLeft(2, '0');
  final hour = parsed.hour.toString().padLeft(2, '0');
  final minute = parsed.minute.toString().padLeft(2, '0');
  return '${parsed.year}-$month-$day $hour:$minute';
}
