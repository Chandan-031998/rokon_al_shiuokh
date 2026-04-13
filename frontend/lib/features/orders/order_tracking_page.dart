import 'package:flutter/material.dart';

import '../../core/widgets/placeholder_page.dart';

class OrderTrackingPage extends StatelessWidget {
  const OrderTrackingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderPage(
      title: 'Order Tracking',
      description:
          'Live order tracking is still pending once order state updates are available from the backend.',
    );
  }
}
