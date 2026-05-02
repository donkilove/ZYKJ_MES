import 'package:flutter/material.dart';

class QualityWorkbenchSummaryGrid extends StatelessWidget {
  const QualityWorkbenchSummaryGrid({
    super.key,
    required this.children,
  });

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: children,
    );
  }
}
