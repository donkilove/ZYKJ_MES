import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/features/shell/models/home_dashboard_models.dart';

void main() {
  test('首页工作台服务能解析待办、风险和 KPI', () {
    final result = HomeDashboardData.fromJson({
      'generated_at': '2026-04-12T12:00:00Z',
      'notice_count': 2,
      'todo_summary': {
        'total_count': 12,
        'pending_approval_count': 2,
        'high_priority_count': 2,
        'exception_count': 6,
        'overdue_count': 1,
      },
      'todo_items': [
        {
          'id': 1,
          'title': '待办 A',
          'category_label': '审批',
          'priority_label': '高优',
          'source_module': 'user',
          'target_page_code': 'user',
          'target_tab_code': 'registration_approval',
          'target_route_payload_json': '{"request_id":1}',
        },
      ],
      'risk_items': [],
      'kpi_items': [],
      'degraded_blocks': [],
    });

    expect(result.noticeCount, 2);
    expect(result.todoItems.single.title, '待办 A');
    expect(result.todoSummary.exceptionCount, 6);
  });
}
