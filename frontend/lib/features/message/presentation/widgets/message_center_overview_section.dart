import 'package:flutter/material.dart';
import 'package:mes_client/core/ui/patterns/mes_metric_card.dart';
import 'package:mes_client/core/ui/patterns/mes_section_card.dart';

class MessageCenterOverviewSection extends StatelessWidget {
  const MessageCenterOverviewSection({
    super.key,
    required this.unreadCount,
    required this.todoCount,
    required this.urgentCount,
    required this.allCount,
  });

  final int unreadCount;
  final int todoCount;
  final int urgentCount;
  final int allCount;

  @override
  Widget build(BuildContext context) {
    return MesSectionCard(
      title: '消息概览',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 1200
              ? 4
              : constraints.maxWidth >= 760
              ? 2
              : 1;
          final spacing = 8.0;
          final rawWidth =
              (constraints.maxWidth - spacing * (columns - 1)) / columns;
          final itemWidth = rawWidth.clamp(180.0, 220.0).toDouble();
          return Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: [
                SizedBox(
                  width: itemWidth,
                  child: MesMetricCard(label: '未读消息', value: '$unreadCount'),
                ),
                SizedBox(
                  width: itemWidth,
                  child: MesMetricCard(label: '待处理', value: '$todoCount'),
                ),
                SizedBox(
                  width: itemWidth,
                  child: MesMetricCard(label: '高优先级', value: '$urgentCount'),
                ),
                SizedBox(
                  width: itemWidth,
                  child: MesMetricCard(label: '全部消息', value: '$allCount'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
