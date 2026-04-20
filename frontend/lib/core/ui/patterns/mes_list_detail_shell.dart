import 'package:flutter/material.dart';
import 'package:mes_client/core/ui/foundation/mes_tokens.dart';
import 'package:mes_client/core/ui/primitives/mes_gap.dart';

class MesListDetailShell extends StatelessWidget {
  const MesListDetailShell({
    super.key,
    required this.sidebar,
    required this.content,
    this.header,
    this.banner,
    this.sidebarWidth = 280,
    this.breakpoint = 960,
  });

  final Widget sidebar;
  final Widget content;
  final Widget? header;
  final Widget? banner;
  final double sidebarWidth;
  final double breakpoint;

  @override
  Widget build(BuildContext context) {
    final spacing =
        Theme.of(context).extension<MesTokens>()?.spacing.md ?? 16.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked = constraints.maxWidth < breakpoint;
        final stackedSidebarHeight =
            (constraints.maxHeight * 0.35).clamp(240.0, 360.0).toDouble();

        final body = stacked
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: stackedSidebarHeight,
                    child: KeyedSubtree(
                      key: const ValueKey('mes-list-detail-shell-sidebar'),
                      child: sidebar,
                    ),
                  ),
                  MesGap.vertical(spacing),
                  Expanded(
                    child: KeyedSubtree(
                      key: const ValueKey('mes-list-detail-shell-content'),
                      child: content,
                    ),
                  ),
                ],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: sidebarWidth,
                    child: KeyedSubtree(
                      key: const ValueKey('mes-list-detail-shell-sidebar'),
                      child: sidebar,
                    ),
                  ),
                  MesGap.horizontal(spacing),
                  Expanded(
                    child: KeyedSubtree(
                      key: const ValueKey('mes-list-detail-shell-content'),
                      child: content,
                    ),
                  ),
                ],
              );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (header != null) ...[
              header!,
              MesGap.vertical(spacing),
            ],
            if (banner != null) ...[
              banner!,
              MesGap.vertical(spacing),
            ],
            Expanded(child: body),
          ],
        );
      },
    );
  }
}
