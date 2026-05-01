import 'package:flutter/material.dart';

import 'package:mes_client/core/models/current_user.dart';
import 'package:mes_client/core/ui/foundation/mes_tokens.dart';
import 'package:mes_client/features/shell/models/home_dashboard_models.dart';
import 'package:mes_client/features/shell/presentation/widgets/home_dashboard_header.dart';
import 'package:mes_client/features/shell/presentation/widgets/home_dashboard_kpi_card.dart';
import 'package:mes_client/features/shell/presentation/widgets/home_dashboard_risk_card.dart';
import 'package:mes_client/features/shell/presentation/widgets/home_dashboard_todo_card.dart';

class HomeQuickJumpEntry {
  const HomeQuickJumpEntry({
    required this.pageCode,
    required this.title,
    required this.icon,
    this.tabCode,
    this.routePayloadJson,
  });

  final String pageCode;
  final String title;
  final IconData icon;
  final String? tabCode;
  final String? routePayloadJson;
}

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.currentUser,
    required this.shortcuts,
    required this.onNavigateToPage,
    required this.onRefresh,
    required this.refreshing,
    this.refreshStatusText,
    this.dashboardData,
  });

  final CurrentUser currentUser;
  final List<HomeQuickJumpEntry> shortcuts;
  final void Function(
    String pageCode, {
    String? tabCode,
    String? routePayloadJson,
  })
  onNavigateToPage;
  final Future<void> Function() onRefresh;
  final bool refreshing;
  final String? refreshStatusText;
  final HomeDashboardData? dashboardData;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const _desktopHeaderKey = Key('home_desktop_header');
  static const _desktopMainRowKey = Key('home_desktop_main_row');
  static const _desktopTodoPaneKey = Key('home_desktop_todo_pane');
  static const _desktopRightPaneKey = Key('home_desktop_right_pane');
  static const _desktopRiskPaneKey = Key('home_desktop_risk_pane');
  static const _desktopKpiPaneKey = Key('home_desktop_kpi_pane');

  bool _isDesktopLayout(BoxConstraints constraints) {
    return constraints.maxWidth >= 1200;
  }

  HomeDashboardData _buildFallbackData() {
    final todoItems = widget.shortcuts
        .take(4)
        .map(
          (entry) => HomeDashboardTodoItem(
            id: entry.pageCode.hashCode,
            title: entry.title,
            categoryLabel: '快捷入口',
            priorityLabel: '常规',
            targetPageCode: entry.pageCode,
            targetTabCode: entry.tabCode,
            targetRoutePayloadJson: entry.routePayloadJson,
          ),
        )
        .toList();
    return HomeDashboardData(
      generatedAt: null,
      noticeCount: 0,
      todoSummary: HomeDashboardTodoSummary(
        totalCount: widget.shortcuts.length,
        pendingApprovalCount: 0,
        highPriorityCount: 0,
        exceptionCount: 0,
        overdueCount: 0,
      ),
      todoItems: todoItems,
      riskItems: const [
        HomeDashboardMetricItem(
          code: 'production_exception',
          label: '生产异常',
          value: '--',
        ),
        HomeDashboardMetricItem(
          code: 'quality_warning',
          label: '质量预警',
          value: '--',
        ),
        HomeDashboardMetricItem(
          code: 'maintenance_overdue',
          label: '设备逾期保养',
          value: '--',
        ),
        HomeDashboardMetricItem(
          code: 'high_priority_message',
          label: '待确认高优消息',
          value: '--',
        ),
      ],
      kpiItems: const [
        HomeDashboardMetricItem(code: 'wip_orders', label: '在制订单', value: '--'),
        HomeDashboardMetricItem(
          code: 'today_output',
          label: '今日产量',
          value: '--',
        ),
        HomeDashboardMetricItem(
          code: 'first_pass_rate',
          label: '首件通过率',
          value: '--',
        ),
        HomeDashboardMetricItem(code: 'scrap_count', label: '报废数', value: '--'),
      ],
      degradedBlocks: const [],
    );
  }

  Widget _buildDesktopLayout(HomeDashboardData data) {
    return Column(
      children: [
        HomeDashboardHeader(
          key: _desktopHeaderKey,
          currentUser: widget.currentUser,
          noticeCount: data.noticeCount,
          refreshing: widget.refreshing,
          onRefresh: widget.onRefresh,
          refreshStatusText: widget.refreshStatusText,
        ),
        const SizedBox(height: 12),
        Expanded(
          child: Row(
            key: _desktopMainRowKey,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                key: _desktopTodoPaneKey,
                flex: 17,
                child: HomeDashboardTodoCard(
                  todoSummary: data.todoSummary,
                  todoItems: data.todoItems,
                  onNavigateToPage: widget.onNavigateToPage,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                key: _desktopRightPaneKey,
                flex: 10,
                child: Column(
                  children: [
                    Expanded(
                      key: _desktopRiskPaneKey,
                      child: HomeDashboardRiskCard(
                        riskItems: data.riskItems,
                        onNavigateToPage: widget.onNavigateToPage,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      key: _desktopKpiPaneKey,
                      child: HomeDashboardKpiCard(
                        kpiItems: data.kpiItems,
                        onNavigateToPage: widget.onNavigateToPage,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout(HomeDashboardData data) {
    return SingleChildScrollView(
      child: Column(
        children: [
          HomeDashboardHeader(
            currentUser: widget.currentUser,
            noticeCount: data.noticeCount,
            refreshing: widget.refreshing,
            onRefresh: widget.onRefresh,
            refreshStatusText: widget.refreshStatusText,
          ),
          const SizedBox(height: 12),
          HomeDashboardTodoCard(
            todoSummary: data.todoSummary,
            todoItems: data.todoItems,
            onNavigateToPage: widget.onNavigateToPage,
          ),
          const SizedBox(height: 12),
          HomeDashboardRiskCard(
            riskItems: data.riskItems,
            onNavigateToPage: widget.onNavigateToPage,
          ),
          const SizedBox(height: 12),
          HomeDashboardKpiCard(
            kpiItems: data.kpiItems,
            onNavigateToPage: widget.onNavigateToPage,
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.dashboardData ?? _buildFallbackData();
    final spacing =
        Theme.of(context).extension<MesTokens>()?.spacing.md ?? 16.0;
    return Padding(
      padding: EdgeInsets.all(spacing),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (_isDesktopLayout(constraints)) {
            return _buildDesktopLayout(data);
          }
          return _buildMobileLayout(data);
        },
      ),
    );
  }
}
