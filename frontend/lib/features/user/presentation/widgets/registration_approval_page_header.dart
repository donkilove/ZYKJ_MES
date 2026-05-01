import 'package:flutter/material.dart';
import 'package:mes_client/core/ui/patterns/mes_refresh_page_header.dart';

class RegistrationApprovalPageHeader extends StatelessWidget {
  const RegistrationApprovalPageHeader({
    super.key,
    required this.loading,
    required this.statusFilter,
    required this.onStatusChanged,
    required this.onRefresh,
  });

  final bool loading;
  final String? statusFilter;
  final ValueChanged<String?> onStatusChanged;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return MesRefreshPageHeader(
      title: '注册审批',
      onRefresh: loading ? null : onRefresh,
      actionsBeforeRefresh: [
        SizedBox(
          key: const ValueKey('registration-approval-status-filter'),
          width: 160,
          child: DropdownButtonFormField<String?>(
            key: ValueKey('registration-approval-status-field-$statusFilter'),
            initialValue: statusFilter,
            decoration: const InputDecoration(
              labelText: '申请状态',
              border: OutlineInputBorder(),
              isDense: true,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
            ),
            items: const [
              DropdownMenuItem<String?>(value: null, child: Text('全部')),
              DropdownMenuItem<String?>(value: 'pending', child: Text('待审批')),
              DropdownMenuItem<String?>(value: 'approved', child: Text('已通过')),
              DropdownMenuItem<String?>(value: 'rejected', child: Text('已驳回')),
            ],
            onChanged: loading ? null : onStatusChanged,
          ),
        ),
      ],
    );
  }
}
