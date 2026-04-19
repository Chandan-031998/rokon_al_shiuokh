import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/extensions/localized_content.dart';
import '../../localization/app_localizations.dart';
import '../../models/branch_model.dart';
import '../../models/cart_item_model.dart';
import '../../models/cart_model.dart';
import '../../models/support_settings_model.dart';
import '../../models/user_model.dart';
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
  int? _selectedSavedAddressId;
  bool _useNewAddress = false;
  String _selectedPaymentMethod = 'cod';
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
    final hasSession = await widget.apiService.hasAuthSession();
    final futures = await Future.wait<dynamic>([
      widget.apiService.fetchCart(),
      widget.apiService.fetchBranches(),
      widget.apiService.fetchSupportSettings(),
      hasSession
          ? widget.apiService.fetchProfile()
          : widget.apiService.getStoredUser(),
    ]);

    final cart = futures[0] as CartModel;
    final branches = (futures[1] as List<BranchModel>)
        .where((branch) => branch.id > 0 && branch.name.trim().isNotEmpty)
        .toList();
    final settings = futures[2] as SupportSettingsModel;
    final user = futures[3] as UserModel?;

    final availableMethods = _paymentMethodsFromSettings(settings);
    if (availableMethods.isNotEmpty &&
        !availableMethods.any((method) => method.code == _selectedPaymentMethod)) {
      _selectedPaymentMethod = availableMethods.first.code;
    }

    final preferredBranchId = user?.preferredBranch?.id;
    final cartBranchId = cart.items.firstOrNull?.branchId;
    _selectedBranchId = _resolveBranchSelection(
      branches: branches,
      branchId: _selectedBranchId ?? preferredBranchId ?? cartBranchId,
      mode: _mode,
    );

    final addresses = user?.addresses ?? const <SavedAddressModel>[];
    if (addresses.isNotEmpty && _selectedSavedAddressId == null) {
      _selectedSavedAddressId =
          addresses.firstWhere((address) => address.isDefault, orElse: () => addresses.first).id;
      _applySavedAddress(addresses.firstWhere(
        (address) => address.id == _selectedSavedAddressId,
        orElse: () => addresses.first,
      ));
    }

    return _CheckoutData(
      cart: cart,
      branches: branches,
      settings: settings,
      user: user,
      paymentMethods: availableMethods,
    );
  }

  int? _resolveBranchSelection({
    required List<BranchModel> branches,
    required int? branchId,
    required CheckoutMode mode,
  }) {
    final availableBranches = _branchesForMode(branches, mode);
    if (availableBranches.isEmpty) {
      return null;
    }
    if (branchId != null && availableBranches.any((branch) => branch.id == branchId)) {
      return branchId;
    }
    return availableBranches.first.id;
  }

  List<BranchModel> _branchesForMode(List<BranchModel> branches, CheckoutMode mode) {
    return branches.where((branch) {
      if (!branch.isActive) {
        return false;
      }
      return mode == CheckoutMode.delivery
          ? branch.deliveryAvailable
          : branch.pickupAvailable;
    }).toList();
  }

  List<_PaymentMethodOption> _paymentMethodsFromSettings(
    SupportSettingsModel settings,
  ) {
    final methods = <_PaymentMethodOption>[];
    if (settings.paymentCodEnabled) {
      methods.add(_PaymentMethodOption(
        code: 'cod',
        label: (settings.paymentCodLabel ?? '').trim().isNotEmpty
            ? settings.paymentCodLabel!
            : 'Cash on Delivery',
        description: 'Pay when your order is delivered or handed over.',
      ));
    }
    if (settings.paymentCardEnabled) {
      methods.add(_PaymentMethodOption(
        code: 'card',
        label: (settings.paymentCardLabel ?? '').trim().isNotEmpty
            ? settings.paymentCardLabel!
            : 'Card Payment',
        description: 'Use the card payment option enabled by the admin team.',
      ));
    }
    if (settings.paymentBankTransferEnabled) {
      methods.add(_PaymentMethodOption(
        code: 'bank_transfer',
        label: (settings.paymentBankTransferLabel ?? '').trim().isNotEmpty
            ? settings.paymentBankTransferLabel!
            : 'Bank Transfer',
        description: 'Transfer payment using the branch instructions after placing the order.',
      ));
    }
    return methods;
  }

  Future<void> _retry() async {
    setState(() {
      _checkoutFuture = _loadCheckoutData();
    });
    try {
      await _checkoutFuture;
    } catch (_) {
      // FutureBuilder handles the visible error state.
    }
  }

  void _applySavedAddress(SavedAddressModel address) {
    _labelController.text = address.label;
    _cityController.text = address.city;
    _neighborhoodController.text = address.neighborhood;
    _addressLineController.text = address.addressLine;
  }

  Future<void> _placeOrder(_CheckoutData data) async {
    if (_isPlacingOrder) {
      return;
    }
    if (_selectedBranchId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.t('checkout_select_branch_error'))),
      );
      return;
    }
    if (data.paymentMethods.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No payment methods are enabled right now.')),
      );
      return;
    }
    if (_mode == CheckoutMode.delivery &&
        (_useNewAddress || _selectedSavedAddressId == null) &&
        !_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isPlacingOrder = true);
    try {
      final order = await widget.apiService.placeOrder(
        orderType: _mode == CheckoutMode.delivery ? 'delivery' : 'pickup',
        branchId: _selectedBranchId!,
        paymentMethod: _selectedPaymentMethod,
        notes: _notesController.text,
        addressId: _mode == CheckoutMode.delivery && !_useNewAddress
            ? _selectedSavedAddressId
            : null,
        address: _mode == CheckoutMode.delivery &&
                (_useNewAddress || _selectedSavedAddressId == null)
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
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
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

          final data = snapshot.data;
          if (data == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: _ErrorCard(onRetry: _retry),
              ),
            );
          }
          if (data.cart.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: _EmptyCheckoutCard(),
              ),
            );
          }

          final availableBranches = _branchesForMode(data.branches, _mode);
          _selectedBranchId = _resolveBranchSelection(
            branches: data.branches,
            branchId: _selectedBranchId,
            mode: _mode,
          );

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
                    branches: availableBranches,
                    user: data.user,
                    useNewAddress: _useNewAddress,
                    selectedSavedAddressId: _selectedSavedAddressId,
                    paymentMethods: data.paymentMethods,
                    selectedPaymentMethod: _selectedPaymentMethod,
                    settings: data.settings,
                    labelController: _labelController,
                    cityController: _cityController,
                    neighborhoodController: _neighborhoodController,
                    addressLineController: _addressLineController,
                    notesController: _notesController,
                    onModeChanged: (mode) {
                      setState(() {
                        _mode = mode;
                        _selectedBranchId = _resolveBranchSelection(
                          branches: data.branches,
                          branchId: _selectedBranchId,
                          mode: mode,
                        );
                      });
                    },
                    onBranchChanged: (value) =>
                        setState(() => _selectedBranchId = value),
                    onUseNewAddressChanged: (value) =>
                        setState(() => _useNewAddress = value),
                    onSavedAddressChanged: (addressId) {
                      setState(() {
                        _selectedSavedAddressId = addressId;
                        final address = data.user?.addresses
                            .where((item) => item.id == addressId)
                            .cast<SavedAddressModel?>()
                            .firstOrNull;
                        if (address != null) {
                          _applySavedAddress(address);
                        }
                      });
                    },
                    onPaymentMethodChanged: (code) {
                      setState(() => _selectedPaymentMethod = code);
                    },
                  );
                  final summary = _OrderSummaryCard(
                    cart: data.cart,
                    mode: _mode,
                    selectedBranch: availableBranches
                        .where((branch) => branch.id == _selectedBranchId)
                        .cast<BranchModel?>()
                        .firstOrNull,
                    selectedPaymentMethod: data.paymentMethods
                        .where((method) => method.code == _selectedPaymentMethod)
                        .cast<_PaymentMethodOption?>()
                        .firstOrNull,
                    onPlaceOrder: () => _placeOrder(data),
                    isPlacingOrder: _isPlacingOrder,
                  );

                  if (wide) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 3,
                          child: SingleChildScrollView(child: form),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          flex: 2,
                          child: SingleChildScrollView(child: summary),
                        ),
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
  final SupportSettingsModel settings;
  final UserModel? user;
  final List<_PaymentMethodOption> paymentMethods;

  const _CheckoutData({
    required this.cart,
    required this.branches,
    required this.settings,
    required this.user,
    required this.paymentMethods,
  });
}

