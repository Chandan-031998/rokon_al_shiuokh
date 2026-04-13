import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/extensions/localized_content.dart';
import '../../localization/app_localizations.dart';
import '../../models/branch_model.dart';
import '../../models/cart_item_model.dart';
import '../../models/cart_model.dart';
import '../../services/api_service.dart';
import 'order_success_page.dart';

enum CheckoutMode { delivery, pickup }

class CheckoutPage extends StatefulWidget {
  final ApiService apiService;

  const CheckoutPage({
    super.key,
    required this.apiService,
  });

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  final _formKey = GlobalKey<FormState>();
  final _labelController = TextEditingController();
  final _cityController = TextEditingController();
  final _neighborhoodController = TextEditingController();
  final _addressLineController = TextEditingController();
  final _notesController = TextEditingController();

  late Future<_CheckoutData> _checkoutFuture;
  CheckoutMode _mode = CheckoutMode.delivery;
  int? _selectedBranchId;
  bool _isPlacingOrder = false;

  @override
  void initState() {
    super.initState();
    _checkoutFuture = _loadCheckoutData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_labelController.text.trim().isEmpty) {
      _labelController.text = context.l10n.t('checkout_address_label_default');
    }
  }

  @override
  void dispose() {
    _labelController.dispose();
    _cityController.dispose();
    _neighborhoodController.dispose();
    _addressLineController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<_CheckoutData> _loadCheckoutData() async {
    final results = await Future.wait([
      widget.apiService.fetchCart(),
      widget.apiService.fetchBranches(),
    ]);
    final cart = results[0] as CartModel;
    final branches = results[1] as List<BranchModel>;
    if (_selectedBranchId == null && branches.isNotEmpty) {
      _selectedBranchId = cart.items.firstOrNull?.branchId ?? branches.first.id;
    }
    return _CheckoutData(cart: cart, branches: branches);
  }

  Future<void> _retry() async {
    setState(() {
      _checkoutFuture = _loadCheckoutData();
    });
    await _checkoutFuture;
  }

  Future<void> _placeOrder(CartModel cart, List<BranchModel> branches) async {
    if (_isPlacingOrder) {
      return;
    }
    if (_selectedBranchId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.t('checkout_select_branch_error'))),
      );
      return;
    }
    if (_mode == CheckoutMode.delivery && !_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isPlacingOrder = true);
    try {
      final order = await widget.apiService.placeOrder(
        orderType: _mode == CheckoutMode.delivery ? 'delivery' : 'pickup',
        branchId: _selectedBranchId!,
        notes: _notesController.text,
        address: _mode == CheckoutMode.delivery
            ? {
                'label': _labelController.text.trim(),
                'city': _cityController.text.trim(),
                'neighborhood': _neighborhoodController.text.trim(),
                'address_line': _addressLineController.text.trim(),
              }
            : null,
      );
      if (!mounted) {
        return;
      }
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => OrderSuccessPage(order: order),
        ),
      );
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
        setState(() => _isPlacingOrder = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.t('checkout_title'))),
      body: FutureBuilder<_CheckoutData>(
        future: _checkoutFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: _ErrorCard(onRetry: _retry),
              ),
            );
          }

          final data = snapshot.data!;
          if (data.cart.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: _EmptyCheckoutCard(),
              ),
            );
          }

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1180),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 940;
                  final form = _CheckoutForm(
                    formKey: _formKey,
                    mode: _mode,
                    selectedBranchId: _selectedBranchId,
                    branches: data.branches,
                    labelController: _labelController,
                    cityController: _cityController,
                    neighborhoodController: _neighborhoodController,
                    addressLineController: _addressLineController,
                    notesController: _notesController,
                    onModeChanged: (mode) => setState(() => _mode = mode),
                    onBranchChanged: (value) =>
                        setState(() => _selectedBranchId = value),
                  );
                  final summary = _OrderSummaryCard(
                    cart: data.cart,
                    mode: _mode,
                    onPlaceOrder: () => _placeOrder(data.cart, data.branches),
                    isPlacingOrder: _isPlacingOrder,
                  );

                  if (wide) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                            flex: 3, child: SingleChildScrollView(child: form)),
                        const SizedBox(width: 20),
                        Expanded(
                            flex: 2,
                            child: SingleChildScrollView(child: summary)),
                      ],
                    );
                  }

                  return ListView(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                    children: [
                      form,
                      const SizedBox(height: 18),
                      summary,
                    ],
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CheckoutData {
  final CartModel cart;
  final List<BranchModel> branches;

  const _CheckoutData({
    required this.cart,
    required this.branches,
  });
}

class _CheckoutForm extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final CheckoutMode mode;
  final int? selectedBranchId;
  final List<BranchModel> branches;
  final TextEditingController labelController;
  final TextEditingController cityController;
  final TextEditingController neighborhoodController;
  final TextEditingController addressLineController;
  final TextEditingController notesController;
  final ValueChanged<CheckoutMode> onModeChanged;
  final ValueChanged<int?> onBranchChanged;

  const _CheckoutForm({
    required this.formKey,
    required this.mode,
    required this.selectedBranchId,
    required this.branches,
    required this.labelController,
    required this.cityController,
    required this.neighborhoodController,
    required this.addressLineController,
    required this.notesController,
    required this.onModeChanged,
    required this.onBranchChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _HeroCard(mode: mode),
            const SizedBox(height: 18),
            _SectionCard(
              title: l10n.t('checkout_fulfilment_option'),
              child: Column(
                children: [
                  _ModeTile(
                    title: l10n.t('checkout_delivery_title'),
                    subtitle: l10n.t('checkout_delivery_subtitle'),
                    selected: mode == CheckoutMode.delivery,
                    icon: Icons.local_shipping_outlined,
                    onTap: () => onModeChanged(CheckoutMode.delivery),
                  ),
                  const SizedBox(height: 12),
                  _ModeTile(
                    title: l10n.t('checkout_pickup_title'),
                    subtitle: l10n.t('checkout_pickup_branch_note'),
                    selected: mode == CheckoutMode.pickup,
                    icon: Icons.storefront_outlined,
                    onTap: () => onModeChanged(CheckoutMode.pickup),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _SectionCard(
              title: l10n.t('checkout_branch_selection'),
              child: DropdownButtonFormField<int>(
                initialValue: selectedBranchId,
                items: branches
                    .map(
                      (branch) => DropdownMenuItem<int>(
                        value: branch.id,
                        child: Text(branch.name),
                      ),
                    )
                    .toList(),
                onChanged: onBranchChanged,
                decoration: _fieldDecoration(l10n.t('checkout_choose_branch')),
              ),
            ),
            if (mode == CheckoutMode.delivery) ...[
              const SizedBox(height: 16),
              _SectionCard(
                title: l10n.t('checkout_delivery_information'),
                child: Column(
                  children: [
                    TextFormField(
                      controller: labelController,
                      validator:
                          _requiredValidator(context, l10n.t('checkout_address_label')),
                      decoration: _fieldDecoration(l10n.t('checkout_address_label')),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: cityController,
                      validator: _requiredValidator(context, l10n.t('checkout_city')),
                      decoration: _fieldDecoration(l10n.t('checkout_city')),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: neighborhoodController,
                      validator: _requiredValidator(
                        context,
                        l10n.t('checkout_neighborhood'),
                      ),
                      decoration: _fieldDecoration(l10n.t('checkout_neighborhood')),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: addressLineController,
                      validator: _requiredValidator(
                        context,
                        l10n.t('checkout_address_line'),
                      ),
                      minLines: 3,
                      maxLines: 4,
                      decoration: _fieldDecoration(l10n.t('checkout_address_line')),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            _SectionCard(
              title: l10n.t('checkout_delivery_notes'),
              child: TextFormField(
                controller: notesController,
                minLines: 3,
                maxLines: 4,
                decoration: _fieldDecoration(
                  mode == CheckoutMode.delivery
                      ? l10n.t('checkout_delivery_notes_hint')
                      : l10n.t('checkout_pickup_notes_hint'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? Function(String?) _requiredValidator(
    BuildContext context,
    String label,
  ) {
    return (value) {
      if ((value ?? '').trim().isEmpty) {
        return context.l10n.t('validation_required_field', {'field': label});
      }
      return null;
    };
  }

  InputDecoration _fieldDecoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: AppColors.cream,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: AppColors.border),
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  final CheckoutMode mode;

  const _HeroCard({required this.mode});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.brownDeep, Color(0xFF4B2D21), AppColors.brown],
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A2D1A12),
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: -18,
            right: -12,
            child: Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Checkout',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: AppColors.white,
                    ),
              ),
              const SizedBox(height: 10),
              Text(
                mode == CheckoutMode.delivery
                    ? 'Complete your delivery details and select the best branch for fulfilment.'
                    : 'Choose your preferred branch and prepare for a smooth pickup experience.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.creamSoft,
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ModeTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool selected;
  final IconData icon;
  final VoidCallback onTap;

  const _ModeTile({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: selected
            ? const [
                BoxShadow(
                  color: Color(0x142D1A12),
                  blurRadius: 16,
                  offset: Offset(0, 8),
                ),
              ]
            : const [],
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: selected ? AppColors.creamSoft : AppColors.cream,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? AppColors.goldMuted : AppColors.border,
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(icon, color: AppColors.brown),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(subtitle,
                        style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
              ),
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_off,
                color: selected ? AppColors.goldMuted : AppColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.white, Color(0xFFFFFBF7)],
        ),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x102D1A12),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _OrderSummaryCard extends StatelessWidget {
  final CartModel cart;
  final CheckoutMode mode;
  final VoidCallback onPlaceOrder;
  final bool isPlacingOrder;

  const _OrderSummaryCard({
    required this.cart,
    required this.mode,
    required this.onPlaceOrder,
    required this.isPlacingOrder,
  });

  @override
  Widget build(BuildContext context) {
    final deliveryFee = mode == CheckoutMode.delivery ? 12.0 : 0.0;
    final total = cart.subtotal + deliveryFee;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.white, Color(0xFFFFFBF7)],
        ),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x122D1A12),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.t('brand_badge'),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.goldMuted,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.6,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            context.l10n.t('checkout_summary_title'),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 16),
          for (final item in cart.items) ...[
            _SummaryLine(item: item),
            const SizedBox(height: 12),
          ],
          const Divider(color: AppColors.border),
          const SizedBox(height: 12),
          _PriceRow(label: context.l10n.t('checkout_subtotal'), value: cart.subtotal),
          const SizedBox(height: 8),
          _PriceRow(
            label: context.l10n.t('checkout_delivery_fee'),
            value: deliveryFee,
          ),
          const SizedBox(height: 8),
          _PriceRow(
            label: context.l10n.t('checkout_total'),
            value: total,
            emphasize: true,
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: isPlacingOrder ? null : onPlaceOrder,
              child: Text(
                isPlacingOrder
                    ? context.l10n.t('checkout_placing_order')
                    : context.l10n.t('checkout_place_order'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryLine extends StatelessWidget {
  final CartItemModel item;

  const _SummaryLine({required this.item});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.product.localizedName(context.l10n),
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                context.l10n.t('checkout_qty', {'quantity': '${item.quantity}'}),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
        Text(
          '${context.l10n.t('currency_label')} ${item.lineTotal.toStringAsFixed(0)}',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
      ],
    );
  }
}

class _PriceRow extends StatelessWidget {
  final String label;
  final double value;
  final bool emphasize;

  const _PriceRow({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  @override
  Widget build(BuildContext context) {
    final style = emphasize
        ? Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: AppColors.brownDeep,
            )
        : Theme.of(context).textTheme.bodyLarge;

    return Row(
      children: [
        Text(label, style: style),
        const Spacer(),
        Text('${context.l10n.t('currency_label')} ${value.toStringAsFixed(0)}',
            style: style),
      ],
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final Future<void> Function() onRetry;

  const _ErrorCard({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: context.l10n.t('checkout_load_error_title'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.t('checkout_load_error_desc'),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: onRetry,
            child: Text(context.l10n.t('common_retry')),
          ),
        ],
      ),
    );
  }
}

class _EmptyCheckoutCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: context.l10n.t('checkout_empty_title'),
      child: Text(
        context.l10n.t('checkout_empty_desc'),
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }
}

extension<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
