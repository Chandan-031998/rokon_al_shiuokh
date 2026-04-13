import 'package:flutter/material.dart';

import '../../core/widgets/placeholder_page.dart';

class SearchPage extends StatelessWidget {
  const SearchPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderPage(
      title: 'Search',
      description:
          'Product search suggestions and keyword results are still incomplete.',
    );
  }
}
