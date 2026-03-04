import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/app_session.dart';
import 'daily_first_article_page.dart';
import 'quality_data_page.dart';

const String firstArticleManagementTabCode = 'first_article_management';
const String qualityDataQueryTabCode = 'quality_data_query';

const List<String> _defaultTabOrder = [
  firstArticleManagementTabCode,
  qualityDataQueryTabCode,
];

class QualityPage extends StatefulWidget {
  const QualityPage({
    super.key,
    required this.session,
    required this.onLogout,
    required this.visibleTabCodes,
  });

  final AppSession session;
  final VoidCallback onLogout;
  final List<String> visibleTabCodes;

  @override
  State<QualityPage> createState() => _QualityPageState();
}

class _QualityPageState extends State<QualityPage>
    with SingleTickerProviderStateMixin {
  late List<String> _orderedVisibleTabCodes;
  TabController? _tabController;

  @override
  void initState() {
    super.initState();
    _orderedVisibleTabCodes = _sortedVisibleTabCodes(widget.visibleTabCodes);
    _rebuildTabController();
  }

  @override
  void didUpdateWidget(covariant QualityPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final updatedCodes = _sortedVisibleTabCodes(widget.visibleTabCodes);
    if (listEquals(updatedCodes, _orderedVisibleTabCodes)) {
      return;
    }
    final selectedCode = _currentSelectedTabCode();
    _orderedVisibleTabCodes = updatedCodes;
    _rebuildTabController(preferredCode: selectedCode);
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  List<String> _sortedVisibleTabCodes(List<String> tabCodes) {
    final visibleSet = tabCodes.toSet();
    final ordered = <String>[];
    for (final code in _defaultTabOrder) {
      if (visibleSet.remove(code)) {
        ordered.add(code);
      }
    }
    final remaining = visibleSet.toList()..sort();
    ordered.addAll(remaining);
    return ordered;
  }

  String? _currentSelectedTabCode() {
    if (_tabController == null || _orderedVisibleTabCodes.isEmpty) {
      return null;
    }
    final safeIndex = _tabController!.index.clamp(
      0,
      _orderedVisibleTabCodes.length - 1,
    );
    return _orderedVisibleTabCodes[safeIndex];
  }

  void _rebuildTabController({String? preferredCode}) {
    _tabController?.dispose();
    if (_orderedVisibleTabCodes.isEmpty) {
      _tabController = null;
      return;
    }
    var initialIndex = 0;
    if (preferredCode != null) {
      final preferredIndex = _orderedVisibleTabCodes.indexOf(preferredCode);
      if (preferredIndex >= 0) {
        initialIndex = preferredIndex;
      }
    }
    _tabController = TabController(
      length: _orderedVisibleTabCodes.length,
      vsync: this,
      initialIndex: initialIndex,
    );
  }

  String _tabTitle(String code) {
    switch (code) {
      case firstArticleManagementTabCode:
        return '每日首件';
      case qualityDataQueryTabCode:
        return '品质数据';
      default:
        return code;
    }
  }

  Widget _buildTabContent(String code) {
    switch (code) {
      case firstArticleManagementTabCode:
        return DailyFirstArticlePage(
          session: widget.session,
          onLogout: widget.onLogout,
        );
      case qualityDataQueryTabCode:
        return QualityDataPage(
          session: widget.session,
          onLogout: widget.onLogout,
        );
      default:
        return Center(child: Text('页面暂未实现：$code'));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_orderedVisibleTabCodes.isEmpty || _tabController == null) {
      return const Center(child: Text('当前账号无可见品质页面。'));
    }

    return Column(
      children: [
        Material(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: TabBar(
            controller: _tabController,
            tabs: _orderedVisibleTabCodes
                .map((code) => Tab(text: _tabTitle(code)))
                .toList(),
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: _orderedVisibleTabCodes.map(_buildTabContent).toList(),
          ),
        ),
      ],
    );
  }
}
