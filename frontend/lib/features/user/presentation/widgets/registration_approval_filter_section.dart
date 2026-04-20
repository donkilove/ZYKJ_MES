import 'package:flutter/material.dart';
import 'package:mes_client/features/user/presentation/widgets/shared/user_module_filter_panel.dart';

class RegistrationApprovalFilterSection extends StatelessWidget {
  const RegistrationApprovalFilterSection({
    super.key,
    required this.statusFilter,
    required this.onChanged,
  });

  final String? statusFilter;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return UserModuleFilterPanel(
      sectionKey: const ValueKey('registration-approval-filter-section'),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        children: [
          SizedBox(
            width: 150,
            child: DropdownButtonFormField<String?>(
              initialValue: statusFilter,
              decoration: const InputDecoration(
                labelText: '申请状态',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: const [
                DropdownMenuItem<String?>(value: null, child: Text('全部')),
                DropdownMenuItem<String?>(value: 'pending', child: Text('待审批')),
                DropdownMenuItem<String?>(
                  value: 'approved',
                  child: Text('已通过'),
                ),
                DropdownMenuItem<String?>(
                  value: 'rejected',
                  child: Text('已驳回'),
                ),
              ],
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}
