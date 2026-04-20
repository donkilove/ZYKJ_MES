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
          final itemWidth = (constraints.maxWidth - 36) / 4;
          return Wrap(
            spacing: 12,
            runSpacing: 12,
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
          );
        },
      ),
    );
  }
}
