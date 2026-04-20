import 'package:flutter/material.dart';
import 'package:mes_client/core/ui/primitives/mes_surface.dart';

class MesToolbar extends StatelessWidget {
  const MesToolbar({
    super.key,
    required this.leading,
    this.trailing = const <Widget>[],
  });

  final Widget leading;
  final List<Widget> trailing;

  @override
  Widget build(BuildContext context) {
    return MesSurface(
      tone: MesSurfaceTone.subtle,
      child: Row(
        children: [
          Expanded(child: leading),
          Wrap(spacing: 12, runSpacing: 12, children: trailing),
        ],
      ),
    );
  }
}