class _PaymentMethodOption {
  final String code;
  final String label;
  final String description;

  const _PaymentMethodOption({
    required this.code,
    required this.label,
    required this.description,
  });
}

class _CheckoutForm extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final CheckoutMode mode;
  final int? selectedBranchId;
  final List<BranchModel> branches;
  final UserModel? user;
  final bool useNewAddress;
  final int? selectedSavedAddressId;
  final List<_PaymentMethodOption> paymentMethods;
  final String selectedPaymentMethod;
  final SupportSettingsModel settings;
  final TextEditingController labelController;
  final TextEditingController cityController;
  final TextEditingController neighborhoodController;
  final TextEditingController addressLineController;
  final TextEditingController notesController;
  final ValueChanged<CheckoutMode> onModeChanged;
  final ValueChanged<int?> onBranchChanged;
  final ValueChanged<bool> onUseNewAddressChanged;
  final ValueChanged<int?> onSavedAddressChanged;
  final ValueChanged<String> onPaymentMethodChanged;

  const _CheckoutForm({
    required this.formKey,
    required this.mode,
    required this.selectedBranchId,
    required this.branches,
    required this.user,
    required this.useNewAddress,
    required this.selectedSavedAddressId,
    required this.paymentMethods,
    required this.selectedPaymentMethod,
    required this.settings,
    required this.labelController,
    required this.cityController,
    required this.neighborhoodController,
    required this.addressLineController,
    required this.notesController,
    required this.onModeChanged,
    required this.onBranchChanged,
    required this.onUseNewAddressChanged,
    required this.onSavedAddressChanged,
    required this.onPaymentMethodChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final savedAddresses = user?.addresses ?? const <SavedAddressModel>[];

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
              child: Column(
                children: [
                  DropdownButtonFormField<int>(
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
                  const SizedBox(height: 14),
                  if (selectedBranchId != null)
                    _BranchModeCard(
                      branch: branches.firstWhere(
                        (branch) => branch.id == selectedBranchId,
                        orElse: () => branches.first,
                      ),
                      mode: mode,
                    ),
                ],
              ),
            ),
            if (mode == CheckoutMode.delivery) ...[
              const SizedBox(height: 16),
              _SectionCard(
                title: l10n.t('checkout_delivery_information'),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (savedAddresses.isNotEmpty) ...[
                      SwitchListTile.adaptive(
                        value: useNewAddress,
                        onChanged: onUseNewAddressChanged,
                        title: const Text('Use a new address'),
                        subtitle: Text(
                          useNewAddress
                              ? 'Enter a new delivery address for this order.'
                              : 'Use one of your saved delivery addresses.',
                        ),
                        contentPadding: EdgeInsets.zero,
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (savedAddresses.isNotEmpty && !useNewAddress) ...[
                      DropdownButtonFormField<int>(
                        initialValue: selectedSavedAddressId,
                        items: savedAddresses
                            .map(
                              (address) => DropdownMenuItem<int>(
                                value: address.id,
                                child: Text(
                                  '${address.label} · ${address.city}',
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: onSavedAddressChanged,
                        decoration: _fieldDecoration('Saved address'),
                      ),
                      const SizedBox(height: 14),
                      if (selectedSavedAddressId != null)
                        _SavedAddressPreview(
                          address: savedAddresses.firstWhere(
                            (address) => address.id == selectedSavedAddressId,
                            orElse: () => savedAddresses.first,
                          ),
                        ),
                    ] else ...[
                      TextFormField(
                        controller: labelController,
                        validator:
                            _requiredValidator(context, l10n.t('checkout_address_label')),
                        decoration:
                            _fieldDecoration(l10n.t('checkout_address_label')),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: cityController,
                        validator:
                            _requiredValidator(context, l10n.t('checkout_city')),
                        decoration: _fieldDecoration(l10n.t('checkout_city')),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: neighborhoodController,
                        validator: _requiredValidator(
                          context,
                          l10n.t('checkout_neighborhood'),
                        ),
                        decoration:
                            _fieldDecoration(l10n.t('checkout_neighborhood')),
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
                        decoration:
                            _fieldDecoration(l10n.t('checkout_address_line')),
                      ),
                    ],
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            _SectionCard(
              title: 'Payment Method',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (paymentMethods.isEmpty)
                    const Text(
                      'No payment methods are enabled in admin settings.',
                    )
                  else
                    for (final method in paymentMethods) ...[
                      _PaymentMethodTile(
                        option: method,
                        selected: selectedPaymentMethod == method.code,
                        onTap: () => onPaymentMethodChanged(method.code),
                      ),
                      const SizedBox(height: 12),
                    ],
                  if ((settings.paymentCheckoutNotice ?? '').trim().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      settings.paymentCheckoutNotice!,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.textMuted,
                            height: 1.5,
                          ),
                    ),
                  ],
                ],
              ),
            ),
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
      child: Column(
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
                ? 'Complete delivery details, choose a branch with delivery coverage, and confirm your payment preference.'
                : 'Choose a pickup-ready branch, confirm your payment method, and place the order without leaving the customer flow.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.creamSoft,
                ),
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

class _PaymentMethodTile extends StatelessWidget {
  final _PaymentMethodOption option;
  final bool selected;
  final VoidCallback onTap;

  const _PaymentMethodTile({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Ink(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? AppColors.creamSoft : AppColors.cream,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? AppColors.goldMuted : AppColors.border,
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              _paymentIcon(option.code),
              color: AppColors.brownDeep,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    option.label,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(option.description),
                ],
              ),
            ),
            Icon(
              selected ? Icons.check_circle_rounded : Icons.circle_outlined,
              color: selected ? AppColors.goldMuted : AppColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }

  IconData _paymentIcon(String code) {
    switch (code) {
      case 'card':
        return Icons.credit_card_rounded;
      case 'bank_transfer':
        return Icons.account_balance_outlined;
      case 'cod':
      default:
        return Icons.payments_outlined;
    }
  }
}

class _BranchModeCard extends StatelessWidget {
  final BranchModel branch;
  final CheckoutMode mode;

  const _BranchModeCard({
    required this.branch,
    required this.mode,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            branch.name,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            mode == CheckoutMode.delivery
                ? (branch.deliveryCoverage?.trim().isNotEmpty == true
                    ? 'Delivery coverage: ${branch.deliveryCoverage}'
                    : 'Delivery is available from this branch.')
                : 'Pickup is available from this branch during branch operating hours.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  height: 1.5,
                ),
          ),
        ],
      ),
    );
  }
}

class _SavedAddressPreview extends StatelessWidget {
  final SavedAddressModel address;

  const _SavedAddressPreview({
    required this.address,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            address.label,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            '${address.city}, ${address.neighborhood}\n${address.addressLine}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.5),
          ),
        ],
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
  final BranchModel? selectedBranch;
  final _PaymentMethodOption? selectedPaymentMethod;
  final VoidCallback onPlaceOrder;
  final bool isPlacingOrder;

  const _OrderSummaryCard({
    required this.cart,
    required this.mode,
    required this.selectedBranch,
    required this.selectedPaymentMethod,
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
          const SizedBox(height: 12),
          if (selectedBranch != null)
            _SummaryInfoRow(
              label: 'Branch',
              value: selectedBranch!.name,
            ),
          if (selectedPaymentMethod != null)
            _SummaryInfoRow(
              label: 'Payment',
              value: selectedPaymentMethod!.label,
            ),
          _SummaryInfoRow(
            label: 'Mode',
            value: mode == CheckoutMode.delivery ? 'Delivery' : 'Pickup',
          ),
          const SizedBox(height: 14),
          for (final item in cart.items) ...[
            _SummaryLine(item: item),
            const SizedBox(height: 12),
          ],
          const Divider(color: AppColors.border),
          const SizedBox(height: 12),
          _PriceRow(
            label: context.l10n.t('checkout_subtotal'),
            value: cart.subtotal,
          ),
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

class _SummaryInfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryInfoRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textMuted,
                ),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w700,
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
                context.l10n
                    .t('checkout_qty', {'quantity': '${item.quantity}'}),
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
  const _EmptyCheckoutCard();

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

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
