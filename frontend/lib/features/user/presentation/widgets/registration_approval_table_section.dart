import 'package:flutter/material.dart';
import 'package:mes_client/core/widgets/crud_list_table_section.dart';
import 'package:mes_client/core/widgets/unified_list_table_header_style.dart';
import 'package:mes_client/features/user/models/user_models.dart';
import 'package:mes_client/features/user/presentation/widgets/shared/user_module_status_chip.dart';
import 'package:mes_client/features/user/presentation/widgets/shared/user_module_table_shell.dart';

class RegistrationApprovalTableSection extends StatelessWidget {
  const RegistrationApprovalTableSection({
    super.key,
    required this.items,
    required this.loading,
    required this.emptyText,
    required this.canApprove,
    required this.canReject,
    required this.onApprove,
    required this.onReject,
    required this.formatTime,
  });

  final List<RegistrationRequestItem> items;
  final bool loading;
  final String emptyText;
  final bool canApprove;
  final bool canReject;
  final void Function(RegistrationRequestItem item) onApprove;
  final void Function(RegistrationRequestItem item) onReject;
  final String Function(DateTime value) formatTime;

  @override
  Widget build(BuildContext context) {
    return UserModuleTableShell(
      sectionKey: const ValueKey('registration-approval-table-section'),
      title: '申请列表',
      child: CrudListTableSection(
        loading: loading,
        isEmpty: items.isEmpty,
        emptyText: emptyText,
        enableUnifiedHeaderStyle: true,
        child: DataTable(
          columnSpacing: 16,
          columns: [
            UnifiedListTableHeaderStyle.column(context, '用户名'),
            UnifiedListTableHeaderStyle.column(context, '申请时间'),
            UnifiedListTableHeaderStyle.column(context, '申请状态'),
            UnifiedListTableHeaderStyle.column(context, '驳回原因'),
            UnifiedListTableHeaderStyle.column(context, '操作'),
          ],
          rows: items.map((item) {
            return DataRow(
              cells: [
                DataCell(Text(item.account)),
                DataCell(Text(formatTime(item.createdAt))),
                DataCell(
                  UserModuleStatusChip(
                    tone: switch (item.status) {
                      'approved' => UserModuleStatusTone.approved,
                      'rejected' => UserModuleStatusTone.rejected,
                      _ => UserModuleStatusTone.pending,
                    },
                    label: switch (item.status) {
                      'approved' => '已通过',
                      'rejected' => '已驳回',
                      _ => '待审批',
                    },
                  ),
                ),
                DataCell(Text(item.rejectedReason ?? '-')),
                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (item.status == 'pending' && canApprove)
                        UnifiedListTableHeaderStyle.capsuleActionButton(
                          key: ValueKey(
                            'registration-approval-approve-button-${item.id}',
                          ),
                          label: '通过',
                          backgroundColor: Colors.green.shade600,
                          foregroundColor: Colors.white,
                          onPressed: () => onApprove(item),
                        ),
                      if (item.status == 'pending' && canApprove && canReject)
                        const SizedBox(width: 8),
                      if (item.status == 'pending' && canReject)
                        UnifiedListTableHeaderStyle.capsuleActionButton(
                          key: ValueKey(
                            'registration-approval-reject-button-${item.id}',
                          ),
                          label: '驳回',
                          backgroundColor: Colors.red.shade600,
                          foregroundColor: Colors.white,
                          onPressed: () => onReject(item),
                        ),
                      if (item.status != 'pending' ||
                          (!canApprove && !canReject))
                        const Text('-'),
                    ],
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}
