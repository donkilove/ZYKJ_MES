import 'package:flutter/material.dart';
import 'package:mes_client/core/ui/patterns/mes_page_header.dart';

class FunctionPermissionConfigPageHeader extends StatelessWidget {
  const FunctionPermissionConfigPageHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return const KeyedSubtree(
      key: ValueKey('function-permission-config-page-header'),
      child: MesPageHeader(
        title: '功能权限配置',
        subtitle: '统一配置模块权限能力包。',
      ),
    );
  }
}
