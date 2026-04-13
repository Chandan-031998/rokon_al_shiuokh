import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/extensions/localized_content.dart';
import '../../core/widgets/premium_network_image.dart';
import '../../localization/app_locale_controller.dart';
import '../../localization/app_localizations.dart';
import '../../models/cart_item_model.dart';
import '../../models/cart_model.dart';
import '../../services/api_service.dart';
import '../checkout/checkout_page.dart';
import '../navigation/app_shell.dart';

class CartPage extends StatefulWidget {
  final ApiService apiService;
  final AppLocaleController localeController;
  final bool isActive;
  final VoidCallback onBrowseProducts;
  final VoidCallback onOpenOrders;
  final bool showAppBar;

  const CartPage({
    super.key,
    required this.apiService,
    required this.localeController,
    required this.isActive,
    required this.onBrowseProducts,
    required this.onOpenOrders,
    this.showAppBar = true,
  });

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  late Future<CartModel> _cartFuture;
  bool _isBusy = false;

  @override
  void initState() {
    super.initState();
    _cartFuture = widget.apiService.fetchCart();
  }

  @override
  void didUpdateWidget(covariant CartPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isActive && widget.isActive) {
      _reloadCart();
    }
  }

  Future<void> _reloadCart() async {
    setState(() {
      _cartFuture = widget.apiService.fetchCart();
    });
    await _cartFuture;
  }

  Future<void> _updateQuantity(CartItemModel item, int quantity) async {
    if (_isBusy) {
      return;
    }

    setState(() => _isBusy = true);
    try {
      final cart = await widget.apiService.updateCartItem(
        itemId: item.id,
        quantity: quantity,
        branchId: item.branchId,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _cartFuture = Future<CartModel>.value(cart);
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.t('cart_update_error'))),
      );
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }

  Future<void> _removeItem(CartItemModel item) async {
    if (_isBusy) {
      return;
    }

    setState(() => _isBusy = true);
    try {
      final cart = await widget.apiService.removeCartItem(item.id);
      if (!mounted) {
        return;
      }
      setState(() {
        _cartFuture = Future<CartModel>.value(cart);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.t(
              'cart_remove_success',
              {'name': item.product.localizedName(context.l10n)},
            ),
          ),
        ),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.t('cart_remove_error'))),
      );
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }

  Future<void> _openCheckout() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CheckoutPage(apiService: widget.apiService),
      ),
    );
    if (!mounted) {
      return;
    }
    await _reloadCart();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return TabScreenTemplate(
      eyebrow: l10n.t('cart_eyebrow'),
      title: l10n.t('cart_title'),
      subtitle: l10n.t('cart_subtitle'),
      icon: Icons.shopping_cart_checkout_rounded,
      showAppBar: widget.showAppBar,
      localeController: widget.localeController,
      body: FutureBuilder<CartModel>(
        future: _cartFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            );
          }

          if (snapshot.hasError) {
            return ActionPanel(
              title: l10n.t('cart_load_error_title'),
              description: l10n.t('cart_load_error_desc'),
              actionLabel: l10n.t('common_retry'),
              onPressed: _reloadCart,
              icon: Icons.refresh_rounded,
            );
          }

          final cart = snapshot.data ??
              const CartModel(
                items: <CartItemModel>[],
                subtotal: 0,
                total: 0,
                currency: 'SAR',
              );

          if (cart.isEmpty) {
            return Column(
              children: [
                ActionPanel(
                  title: l10n.t('cart_empty_title'),
                  description: l10n.t('cart_empty_desc'),
                  actionLabel: l10n.t('common_browse_products'),
                  onPressed: widget.onBrowseProducts,
                  icon: Icons.shopping_bag_outlined,
                ),
                ActionPanel(
                  title: l10n.t('cart_track_orders_title'),
                  description: l10n.t('cart_track_orders_desc'),
                  actionLabel: l10n.t('common_view_orders'),
                  onPressed: widget.onOpenOrders,
                  icon: Icons.receipt_long_outlined,
                ),
              ],
            );
          }

          return Column(
            children: [
              for (final item in cart.items)
                _CartItemCard(
                  item: item,
                  isBusy: _isBusy,
                  onIncrease: () => _updateQuantity(item, item.quantity + 1),
                  onDecrease: item.quantity > 1
                      ? () => _updateQuantity(item, item.quantity - 1)
                      : null,
                  onRemove: () => _removeItem(item),
                ),
              _SummaryCard(
                cart: cart,
                onCheckout: _openCheckout,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CartItemCard extends StatelessWidget {
  final CartItemModel item;
  final bool isBusy;
  final VoidCallback onIncrease;
  final VoidCallback? onDecrease;
  final VoidCallback onRemove;

  const _CartItemCard({
    required this.item,
    required this.isBusy,
    required this.onIncrease,
    required this.onDecrease,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.white, Color(0xFFFFFBF7)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x102D1A12),
            blurRadius: 14,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CartItemVisual(imageUrl: item.product.imageUrl),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.product.localizedName(context.l10n),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.creamSoft,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    _cartSubtitleWithContext(context, item),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.brown,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    _QtyButton(
                      icon: Icons.remove_rounded,
                      onPressed: isBusy ? null : onDecrease,
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        '${item.quantity}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    _QtyButton(
                      icon: Icons.add_rounded,
                      onPressed: isBusy ? null : onIncrease,
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: isBusy ? null : onRemove,
                      child: Text(context.l10n.t('common_remove')),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.brownDeep,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              'SAR ${item.lineTotal.toStringAsFixed(0)}',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: AppColors.white,
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CartItemVisual extends StatelessWidget {
  final String? imageUrl;

  const _CartItemVisual({this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return PremiumNetworkImage(
      imageUrl: imageUrl,
      width: 84,
      height: 92,
      borderRadius: BorderRadius.circular(18),
      fallbackIcon: Icons.shopping_bag_outlined,
      fallbackIconSize: 26,
    );
  }
}

class _QtyButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;

  const _QtyButton({
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: onPressed,
      radius: 20,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: AppColors.creamSoft,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: AppColors.brown, size: 18),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final CartModel cart;
  final VoidCallback onCheckout;

  const _SummaryCard({
    required this.cart,
    required this.onCheckout,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.white, Color(0xFFFFFBF7)],
        ),
        borderRadius: BorderRadius.circular(28),
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
          _SummaryRow(
            label: context.l10n.t('cart_items'),
            value: '${cart.totalQuantity}',
          ),
          const SizedBox(height: 10),
          _SummaryRow(
            label: context.l10n.t('cart_subtotal'),
            value: '${cart.currency} ${cart.subtotal.toStringAsFixed(0)}',
          ),
          const SizedBox(height: 10),
          _SummaryRow(
            label: context.l10n.t('cart_total'),
            value: '${cart.currency} ${cart.total.toStringAsFixed(0)}',
            emphasize: true,
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onCheckout,
              child: Text(context.l10n.t('cart_continue_checkout')),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool emphasize;

  const _SummaryRow({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  @override
  Widget build(BuildContext context) {
    final textStyle = emphasize
        ? Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: AppColors.brownDeep,
            )
        : Theme.of(context).textTheme.bodyLarge;

    return Row(
      children: [
        Text(label, style: textStyle),
        const Spacer(),
        Text(value, style: textStyle),
      ],
    );
  }
}

String _cartSubtitleWithContext(BuildContext context, CartItemModel item) {
  final branchName =
      item.branch?.name ?? context.l10n.t('orders_selected_branch');
  return '${_packSizeLabel(context, item.product.name, item.product.description, item.product.sku)} · $branchName';
}

String _packSizeLabel(
  BuildContext context,
  String name,
  String? description,
  String? sku,
) {
  final source = '$name ${description ?? ''} ${sku ?? ''}';
  final match = RegExp(r'(\d+\s?(?:g|kg|ml|l|pack))', caseSensitive: false)
      .firstMatch(source);
  return match?.group(1) ?? context.l10n.t('product_standard_pack');
}
