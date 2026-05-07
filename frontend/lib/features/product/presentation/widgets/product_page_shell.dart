import 'package:flutter/material.dart';

class ProductPageShell extends StatelessWidget {
  const ProductPageShell({
    super.key,
    required this.header,
    required this.tabBar,
    required this.tabBarView,
  });

  final Widget header;
  final Widget tabBar;
  final Widget tabBarView;

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: const ValueKey('product-page-shell'),
      child: Column(
        children: [
          KeyedSubtree(
            key: const ValueKey('product-page-header-slot'),
            child: header,
          ),
          KeyedSubtree(
            key: const ValueKey('product-page-tab-bar'),
            child: tabBar,
          ),
          Expanded(child: tabBarView),
        ],
      ),
    );
  }
}
