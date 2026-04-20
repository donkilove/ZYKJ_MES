import 'package:flutter/material.dart';
import 'package:mes_client/core/ui/foundation/mes_tokens.dart';
import 'package:mes_client/core/ui/primitives/mes_gap.dart';

class MesCrudPageScaffold extends StatelessWidget {
  const MesCrudPageScaffold({
    super.key,
    required this.header,
    required this.content,
    this.filters,
    this.banner,
    this.pagination,
    this.padding,
  });

  final Widget header;
  final Widget? filters;
  final Widget? banner;
  final Widget content;
  final Widget? pagination;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final spacing =
        Theme.of(context).extension<MesTokens>()?.spacing.md ?? 16.0;
    return Padding(
      padding: padding ?? EdgeInsets.all(spacing),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          header,
          if (filters != null) ...[MesGap.vertical(spacing), filters!],
          if (banner != null) ...[MesGap.vertical(spacing), banner!],
          MesGap.vertical(spacing),
          Expanded(child: content),
          if (pagination != null) ...[MesGap.vertical(spacing), pagination!],
        ],
      ),
    );
  }
}
