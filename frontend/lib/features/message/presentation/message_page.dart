import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:mes_client/core/models/app_session.dart';
import 'package:mes_client/features/message/presentation/announcement_management_page.dart';
import 'package:mes_client/features/message/presentation/message_center_page.dart';
import 'package:mes_client/features/message/presentation/widgets/message_page_shell.dart';
import 'package:mes_client/features/message/services/message_service.dart';

const String messageCenterTabCode = 'message_center';
const String announcementManagementTabCode = 'announcement_management';

const List<String> _defaultTabOrder = [
  messageCenterTabCode,
  announcementManagementTabCode,
];

class MessagePage extends StatefulWidget {
  const MessagePage({
    super.key,
    required this.session,
    required this.onLogout,
    required this.visibleTabCodes,
    required this.capabilityCodes,
    this.moduleActive = true,
    this.preferredTabCode,
    this.routePayloadJson,
    this.service,
    this.refreshTick = 0,
    this.onUnreadCountChanged,
    this.onNavigateToPage,
    DateTime Function()? nowProvider,
  }) : nowProvider = nowProvider ?? DateTime.now;

  final AppSession session;
  final VoidCallback onLogout;
  final List<String> visibleTabCodes;
  final Set<String> capabilityCodes;
  final bool moduleActive;
  final String? preferredTabCode;
  final String? routePayloadJson;
  final MessageService? service;
  final int refreshTick;
  final void Function(int count)? onUnreadCountChanged;
  final void Function(
    String pageCode, {
    String? tabCode,
    String? routePayloadJson,
  })?
  onNavigateToPage;
  final DateTime Function() nowProvider;

  @override
  State<MessagePage> createState() => _MessagePageState();
}

class _MessagePageState extends State<MessagePage>
    with SingleTickerProviderStateMixin {
  late List<String> _orderedVisibleTabCodes;
  TabController? _tabController;
  int _currentTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _orderedVisibleTabCodes = _sortedVisibleTabCodes(widget.visibleTabCodes);
    _rebuildTabController(preferredCode: widget.preferredTabCode);
  }

  @override
  void didUpdateWidget(covariant MessagePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final updatedCodes = _sortedVisibleTabCodes(widget.visibleTabCodes);
    if (!listEquals(updatedCodes, _orderedVisibleTabCodes)) {
      final selectedCode = _currentSelectedTabCode();
      _orderedVisibleTabCodes = updatedCodes;
      _rebuildTabController(preferredCode: selectedCode);
    } else if (widget.preferredTabCode != oldWidget.preferredTabCode) {
      _selectPreferredTab(widget.preferredTabCode);
    }
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
      _currentTabIndex = 0;
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
    _currentTabIndex = initialIndex;
    _tabController!.addListener(_handleTabIndexChanged);
  }

  void _handleTabIndexChanged() {
    final controller = _tabController;
    if (controller == null || _currentTabIndex == controller.index) {
      return;
    }
    setState(() {
      _currentTabIndex = controller.index;
    });
  }

  void _selectPreferredTab(String? preferredCode) {
    final controller = _tabController;
    if (controller == null || preferredCode == null) {
      return;
    }
    final preferredIndex = _orderedVisibleTabCodes.indexOf(preferredCode);
    if (preferredIndex < 0 || preferredIndex == controller.index) {
      return;
    }
    controller.animateTo(preferredIndex);
  }

  String _tabTitle(String code) {
    switch (code) {
      case messageCenterTabCode:
        return '消息中心';
      case announcementManagementTabCode:
        return '公告管理';
      default:
        return code;
    }
  }

  Widget _buildTabContent(String code) {
    final currentIndex = _orderedVisibleTabCodes.indexOf(code);
    final isTabActive =
        currentIndex >= 0 &&
        widget.moduleActive &&
        _currentTabIndex == currentIndex;
    switch (code) {
      case messageCenterTabCode:
        return MessageCenterPage(
          session: widget.session,
          service: widget.service,
          onLogout: widget.onLogout,
          pollingEnabled: isTabActive,
          canPublishAnnouncement: widget.capabilityCodes.contains(
            'feature.message.announcement.publish',
          ),
          canViewDetail: widget.capabilityCodes.contains(
            'feature.message.detail.view',
          ),
          canUseJump: true,
          refreshTick: widget.refreshTick,
          onUnreadCountChanged: widget.onUnreadCountChanged,
          onNavigateToPage: widget.onNavigateToPage,
          routePayloadJson:
              widget.preferredTabCode == messageCenterTabCode
              ? widget.routePayloadJson
              : null,
          nowProvider: widget.nowProvider,
        );
      case announcementManagementTabCode:
        return AnnouncementManagementPage(
          session: widget.session,
          onLogout: widget.onLogout,
          service: widget.service,
        );
      default:
        return Center(child: Text('页面暂未实现：$code'));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_orderedVisibleTabCodes.isEmpty || _tabController == null) {
      return const Center(child: Text('当前账号没有可访问的消息模块页面。'));
    }

    return MessagePageShell(
      tabBar: Material(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: TabBar(
          controller: _tabController,
          tabs: _orderedVisibleTabCodes
              .map((code) => Tab(text: _tabTitle(code)))
              .toList(),
        ),
      ),
      tabBarView: TabBarView(
        controller: _tabController,
        children: _orderedVisibleTabCodes.map(_buildTabContent).toList(),
      ),
    );
  }
}
