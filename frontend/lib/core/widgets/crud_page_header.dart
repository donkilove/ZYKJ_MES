import 'package:flutter/material.dart';
import 'package:mes_client/core/ui/patterns/mes_page_header.dart';

class CrudPageHeader extends StatelessWidget {
  const CrudPageHeader({super.key, required this.title, this.onRefresh});

  final String title;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    return MesPageHeader(
      title: title,
      actions: [
        Tooltip(
          message: '刷新',
          child: SizedBox(
            width: 40,
            height: 40,
            child: IconButton(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh),
            ),
          ),
        ),
      ],
    );
  }
}
