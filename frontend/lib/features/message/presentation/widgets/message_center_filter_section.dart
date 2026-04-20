import 'package:flutter/material.dart';
import 'package:mes_client/core/ui/patterns/mes_filter_bar.dart';

class MessageCenterFilterSection extends StatelessWidget {
  const MessageCenterFilterSection({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MesFilterBar(child: child);
  }
}
