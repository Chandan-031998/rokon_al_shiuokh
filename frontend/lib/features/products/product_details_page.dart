import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/extensions/localized_content.dart';
import '../../core/widgets/premium_network_image.dart';
import '../../localization/app_localizations.dart';
import '../../models/branch_model.dart';
import '../../models/product_model.dart';
import '../../services/api_service.dart';

class ProductDetailsPage extends StatefulWidget {
  final ProductModel product;
  final List<BranchModel> branches;
  final ApiService apiService;

  const ProductDetailsPage({
    super.key,
    required this.product,
    required this.branches,
    required this.apiService,
  });

  @override
  State<ProductDetailsPage> createState() => _ProductDetailsPageState();
}

class _ProductDetailsPageState extends State<ProductDetailsPage> {
  late int _quantity;
  int? _selectedBranchId;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _quantity = 1;
    _selectedBranchId = widget.product.branchId ??
        (widget.branches.isNotEmpty ? widget.branches.first.id : null);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    BranchModel? selectedBranch;
    for (final branch in widget.branches) {
      if (branch.id == _selectedBranchId) {
        selectedBranch = branch;
        break;
      }
    }

    return Scaffold(
      appBar: AppBar(title: Text(widget.product.localizedName(l10n))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          _DetailsVisual(imageUrl: widget.product.imageUrl),
          const SizedBox(height: 18),
          Text(
            widget.product.localizedName(l10n),
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          Text(
            'SAR ${widget.product.price.toStringAsFixed(0)}',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppColors.brownDeep,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 12),
          _MetaCard(
            title: l10n.t('product_pack_size'),
            value: _packSizeLabel(widget.product, l10n),
            icon: Icons.inventory_2_outlined,
          ),
          const SizedBox(height: 12),
          _MetaCard(
            title: l10n.t('product_description'),
            value: widget.product.description ??
                l10n.t('product_default_description'),
            icon: Icons.description_outlined,
          ),
          const SizedBox(height: 12),
          _BranchSelector(
            branches: widget.branches,
            selectedBranchId: _selectedBranchId,
            onChanged: (value) {
              setState(() => _selectedBranchId = value);
            },
          ),
          const SizedBox(height: 12),
          _QuantitySelector(
            quantity: _quantity,
            onDecrement:
                _quantity > 1 ? () => setState(() => _quantity -= 1) : null,
            onIncrement: () => setState(() => _quantity += 1),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _isSubmitting
                ? null
                : () => _addToCart(
                    selectedBranch?.name ?? l10n.t('orders_selected_branch')),
            child: Text(l10n.t('product_add_to_cart')),
          ),
        ],
      ),
    );
  }

  Future<void> _addToCart(String branchName) async {
    setState(() => _isSubmitting = true);
    try {
      await widget.apiService.addToCart(
        productId: widget.product.id,
        quantity: _quantity,
        branchId: _selectedBranchId,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.t(
              'product_add_success',
              {
                'quantity': '$_quantity',
                'name': widget.product.localizedName(context.l10n),
                'branch': branchName,
              },
            ),
          ),
        ),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.t('product_add_error'))),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }
}

class _DetailsVisual extends StatelessWidget {
  final String? imageUrl;

  const _DetailsVisual({this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return PremiumNetworkImage(
      imageUrl: imageUrl,
      height: 260,
      borderRadius: BorderRadius.circular(28),
      fallbackIcon: Icons.shopping_bag_outlined,
      fallbackIconSize: 48,
    );
  }
}

class _MetaCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _MetaCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.creamSoft,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: AppColors.brown),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: AppColors.goldMuted,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 6),
                Text(value),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BranchSelector extends StatelessWidget {
  final List<BranchModel> branches;
  final int? selectedBranchId;
  final ValueChanged<int?> onChanged;

  const _BranchSelector({
    required this.branches,
    required this.selectedBranchId,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<int?>(
      initialValue: selectedBranchId,
      items: branches
          .map(
            (branch) => DropdownMenuItem<int?>(
              value: branch.id,
              child: Text(branch.name),
            ),
          )
          .toList(),
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: context.l10n.t('product_branch_selection'),
        filled: true,
        fillColor: AppColors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppColors.border),
        ),
      ),
    );
  }
}

class _QuantitySelector extends StatelessWidget {
  final int quantity;
  final VoidCallback? onDecrement;
  final VoidCallback onIncrement;

  const _QuantitySelector({
    required this.quantity,
    required this.onDecrement,
    required this.onIncrement,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Text(
            context.l10n.t('product_quantity'),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const Spacer(),
          IconButton(
            onPressed: onDecrement,
            icon: const Icon(Icons.remove_circle_outline),
          ),
          Text(
            '$quantity',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          IconButton(
            onPressed: onIncrement,
            icon: const Icon(Icons.add_circle_outline),
          ),
        ],
      ),
    );
  }
}

String _packSizeLabel(ProductModel product, AppLocalizations l10n) {
  final source =
      '${product.name} ${product.description ?? ''} ${product.sku ?? ''}';
  final match = RegExp(r'(\d+\s?(?:g|kg|ml|l|pack))', caseSensitive: false)
      .firstMatch(source);
  return match?.group(1) ?? l10n.t('product_standard_pack');
}
