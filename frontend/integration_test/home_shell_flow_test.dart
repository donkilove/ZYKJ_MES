import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';
import 'package:mes_client/core/models/app_session.dart';
import 'package:mes_client/core/models/authz_models.dart';
import 'package:mes_client/core/services/effective_clock.dart';
import 'package:mes_client/features/craft/models/craft_models.dart';
import 'package:mes_client/core/models/current_user.dart';
import 'package:mes_client/features/equipment/models/equipment_models.dart';
import 'package:mes_client/features/message/models/message_models.dart';
import 'package:mes_client/core/models/page_catalog_models.dart';
import 'package:mes_client/features/product/models/product_models.dart';
import 'package:mes_client/features/production/models/production_models.dart';
import 'package:mes_client/features/quality/models/quality_models.dart';
import 'package:mes_client/features/user/models/user_models.dart';
import 'package:mes_client/features/user/presentation/account_settings_page.dart';
import 'package:mes_client/features/craft/presentation/craft_page.dart';
import 'package:mes_client/features/misc/presentation/login_page.dart';
import 'package:mes_client/features/shell/presentation/main_shell_page.dart';
import 'package:mes_client/features/equipment/presentation/maintenance_execution_detail_page.dart';
import 'package:mes_client/features/equipment/presentation/maintenance_execution_page.dart';
import 'package:mes_client/features/craft/presentation/process_management_page.dart';
import 'package:mes_client/features/product/presentation/product_page.dart';
import 'package:mes_client/features/product/presentation/product_version_management_page.dart';
import 'package:mes_client/features/production/presentation/production_assist_records_page.dart';
import 'package:mes_client/features/production/presentation/production_page.dart';
import 'package:mes_client/features/quality/presentation/quality_page.dart';
import 'package:mes_client/features/equipment/presentation/equipment_page.dart';
import 'package:mes_client/features/user/presentation/user_page.dart';
import 'package:mes_client/features/auth/services/auth_service.dart';
import 'package:mes_client/features/auth/services/authz_service.dart';
import 'package:mes_client/features/craft/services/craft_service.dart';
import 'package:mes_client/features/equipment/services/equipment_service.dart';
import 'package:mes_client/features/message/services/message_service.dart';
import 'package:mes_client/features/message/services/message_ws_service.dart';
import 'package:mes_client/features/settings/presentation/software_settings_controller.dart';
import 'package:mes_client/core/services/page_catalog_service.dart';
import 'package:mes_client/features/time_sync/models/time_sync_models.dart';
import 'package:mes_client/features/time_sync/presentation/time_sync_controller.dart';
import 'package:mes_client/features/time_sync/services/server_time_service.dart';
import 'package:mes_client/features/time_sync/services/windows_time_sync_service.dart';
import 'package:mes_client/features/product/services/product_service.dart';
import 'package:mes_client/features/production/services/production_service.dart';
import 'package:mes_client/features/quality/services/quality_service.dart';
import 'package:mes_client/features/user/services/user_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final realBackendConfig = _RealBackendConfig.fromEnvironment();

  testWidgets('登录后进入主壳首页并可从工作台快速跳转到用户模块', (tester) async {
    final authService = _IntegrationAuthService();

    await _pumpHomeShellApp(
      tester,
      authService: authService,
      messageService: _IntegrationMessageService(items: const []),
    );

    await _login(tester);

    expect(find.text('工作台'), findsOneWidget);
    expect(find.textContaining('测试用户'), findsWidgets);
    expect(find.byType(Badge), findsNothing);

    await tester.tap(find.text('用户').first);
    await tester.pumpAndSettle();

    expect(find.text('个人中心'), findsWidgets);
    expect(authService.lastUsername, 'tester');
    expect(authService.lastPassword, 'Pass123');
  });

  testWidgets('登录后主壳可切换到软件设置并返回首页', (tester) async {
    final authService = _IntegrationAuthService();

    await _pumpHomeShellApp(
      tester,
      authService: authService,
      messageService: _IntegrationMessageService(items: const []),
    );

    await _login(tester);

    await tester.tap(
      find.byKey(const ValueKey('main-shell-entry-software-settings')),
    );
    await tester.pumpAndSettle();

    expect(find.text('控制本机软件的外观、布局和时间同步偏好。'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('main-shell-menu-home')));
    await tester.pumpAndSettle();

    expect(find.text('工作台'), findsOneWidget);
  });

  if (realBackendConfig.enabled) {
    testWidgets('真实后端登录后进入主壳首页并打开消息中心列表', (tester) async {
      final authService = AuthService();
      var stage = 'app_bootstrap';

      try {
        await _pumpHomeShellApp(
          tester,
          authService: authService,
          messageService: _RealBackendSingleMessageService(
            realBackendConfig: realBackendConfig,
            messageId: 1061,
          ),
          realBackendConfig: realBackendConfig,
        );

        stage = 'login';
        await _login(
          tester,
          baseUrl: realBackendConfig.baseUrl,
          username: realBackendConfig.username,
          password: realBackendConfig.password,
        );

        expect(find.text('工作台'), findsOneWidget);

        stage = 'message_center_navigation';
        await tester.tap(find.text('消息').first);
        await tester.pumpAndSettle();

        expect(find.text('消息中心'), findsOneWidget);
        expect(find.text('未读消息'), findsOneWidget);

        stage = 'messages';

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      } catch (error) {
        fail(
          '真实后端链路在阶段[${_diagnoseFailureStage(tester, fallback: stage)}]失败：$error\n'
          '可见文本：${_collectVisibleTexts(tester)}',
        );
      }
    });

    testWidgets('真实后端登录后可从主壳侧边栏切换到多业务总页并命中稳定锚点', (tester) async {
      final authService = AuthService();
      var stage = 'app_bootstrap';

      try {
        await _pumpHomeShellApp(
          tester,
          authService: authService,
          messageService: _RealBackendSingleMessageService(
            realBackendConfig: realBackendConfig,
            messageId: 1108,
          ),
          realBackendConfig: realBackendConfig,
        );

        stage = 'login';
        await _login(
          tester,
          baseUrl: realBackendConfig.baseUrl,
          username: realBackendConfig.username,
          password: realBackendConfig.password,
        );

        expect(find.text('工作台'), findsOneWidget);

        stage = 'user_overview_navigation';
        await _openShellSidebarPageAndExpectAnchor(
          tester,
          sidebarTitle: '用户',
          stableAnchors: const ['用户管理', '个人中心'],
        );

        stage = 'product_overview_navigation';
        await _openShellSidebarPageAndExpectAnchor(
          tester,
          sidebarTitle: '产品',
          stableAnchors: const ['产品管理', '版本管理'],
        );

        stage = 'craft_overview_navigation';
        await _openShellSidebarPageAndExpectAnchor(
          tester,
          sidebarTitle: '工艺',
          stableAnchors: const ['工序管理', '生产工序配置'],
        );

        stage = 'production_overview_navigation';
        await _openShellSidebarPageAndExpectAnchor(
          tester,
          sidebarTitle: '生产',
          stableAnchors: const ['订单管理', '订单查询'],
        );

        stage = 'quality_overview_navigation';
        await _openShellSidebarPageAndExpectAnchor(
          tester,
          sidebarTitle: '质量',
          stableAnchors: const ['每日首件', '质量数据'],
        );

        stage = 'equipment_overview_navigation';
        await _openShellSidebarPageAndExpectAnchor(
          tester,
          sidebarTitle: '设备',
          stableAnchors: const ['设备台账', '保养执行'],
        );

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      } catch (error) {
        fail(
          '真实后端总页链路在阶段[${_diagnoseFailureStage(tester, fallback: stage)}]失败：$error\n'
          '可见文本：${_collectVisibleTexts(tester)}',
        );
      }
    });

    testWidgets('真实后端消息 1061 可从消息中心跳转到生产订单管理页', (tester) async {
      final authService = AuthService();
      var stage = 'app_bootstrap';

      try {
        await _pumpHomeShellApp(
          tester,
          authService: authService,
          messageService: _RealBackendSingleMessageService(
            realBackendConfig: realBackendConfig,
            messageId: 1061,
          ),
          realBackendConfig: realBackendConfig,
        );

        stage = 'message_center';
        await _loginAndOpenRealBackendMessageCenter(
          tester,
          realBackendConfig: realBackendConfig,
        );

        stage = 'locate_message_1061';
        await _selectRealBackendMessageInList(
          tester,
          messageId: 1061,
          sourceObjectText: 'PO-IT-1775415375779',
        );

        stage = 'jump_message_1061';
        await _tapMessageJumpAndWaitForShellPage(
          tester,
          messageId: 1061,
          expectedMenuCode: 'production',
          visibleTexts: const ['订单管理'],
        );

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      } catch (error) {
        fail(
          '真实消息[1061]链路在阶段[${_diagnoseFailureStage(tester, fallback: stage)}]失败：$error\n'
          '可见文本：${_collectVisibleTexts(tester)}',
        );
      }
    });

    testWidgets('真实后端消息 1108 可从消息中心跳转到注册审批页', (tester) async {
      final authService = AuthService();
      var stage = 'app_bootstrap';

      try {
        await _pumpHomeShellApp(
          tester,
          authService: authService,
          messageService: _RealBackendSingleMessageService(
            realBackendConfig: realBackendConfig,
            messageId: 1108,
          ),
          realBackendConfig: realBackendConfig,
        );

        stage = 'message_center';
        await _loginAndOpenRealBackendMessageCenter(
          tester,
          realBackendConfig: realBackendConfig,
        );

        stage = 'locate_message_1108';
        await _selectRealBackendMessageInList(
          tester,
          messageId: 1108,
          sourceObjectText: 'p813747900',
        );

        stage = 'jump_message_1108';
        await _tapMessageJumpAndWaitForShellPage(
          tester,
          messageId: 1108,
          expectedMenuCode: 'user',
          visibleTexts: const ['注册审批', '申请状态', '用户名'],
          containingTexts: const ['目标注册申请 #572'],
        );

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      } catch (error) {
        fail(
          '真实消息[1108]链路在阶段[${_diagnoseFailureStage(tester, fallback: stage)}]失败：$error\n'
          '可见文本：${_collectVisibleTexts(tester)}',
        );
      }
    });

    testWidgets('真实后端消息 1007 可从消息中心跳转到生产工序配置目标版本', (tester) async {
      final authService = AuthService();
      var stage = 'app_bootstrap';

      try {
        await _pumpHomeShellApp(
          tester,
          authService: authService,
          messageService: _RealBackendSingleMessageService(
            realBackendConfig: realBackendConfig,
            messageId: 1007,
          ),
          realBackendConfig: realBackendConfig,
        );

        stage = 'message_center';
        await _loginAndOpenRealBackendMessageCenter(
          tester,
          realBackendConfig: realBackendConfig,
        );

        stage = 'locate_message_1007';
        await _selectRealBackendMessageInList(tester, messageId: 1007);

        stage = 'jump_message_1007';
        await _tapMessageJumpAndWaitForShellPage(
          tester,
          messageId: 1007,
          expectedMenuCode: 'craft',
          visibleTexts: const ['生产工序配置', '已自动定位目标版本 v2'],
        );

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      } catch (error) {
        fail(
          '真实消息[1007]链路在阶段[${_diagnoseFailureStage(tester, fallback: stage)}]失败：$error\n'
          '可见文本：${_collectVisibleTexts(tester)}',
        );
      }
    });
  }

  testWidgets('登录后经主壳和消息中心跳转到生产代班记录详情', (tester) async {
    final authService = _IntegrationAuthService();
    final message = _buildMessageItem(
      id: 401,
      title: '生产代班待处理',
      summary: '请查看 authorization_id=501 的代班记录。',
      sourceModule: 'production',
    );

    await _pumpHomeShellApp(
      tester,
      authService: authService,
      messageService: _IntegrationMessageService(
        items: [message],
        jumpResults: {
          message.id: const MessageJumpResult(
            canJump: true,
            disabledReason: null,
            targetPageCode: 'production',
            targetTabCode: productionAssistRecordsTabCode,
            targetRoutePayloadJson:
                '{"action":"detail","authorization_id":501}',
          ),
        },
      ),
      productionService: _IntegrationProductionService(),
    );

    await _loginAndOpenMessageCenter(tester);

    await tester.tap(find.byKey(const ValueKey('message-center-tile-401')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('message-center-preview-jump-401')),
    );
    await tester.pumpAndSettle();

    expect(find.text('代班记录'), findsWidgets);
    expect(find.text('代班记录详情'), findsOneWidget);
    expect(find.text('PO-ASSIST-501'), findsWidgets);
  });

  testWidgets('登录后经主壳和消息中心跳转到质量每日首件详情', (tester) async {
    final authService = _IntegrationAuthService();
    final message = _buildMessageItem(
      id: 402,
      title: '每日首件复核',
      summary: '请查看 record_id=301 的每日首件。',
      sourceModule: 'quality',
    );

    await _pumpHomeShellApp(
      tester,
      authService: authService,
      messageService: _IntegrationMessageService(
        items: [message],
        jumpResults: {
          message.id: const MessageJumpResult(
            canJump: true,
            disabledReason: null,
            targetPageCode: 'quality',
            targetTabCode: firstArticleManagementTabCode,
            targetRoutePayloadJson: '{"action":"detail","record_id":301}',
          ),
        },
      ),
      qualityService: _IntegrationQualityService(),
    );

    await _loginAndOpenMessageCenter(tester);

    await tester.tap(find.byKey(const ValueKey('message-center-tile-402')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('message-center-preview-jump-402')),
    );
    await tester.pumpAndSettle();

    expect(find.text('首件详情 #301'), findsOneWidget);
    expect(find.text('首件基础信息'), findsOneWidget);
    expect(find.text('默认首件模板'), findsOneWidget);
  });

  testWidgets('登录后经主壳和消息中心跳转到个人中心修改密码锚点', (tester) async {
    final authService = _IntegrationAuthService();
    final message = _buildMessageItem(
      id: 403,
      title: '请修改初始密码',
      summary: '请前往个人中心完成密码修改。',
      sourceModule: 'user',
    );

    await _pumpHomeShellApp(
      tester,
      authService: authService,
      messageService: _IntegrationMessageService(
        items: [message],
        jumpResults: {
          message.id: const MessageJumpResult(
            canJump: true,
            disabledReason: null,
            targetPageCode: 'user',
            targetTabCode: 'account_settings',
            targetRoutePayloadJson: '{"action":"change_password"}',
          ),
        },
      ),
      userService: _IntegrationUserService(),
    );

    await _loginAndOpenMessageCenter(tester);

    await tester.tap(find.byKey(const ValueKey('message-center-tile-403')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('message-center-preview-jump-403')),
    );
    await tester.pumpAndSettle();

    expect(find.text('个人中心'), findsWidgets);
    expect(find.text('修改密码'), findsWidgets);
    expect(
      find.byKey(const ValueKey('account-settings-change-password-anchor')),
      findsOneWidget,
    );
  });

  testWidgets('登录后经主壳和消息中心跳转到产品版本管理页', (tester) async {
    final authService = _IntegrationAuthService();
    final message = _buildMessageItem(
      id: 404,
      title: '产品版本待确认',
      summary: '请查看产品66的版本信息。',
      sourceModule: 'product',
    );

    await _pumpHomeShellApp(
      tester,
      authService: authService,
      messageService: _IntegrationMessageService(
        items: [message],
        jumpResults: {
          message.id: const MessageJumpResult(
            canJump: true,
            disabledReason: null,
            targetPageCode: 'product',
            targetTabCode: productVersionManagementTabCode,
            targetRoutePayloadJson:
                '{"target_tab_code":"product_version_management","action":"view_version","product_id":66,"product_name":"产品66","target_version":3,"target_version_label":"V3.0"}',
          ),
        },
      ),
      productService: _IntegrationProductService(),
    );

    await _loginAndOpenMessageCenter(tester);

    await tester.tap(find.byKey(const ValueKey('message-center-tile-404')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('message-center-preview-jump-404')),
    );
    await tester.pumpAndSettle();

    expect(find.text('版本管理'), findsWidgets);
    expect(find.text('产品66'), findsWidgets);
    expect(find.textContaining('当前选中：V3.0'), findsOneWidget);
  });

  testWidgets('登录后经主壳和消息中心跳转到工艺工序管理页', (tester) async {
    final authService = _IntegrationAuthService();
    final message = _buildMessageItem(
      id: 405,
      title: '工序待处理',
      summary: '请查看工序71。',
      sourceModule: 'craft',
    );

    await _pumpHomeShellApp(
      tester,
      authService: authService,
      messageService: _IntegrationMessageService(
        items: [message],
        jumpResults: {
          message.id: const MessageJumpResult(
            canJump: true,
            disabledReason: null,
            targetPageCode: 'craft',
            targetTabCode: processManagementTabCode,
            targetRoutePayloadJson:
                '{"target_tab_code":"process_management","process_id":"71"}',
          ),
        },
      ),
      craftService: _IntegrationCraftService(),
    );

    await _loginAndOpenMessageCenter(tester);

    await tester.tap(find.byKey(const ValueKey('message-center-tile-405')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('message-center-preview-jump-405')),
    );
    await tester.pumpAndSettle();

    expect(find.text('工序管理'), findsWidgets);
    expect(
      find.byKey(const ValueKey('process-management-feedback-banner')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('process-management-view-switch')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('process-item-panel')), findsOneWidget);
    expect(find.byKey(const ValueKey('process-stage-panel')), findsNothing);
    expect(find.textContaining('已定位工序 #71 装配检验'), findsOneWidget);
  });

  testWidgets('登录后经主壳和消息中心跳转到设备保养执行详情', (tester) async {
    final authService = _IntegrationAuthService();
    final message = _buildMessageItem(
      id: 406,
      title: '保养工单待执行',
      summary: '请查看保养工单4。',
      sourceModule: 'equipment',
    );

    await _pumpHomeShellApp(
      tester,
      authService: authService,
      messageService: _IntegrationMessageService(
        items: [message],
        jumpResults: {
          message.id: const MessageJumpResult(
            canJump: true,
            disabledReason: null,
            targetPageCode: maintenanceExecutionTabCode,
            targetTabCode: null,
            targetRoutePayloadJson: '{"action":"detail","work_order_id":"4"}',
          ),
        },
      ),
      craftService: _IntegrationCraftService(),
      equipmentService: _IntegrationEquipmentService(),
    );

    await _loginAndOpenMessageCenter(tester);

    await tester.tap(find.byKey(const ValueKey('message-center-tile-406')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('message-center-preview-jump-406')),
    );
    await tester.pumpAndSettle();

    expect(find.text('保养执行详情 #4'), findsOneWidget);
    expect(find.text('数控冲床-01'), findsWidgets);
    expect(find.text('润滑巡检'), findsWidgets);
  });

  testWidgets('登录后经主壳和消息中心跳转到质量维修订单详情', (tester) async {
    final authService = _IntegrationAuthService();
    final message = _buildMessageItem(
      id: 407,
      title: '维修订单待处理',
      summary: '请查看维修单 RW-21。',
      sourceModule: 'quality',
    );

    await _pumpHomeShellApp(
      tester,
      authService: authService,
      messageService: _IntegrationMessageService(
        items: [message],
        jumpResults: {
          message.id: const MessageJumpResult(
            canJump: true,
            disabledReason: null,
            targetPageCode: 'quality',
            targetTabCode: qualityRepairOrdersTabCode,
            targetRoutePayloadJson:
                '{"action":"detail","repair_order_id":7,"repair_order_code":"RW-21"}',
          ),
        },
      ),
      qualityService: _IntegrationQualityService(),
    );

    await _loginAndOpenMessageCenter(tester);

    await tester.tap(find.byKey(const ValueKey('message-center-tile-407')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('message-center-preview-jump-407')),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('维修详情'), findsOneWidget);
    expect(find.text('缺陷现象'), findsOneWidget);
    expect(find.textContaining('虚焊'), findsWidgets);
  });

  testWidgets('登录后经主壳和消息中心跳转到质量报废统计详情', (tester) async {
    final authService = _IntegrationAuthService();
    final message = _buildMessageItem(
      id: 408,
      title: '报废统计待处理',
      summary: '请查看报废记录 21。',
      sourceModule: 'quality',
    );

    await _pumpHomeShellApp(
      tester,
      authService: authService,
      messageService: _IntegrationMessageService(
        items: [message],
        jumpResults: {
          message.id: const MessageJumpResult(
            canJump: true,
            disabledReason: null,
            targetPageCode: 'quality',
            targetTabCode: qualityScrapStatisticsTabCode,
            targetRoutePayloadJson:
                '{"action":"detail","scrap_id":"21","order_code":"PO-21"}',
          ),
        },
      ),
      qualityService: _IntegrationQualityService(),
    );

    await _loginAndOpenMessageCenter(tester);

    await tester.tap(find.byKey(const ValueKey('message-center-tile-408')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('message-center-preview-jump-408')),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('报废详情'), findsOneWidget);
    expect(find.text('关联维修工单'), findsOneWidget);
    expect(find.text('RW-21'), findsOneWidget);
  });
}

Future<void> _pumpHomeShellApp(
  WidgetTester tester, {
  required AuthService authService,
  MessageService? messageService,
  _IntegrationUserService? userService,
  _IntegrationProductService? productService,
  _IntegrationCraftService? craftService,
  _IntegrationEquipmentService? equipmentService,
  _IntegrationProductionService? productionService,
  _IntegrationQualityService? qualityService,
  _RealBackendConfig? realBackendConfig,
}) async {
  tester.view.physicalSize = const Size(1600, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  await tester.pumpWidget(
    MaterialApp(
      home: _HomeShellIntegrationApp(
        authService: authService,
        messageService: messageService,
        userService: userService ?? _IntegrationUserService(),
        productService: productService ?? _IntegrationProductService(),
        craftService: craftService ?? _IntegrationCraftService(),
        equipmentService: equipmentService ?? _IntegrationEquipmentService(),
        productionService: productionService ?? _IntegrationProductionService(),
        qualityService: qualityService ?? _IntegrationQualityService(),
        realBackendConfig: realBackendConfig,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _login(
  WidgetTester tester, {
  String? baseUrl,
  String username = 'tester',
  String password = 'Pass123',
}) async {
  if (baseUrl != null) {
    await tester.enterText(find.byType(TextFormField).first, baseUrl);
    await tester.pump();
  }
  await tester.enterText(
    find.byKey(const Key('login-account-field')),
    username,
  );
  await tester.enterText(
    find.byKey(const Key('login-password-field')),
    password,
  );
  await tester.tap(find.byKey(const Key('login-submit-button')));
  await tester.pumpAndSettle();
}

Future<void> _loginAndOpenMessageCenter(WidgetTester tester) async {
  await _login(tester);

  expect(find.text('工作台'), findsOneWidget);

  await tester.tap(find.text('消息').first);
  await tester.pumpAndSettle();

  expect(find.text('消息中心'), findsOneWidget);
}

Future<void> _loginAndOpenRealBackendMessageCenter(
  WidgetTester tester, {
  required _RealBackendConfig realBackendConfig,
}) async {
  await _login(
    tester,
    baseUrl: realBackendConfig.baseUrl,
    username: realBackendConfig.username,
    password: realBackendConfig.password,
  );

  expect(find.text('工作台'), findsOneWidget);

  await tester.tap(find.text('消息').first);
  await tester.pumpAndSettle();

  expect(find.text('消息中心'), findsOneWidget);
}

Future<void> _selectRealBackendMessageInList(
  WidgetTester tester, {
  required int messageId,
  String? sourceObjectText,
}) async {
  final tileFinder = find.byKey(ValueKey('message-center-tile-$messageId'));
  final jumpButtonFinder = find.byKey(
    ValueKey('message-center-preview-jump-$messageId'),
  );

  for (var index = 0; index < 20; index += 1) {
    if (tileFinder.evaluate().isNotEmpty) {
      break;
    }
    await tester.pump(const Duration(milliseconds: 300));
  }

  if (tileFinder.evaluate().isEmpty) {
    fail(
      '消息 $messageId 未出现在消息中心列表。'
      '空态=${find.text('暂无消息').evaluate().isNotEmpty} '
      '错误态=${find.textContaining('StateError').evaluate().isNotEmpty || find.textContaining('请求失败').evaluate().isNotEmpty} '
      '可见文本：${_collectVisibleTexts(tester, maxItems: 40)}',
    );
  }

  if (sourceObjectText != null && sourceObjectText.isNotEmpty) {
    expect(find.textContaining(sourceObjectText), findsWidgets);
  }

  await tester.tap(tileFinder);
  await tester.pumpAndSettle();

  expect(jumpButtonFinder, findsOneWidget);
}

Future<void> _tapMessageJumpAndWaitForShellPage(
  WidgetTester tester, {
  required int messageId,
  required String expectedMenuCode,
  required List<String> visibleTexts,
  List<String> containingTexts = const [],
}) async {
  final jumpButtonFinder = find.byKey(
    ValueKey('message-center-preview-jump-$messageId'),
  );
  await tester.ensureVisible(jumpButtonFinder);
  await tester.tap(jumpButtonFinder.hitTestable());
  await tester.pump();

  await _waitForShellMenuSelection(tester, expectedMenuCode: expectedMenuCode);

  for (final text in visibleTexts) {
    await _waitForVisibleText(tester, text);
  }
  for (final text in containingTexts) {
    await _waitForVisibleContainingText(tester, text);
  }
}

Future<void> _waitForShellMenuSelection(
  WidgetTester tester, {
  required String expectedMenuCode,
}) async {
  final menuFinder = find.byKey(ValueKey('main-shell-menu-$expectedMenuCode'));
  final contentFinder = find.byKey(
    ValueKey('main-shell-content-$expectedMenuCode'),
  );

  for (var index = 0; index < 40; index += 1) {
    await tester.pump(const Duration(milliseconds: 200));
    if (menuFinder.evaluate().isEmpty || contentFinder.evaluate().isEmpty) {
      continue;
    }
    final tile = tester.widget<ListTile>(menuFinder);
    if (tile.selected) {
      return;
    }
  }

  fail(
    '主壳未切换到 [$expectedMenuCode]，当前可见文本：${_collectVisibleTexts(tester, maxItems: 40)}',
  );
}

Future<void> _waitForVisibleText(WidgetTester tester, String text) async {
  for (var index = 0; index < 40; index += 1) {
    await tester.pump(const Duration(milliseconds: 200));
    if (find.text(text).hitTestable().evaluate().isNotEmpty) {
      return;
    }
  }

  fail('未在可见区域发现文本 [$text]。可见文本：${_collectVisibleTexts(tester, maxItems: 40)}');
}

Future<void> _waitForVisibleContainingText(
  WidgetTester tester,
  String text,
) async {
  for (var index = 0; index < 40; index += 1) {
    await tester.pump(const Duration(milliseconds: 200));
    if (find.textContaining(text).hitTestable().evaluate().isNotEmpty) {
      return;
    }
  }

  fail(
    '未在可见区域发现包含 [$text] 的文本。可见文本：${_collectVisibleTexts(tester, maxItems: 40)}',
  );
}

class _RealBackendSingleMessageService extends MessageService {
  _RealBackendSingleMessageService({
    required this.realBackendConfig,
    required this.messageId,
  }) : super(AppSession(baseUrl: realBackendConfig.baseUrl, accessToken: ''));

  final _RealBackendConfig realBackendConfig;
  final int messageId;

  String? _accessToken;
  MessageDetailResult? _cachedDetail;

  Future<String> _ensureAccessToken() async {
    final existing = _accessToken;
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }
    final response = await http.post(
      Uri.parse('${realBackendConfig.baseUrl}/auth/login'),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'username': realBackendConfig.username,
        'password': realBackendConfig.password,
      },
    );
    _checkStatus(response);
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final data = body['data'] as Map<String, dynamic>? ?? const {};
    final token = data['access_token'] as String? ?? '';
    if (token.isEmpty) {
      throw StateError('真实后端登录成功但缺少 access_token');
    }
    _accessToken = token;
    return token;
  }

  Future<Map<String, String>> _headers() async {
    final token = await _ensureAccessToken();
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
  }

  Future<Map<String, dynamic>> _getJson(String path) async {
    final response = await http.get(
      Uri.parse('${realBackendConfig.baseUrl}$path'),
      headers: await _headers(),
    );
    _checkStatus(response);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<MessageDetailResult> _loadDetail({bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedDetail != null) {
      return _cachedDetail!;
    }
    final body = await _getJson('/messages/$messageId');
    final detail = MessageDetailResult.fromJson(
      body['data'] as Map<String, dynamic>,
    );
    _cachedDetail = detail;
    return detail;
  }

  @override
  Future<int> getUnreadCount() async {
    final detail = await _loadDetail();
    return detail.item.isRead ? 0 : 1;
  }

  @override
  Future<MessageSummaryResult> getSummary() async {
    final detail = await _loadDetail();
    final unreadCount = detail.item.isRead ? 0 : 1;
    final todoUnreadCount =
        !detail.item.isRead && detail.item.messageType == 'todo' ? 1 : 0;
    final urgentUnreadCount =
        !detail.item.isRead && detail.item.priority == 'urgent' ? 1 : 0;
    return MessageSummaryResult(
      totalCount: 1,
      unreadCount: unreadCount,
      todoUnreadCount: todoUnreadCount,
      urgentUnreadCount: urgentUnreadCount,
    );
  }

  @override
  Future<MessageListResult> listMessages({
    int page = 1,
    int pageSize = 20,
    String? keyword,
    String? status,
    String? messageType,
    String? priority,
    String? sourceModule,
    DateTime? startTime,
    DateTime? endTime,
    bool todoOnly = false,
    bool activeOnly = true,
  }) async {
    final detail = await _loadDetail();
    final item = detail.item;
    final normalizedKeyword = keyword?.trim().toLowerCase() ?? '';
    final matchesKeyword =
        normalizedKeyword.isEmpty ||
        item.title.toLowerCase().contains(normalizedKeyword) ||
        (item.summary?.toLowerCase().contains(normalizedKeyword) ?? false) ||
        (item.sourceCode?.toLowerCase().contains(normalizedKeyword) ?? false);
    final matchesStatus =
        status == null ||
        status.isEmpty ||
        (status == 'read' && item.isRead) ||
        (status == 'unread' && !item.isRead);
    final matchesType =
        messageType == null ||
        messageType.isEmpty ||
        item.messageType == messageType;
    final matchesPriority =
        priority == null || priority.isEmpty || item.priority == priority;
    final matchesModule =
        sourceModule == null ||
        sourceModule.isEmpty ||
        item.sourceModule == sourceModule;
    final matchesTodo = !todoOnly || item.messageType == 'todo';
    final matchesActive = !activeOnly || item.isActive;
    final matchesStart =
        startTime == null ||
        item.publishedAt == null ||
        !item.publishedAt!.isBefore(startTime);
    final matchesEnd =
        endTime == null ||
        item.publishedAt == null ||
        !item.publishedAt!.isAfter(endTime);
    final items =
        matchesKeyword &&
            matchesStatus &&
            matchesType &&
            matchesPriority &&
            matchesModule &&
            matchesTodo &&
            matchesActive &&
            matchesStart &&
            matchesEnd
        ? [item]
        : const <MessageItem>[];
    return MessageListResult(
      items: items,
      total: items.length,
      page: page,
      pageSize: pageSize,
    );
  }

  @override
  Future<void> markRead(int messageId) async {
    final response = await http.post(
      Uri.parse('${realBackendConfig.baseUrl}/messages/$messageId/read'),
      headers: await _headers(),
    );
    _checkStatus(response);
    _cachedDetail = null;
  }

  @override
  Future<MessageDetailResult> getMessageDetail(int messageId) async {
    return _loadDetail(forceRefresh: true);
  }

  @override
  Future<MessageJumpResult> getMessageJumpTarget(int messageId) async {
    final body = await _getJson('/messages/$messageId/jump-target');
    return MessageJumpResult.fromJson(body['data'] as Map<String, dynamic>);
  }

  void _checkStatus(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }
    var message = '请求失败（${response.statusCode}）';
    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final detail = body['detail'];
      if (detail is String && detail.isNotEmpty) {
        message = detail;
      }
    } catch (_) {}
    throw StateError(message);
  }
}

Future<void> _openShellSidebarPageAndExpectAnchor(
  WidgetTester tester, {
  required String sidebarTitle,
  required List<String> stableAnchors,
}) async {
  final sidebarFinder = find.widgetWithText(ListTile, sidebarTitle);
  if (sidebarFinder.evaluate().isEmpty) {
    fail(
      '真实后端未暴露[$sidebarTitle]侧边栏入口，疑似 authz/page-catalog 未返回该总页。'
      '可见文本：${_collectVisibleTexts(tester)}',
    );
  }

  await tester.tap(sidebarFinder.first);
  await tester.pumpAndSettle();

  final matchedAnchors = stableAnchors
      .where((anchor) => find.text(anchor).evaluate().isNotEmpty)
      .toList();
  if (matchedAnchors.isEmpty) {
    fail(
      '已点击[$sidebarTitle]侧边栏入口，但未发现稳定锚点${stableAnchors.join('/')}，'
      '疑似总页装配结果与 authz/page-catalog 返回不一致。'
      '可见文本：${_collectVisibleTexts(tester)}',
    );
  }
}

String _diagnoseFailureStage(WidgetTester tester, {required String fallback}) {
  if (find.textContaining('登录失败').evaluate().isNotEmpty) {
    return 'login';
  }
  if (find.textContaining('加载当前用户失败').evaluate().isNotEmpty) {
    return 'authz';
  }
  if (find.textContaining('加载权限快照失败').evaluate().isNotEmpty) {
    return 'authz';
  }
  if (find.textContaining('页面目录加载失败').evaluate().isNotEmpty) {
    return 'page-catalog';
  }
  if (find.text('消息中心').evaluate().isNotEmpty) {
    return 'messages';
  }
  return fallback;
}

String _collectVisibleTexts(WidgetTester tester, {int maxItems = 12}) {
  final texts = find
      .byType(Text)
      .evaluate()
      .map((element) => element.widget)
      .whereType<Text>()
      .map((widget) => widget.data ?? widget.textSpan?.toPlainText() ?? '')
      .map((text) => text.trim())
      .where((text) => text.isNotEmpty)
      .toSet()
      .take(maxItems)
      .toList();
  return texts.isEmpty ? '无' : texts.join(' | ');
}

MessageItem _buildMessageItem({
  required int id,
  required String title,
  required String summary,
  required String sourceModule,
}) {
  return MessageItem(
    id: id,
    messageType: 'todo',
    priority: 'important',
    title: title,
    summary: summary,
    content: summary,
    sourceModule: sourceModule,
    sourceType: 'record',
    sourceCode: '$sourceModule-$id',
    targetPageCode: null,
    targetTabCode: null,
    targetRoutePayloadJson: null,
    status: 'active',
    inactiveReason: null,
    publishedAt: DateTime.parse('2026-04-06T09:00:00Z'),
    expiresAt: null,
    isRead: false,
    readAt: null,
    deliveredAt: DateTime.parse('2026-04-06T09:00:00Z'),
    deliveryStatus: 'delivered',
    deliveryAttemptCount: 1,
    lastPushAt: DateTime.parse('2026-04-06T09:00:00Z'),
    nextRetryAt: null,
  );
}

class _HomeShellIntegrationApp extends StatefulWidget {
  const _HomeShellIntegrationApp({
    required this.authService,
    required this.messageService,
    required this.userService,
    required this.productService,
    required this.craftService,
    required this.equipmentService,
    required this.productionService,
    required this.qualityService,
    this.realBackendConfig,
  });

  final AuthService authService;
  final MessageService? messageService;
  final _IntegrationUserService userService;
  final _IntegrationProductService productService;
  final _IntegrationCraftService craftService;
  final _IntegrationEquipmentService equipmentService;
  final _IntegrationProductionService productionService;
  final _IntegrationQualityService qualityService;
  final _RealBackendConfig? realBackendConfig;

  @override
  State<_HomeShellIntegrationApp> createState() =>
      _HomeShellIntegrationAppState();
}

class _HomeShellIntegrationAppState extends State<_HomeShellIntegrationApp> {
  AppSession? _session;
  final SoftwareSettingsController _softwareSettingsController =
      SoftwareSettingsController.memory();
  late final TimeSyncController _timeSyncController = _buildTimeSyncController(
    _softwareSettingsController,
  );

  @override
  Widget build(BuildContext context) {
    final useRealBackend = widget.realBackendConfig?.enabled ?? false;
    if (_session == null) {
      return LoginPage(
        defaultBaseUrl:
            widget.realBackendConfig?.baseUrl ?? 'http://example.test/api/v1',
        authService: widget.authService,
        onLoginSuccess: (session) {
          setState(() {
            _session = session;
          });
        },
      );
    }

    return MainShellPage(
      session: _session!,
      onLogout: () {
        setState(() {
          _session = null;
        });
      },
      softwareSettingsController: _softwareSettingsController,
      timeSyncController: _timeSyncController,
      authService: widget.authService,
      authzService: useRealBackend ? null : _IntegrationAuthzService(),
      pageCatalogService: useRealBackend
          ? null
          : _IntegrationPageCatalogService(),
      messageService: widget.messageService,
      messageWsServiceFactory:
          ({
            required baseUrl,
            required accessToken,
            required onEvent,
            required onDisconnected,
          }) => _IntegrationMessageWsService(
            baseUrl: baseUrl,
            accessToken: accessToken,
            onEvent: onEvent,
            onDisconnected: onDisconnected,
          ),
      userPageBuilder:
          ({
            required session,
            required onLogout,
            required visibleTabCodes,
            required capabilityCodes,
            String? preferredTabCode,
            String? routePayloadJson,
            VoidCallback? onVisibilityConfigSaved,
          }) {
            return UserPage(
              session: session,
              onLogout: onLogout,
              visibleTabCodes: visibleTabCodes,
              capabilityCodes: capabilityCodes,
              preferredTabCode: preferredTabCode,
              routePayloadJson: routePayloadJson,
              onVisibilityConfigSaved: onVisibilityConfigSaved,
              tabPageBuilder: (tabCode, child) {
                if (child is AccountSettingsPage) {
                  return AccountSettingsPage(
                    session: child.session,
                    onLogout: child.onLogout,
                    canChangePassword: child.canChangePassword,
                    canViewSession: child.canViewSession,
                    routePayloadJson: child.routePayloadJson,
                    userService: widget.userService,
                    authService: widget.authService,
                  );
                }
                return child;
              },
            );
          },
      productPageBuilder:
          ({
            required session,
            required onLogout,
            required visibleTabCodes,
            required capabilityCodes,
            String? preferredTabCode,
            String? routePayloadJson,
          }) {
            return ProductPage(
              session: session,
              onLogout: onLogout,
              visibleTabCodes: visibleTabCodes,
              capabilityCodes: capabilityCodes,
              preferredTabCode: preferredTabCode,
              routePayloadJson: routePayloadJson,
              productVersionService: widget.productService,
              tabPageBuilder: (tabCode, child) {
                if (child is ProductVersionManagementPage) {
                  return ProductVersionManagementPage(
                    session: child.session,
                    onLogout: child.onLogout,
                    tabCode: child.tabCode,
                    jumpCommand: child.jumpCommand,
                    onJumpHandled: child.onJumpHandled,
                    onEditVersionParameters: child.onEditVersionParameters,
                    canManageVersions: child.canManageVersions,
                    canActivateVersions: child.canActivateVersions,
                    canExportVersionParameters:
                        child.canExportVersionParameters,
                    service: widget.productService,
                  );
                }
                return child;
              },
            );
          },
      equipmentPageBuilder:
          ({
            required session,
            required onLogout,
            required visibleTabCodes,
            required capabilityCodes,
            String? preferredTabCode,
            String? routePayloadJson,
          }) {
            return EquipmentPage(
              session: session,
              onLogout: onLogout,
              visibleTabCodes: visibleTabCodes,
              capabilityCodes: capabilityCodes,
              preferredTabCode: preferredTabCode,
              routePayloadJson: routePayloadJson,
              tabPageBuilder: (tabCode, child) {
                if (child is MaintenanceExecutionPage) {
                  return MaintenanceExecutionPage(
                    session: child.session,
                    onLogout: child.onLogout,
                    canExecute: child.canExecute,
                    jumpPayloadJson: child.jumpPayloadJson,
                    equipmentService: widget.equipmentService,
                    craftService: widget.craftService,
                    detailPageBuilder: (context, workOrderId) {
                      return MaintenanceExecutionDetailPage(
                        session: child.session,
                        onLogout: child.onLogout,
                        workOrderId: workOrderId,
                        service: widget.equipmentService,
                      );
                    },
                  );
                }
                return child;
              },
            );
          },
      productionPageBuilder:
          ({
            required session,
            required onLogout,
            required visibleTabCodes,
            required capabilityCodes,
            String? preferredTabCode,
            String? routePayloadJson,
          }) {
            return ProductionPage(
              session: session,
              onLogout: onLogout,
              visibleTabCodes: visibleTabCodes,
              capabilityCodes: capabilityCodes,
              preferredTabCode: preferredTabCode,
              routePayloadJson: routePayloadJson,
              tabPageBuilder: (tabCode, child) {
                if (child is ProductionAssistRecordsPage) {
                  return ProductionAssistRecordsPage(
                    session: child.session,
                    onLogout: child.onLogout,
                    canViewRecords: child.canViewRecords,
                    routePayloadJson: child.routePayloadJson,
                    service: widget.productionService,
                  );
                }
                return child;
              },
            );
          },
      qualityPageBuilder:
          ({
            required session,
            required onLogout,
            required visibleTabCodes,
            required capabilityCodes,
            String? preferredTabCode,
            String? routePayloadJson,
          }) {
            return QualityPage(
              session: session,
              onLogout: onLogout,
              visibleTabCodes: visibleTabCodes,
              capabilityCodes: capabilityCodes,
              preferredTabCode: preferredTabCode,
              routePayloadJson: routePayloadJson,
              firstArticleService: widget.qualityService,
              repairScrapService: widget.qualityService,
            );
          },
      craftPageBuilder:
          ({
            required session,
            required onLogout,
            required visibleTabCodes,
            required capabilityCodes,
            String? preferredTabCode,
            String? routePayloadJson,
          }) {
            return CraftPage(
              session: session,
              onLogout: onLogout,
              visibleTabCodes: visibleTabCodes,
              capabilityCodes: capabilityCodes,
              preferredTabCode: preferredTabCode,
              routePayloadJson: routePayloadJson,
              tabPageBuilder: (tabCode, child) {
                if (child is ProcessManagementPage) {
                  return ProcessManagementPage(
                    session: child.session,
                    onLogout: child.onLogout,
                    canWrite: child.canWrite,
                    craftService: widget.craftService,
                    processId: child.processId,
                    jumpRequestId: child.jumpRequestId,
                  );
                }
                return child;
              },
            );
          },
    );
  }
}

TimeSyncController _buildTimeSyncController(
  SoftwareSettingsController controller,
) {
  return TimeSyncController(
    softwareSettingsController: controller,
    serverTimeService: _FakeServerTimeService(),
    systemTimeSyncService: _FakeWindowsTimeSyncService(),
    effectiveClock: EffectiveClock(),
  );
}

class _FakeServerTimeService extends ServerTimeService {
  @override
  Future<ServerTimeSnapshot> fetchSnapshot({required String baseUrl}) async {
    return ServerTimeSnapshot(
      serverUtc: DateTime.utc(2026, 4, 20, 2, 0, 0),
      serverTimezoneOffsetMinutes: 480,
      sampledAtEpochMs: DateTime.utc(
        2026,
        4,
        20,
        2,
        0,
        0,
      ).millisecondsSinceEpoch,
    );
  }
}

class _FakeWindowsTimeSyncService extends WindowsTimeSyncService {}

class _RealBackendConfig {
  const _RealBackendConfig({
    required this.enabled,
    required this.baseUrl,
    required this.username,
    required this.password,
  });

  final bool enabled;
  final String baseUrl;
  final String username;
  final String password;

  static _RealBackendConfig fromEnvironment() {
    return _RealBackendConfig(
      enabled: _readBool('MES_ITEST_REAL_BACKEND'),
      baseUrl: _readString(
        'MES_ITEST_BASE_URL',
        defaultValue: 'http://127.0.0.1:8000/api/v1',
      ),
      username: _readString('MES_ITEST_USERNAME', defaultValue: 'admin'),
      password: _readString('MES_ITEST_PASSWORD', defaultValue: 'Admin@123456'),
    );
  }

  static bool _readBool(String key) {
    final raw = _readString(key);
    return raw.toLowerCase() == 'true' || raw == '1';
  }

  static String _readString(String key, {String defaultValue = ''}) {
    const environment = String.fromEnvironment('unused_environment_probe');
    final dartDefineValue = switch (key) {
      'MES_ITEST_REAL_BACKEND' => const String.fromEnvironment(
        'MES_ITEST_REAL_BACKEND',
      ),
      'MES_ITEST_BASE_URL' => const String.fromEnvironment(
        'MES_ITEST_BASE_URL',
      ),
      'MES_ITEST_USERNAME' => const String.fromEnvironment(
        'MES_ITEST_USERNAME',
      ),
      'MES_ITEST_PASSWORD' => const String.fromEnvironment(
        'MES_ITEST_PASSWORD',
      ),
      _ => environment,
    };
    final processValue = Platform.environment[key];
    final value = dartDefineValue.isNotEmpty ? dartDefineValue : processValue;
    return (value == null || value.trim().isEmpty)
        ? defaultValue
        : value.trim();
  }
}

class _IntegrationAuthService extends AuthService {
  String? lastUsername;
  String? lastPassword;

  @override
  Future<List<String>> listAccounts({required String baseUrl}) async {
    return const ['tester'];
  }

  @override
  Future<({String token, bool mustChangePassword})> login({
    required String baseUrl,
    required String username,
    required String password,
  }) async {
    lastUsername = username;
    lastPassword = password;
    return (token: 'token', mustChangePassword: false);
  }

  @override
  Future<CurrentUser> getCurrentUser({
    required String baseUrl,
    required String accessToken,
  }) async {
    return CurrentUser(
      id: 1,
      username: 'tester',
      fullName: '测试用户',
      roleCode: 'user_admin',
      roleName: '系统管理员',
      stageId: null,
      stageName: null,
    );
  }

  @override
  Future<void> logout({
    required String baseUrl,
    required String accessToken,
  }) async {}
}

class _IntegrationAuthzService extends AuthzService {
  _IntegrationAuthzService()
    : super(
        AppSession(baseUrl: 'http://example.test/api/v1', accessToken: 'token'),
      );

  @override
  Future<AuthzSnapshotResult> loadAuthzSnapshot() async {
    return AuthzSnapshotResult(
      revision: 1,
      roleCodes: const ['user_admin'],
      visibleSidebarCodes: const [
        'user',
        'product',
        'equipment',
        'production',
        'quality',
        'craft',
        'message',
      ],
      tabCodesByParent: const {
        'user': ['account_settings'],
        'product': [productVersionManagementTabCode],
        'equipment': [maintenanceExecutionTabCode],
        'production': [productionAssistRecordsTabCode],
        'quality': [
          firstArticleManagementTabCode,
          qualityScrapStatisticsTabCode,
          qualityRepairOrdersTabCode,
        ],
        'craft': [processManagementTabCode],
        'message': ['message_center'],
      },
      moduleItems: const [
        AuthzSnapshotModuleItem(
          moduleCode: 'user',
          moduleName: '用户',
          moduleRevision: 1,
          moduleEnabled: true,
          effectivePermissionCodes: [],
          effectivePagePermissionCodes: [],
          effectiveCapabilityCodes: [],
          effectiveActionPermissionCodes: [],
        ),
        AuthzSnapshotModuleItem(
          moduleCode: 'product',
          moduleName: '产品',
          moduleRevision: 1,
          moduleEnabled: true,
          effectivePermissionCodes: [],
          effectivePagePermissionCodes: [],
          effectiveCapabilityCodes: [
            ProductFeaturePermissionCodes.versionsManage,
          ],
          effectiveActionPermissionCodes: [],
        ),
        AuthzSnapshotModuleItem(
          moduleCode: 'equipment',
          moduleName: '设备',
          moduleRevision: 1,
          moduleEnabled: true,
          effectivePermissionCodes: [],
          effectivePagePermissionCodes: [],
          effectiveCapabilityCodes: [
            EquipmentFeaturePermissionCodes.executionsOperate,
          ],
          effectiveActionPermissionCodes: [],
        ),
        AuthzSnapshotModuleItem(
          moduleCode: 'production',
          moduleName: '生产',
          moduleRevision: 1,
          moduleEnabled: true,
          effectivePermissionCodes: [],
          effectivePagePermissionCodes: [],
          effectiveCapabilityCodes: [
            ProductionFeaturePermissionCodes.assistRecordsView,
          ],
          effectiveActionPermissionCodes: [],
        ),
        AuthzSnapshotModuleItem(
          moduleCode: 'quality',
          moduleName: '质量',
          moduleRevision: 1,
          moduleEnabled: true,
          effectivePermissionCodes: [],
          effectivePagePermissionCodes: [],
          effectiveCapabilityCodes: [
            'quality.first_articles.detail',
            'quality.scrap_statistics.export',
            'quality.repair_orders.complete',
            'quality.repair_orders.export',
          ],
          effectiveActionPermissionCodes: [],
        ),
        AuthzSnapshotModuleItem(
          moduleCode: 'craft',
          moduleName: '工艺',
          moduleRevision: 1,
          moduleEnabled: true,
          effectivePermissionCodes: [],
          effectivePagePermissionCodes: [],
          effectiveCapabilityCodes: [
            CraftFeaturePermissionCodes.processBasicsManage,
          ],
          effectiveActionPermissionCodes: [],
        ),
        AuthzSnapshotModuleItem(
          moduleCode: 'message',
          moduleName: '消息',
          moduleRevision: 1,
          moduleEnabled: true,
          effectivePermissionCodes: [],
          effectivePagePermissionCodes: [],
          effectiveCapabilityCodes: ['feature.message.jump.use'],
          effectiveActionPermissionCodes: [],
        ),
      ],
    );
  }
}

class _IntegrationPageCatalogService extends PageCatalogService {
  _IntegrationPageCatalogService()
    : super(
        AppSession(baseUrl: 'http://example.test/api/v1', accessToken: 'token'),
      );

  @override
  Future<List<PageCatalogItem>> listPageCatalog() async {
    return const [
      PageCatalogItem(
        code: 'home',
        name: '首页',
        pageType: 'sidebar',
        parentCode: null,
        alwaysVisible: true,
        sortOrder: 10,
      ),
      PageCatalogItem(
        code: 'user',
        name: '用户',
        pageType: 'sidebar',
        parentCode: null,
        alwaysVisible: false,
        sortOrder: 20,
      ),
      PageCatalogItem(
        code: 'account_settings',
        name: '个人中心',
        pageType: 'tab',
        parentCode: 'user',
        alwaysVisible: false,
        sortOrder: 21,
      ),
      PageCatalogItem(
        code: 'product',
        name: '产品',
        pageType: 'sidebar',
        parentCode: null,
        alwaysVisible: false,
        sortOrder: 25,
      ),
      PageCatalogItem(
        code: productVersionManagementTabCode,
        name: '版本管理',
        pageType: 'tab',
        parentCode: 'product',
        alwaysVisible: false,
        sortOrder: 26,
      ),
      PageCatalogItem(
        code: 'equipment',
        name: '设备',
        pageType: 'sidebar',
        parentCode: null,
        alwaysVisible: false,
        sortOrder: 27,
      ),
      PageCatalogItem(
        code: maintenanceExecutionTabCode,
        name: '保养执行',
        pageType: 'tab',
        parentCode: 'equipment',
        alwaysVisible: false,
        sortOrder: 28,
      ),
      PageCatalogItem(
        code: 'production',
        name: '生产',
        pageType: 'sidebar',
        parentCode: null,
        alwaysVisible: false,
        sortOrder: 30,
      ),
      PageCatalogItem(
        code: productionAssistRecordsTabCode,
        name: '代班记录',
        pageType: 'tab',
        parentCode: 'production',
        alwaysVisible: false,
        sortOrder: 31,
      ),
      PageCatalogItem(
        code: 'quality',
        name: '质量',
        pageType: 'sidebar',
        parentCode: null,
        alwaysVisible: false,
        sortOrder: 40,
      ),
      PageCatalogItem(
        code: firstArticleManagementTabCode,
        name: '每日首件',
        pageType: 'tab',
        parentCode: 'quality',
        alwaysVisible: false,
        sortOrder: 41,
      ),
      PageCatalogItem(
        code: qualityScrapStatisticsTabCode,
        name: '报废统计',
        pageType: 'tab',
        parentCode: 'quality',
        alwaysVisible: false,
        sortOrder: 42,
      ),
      PageCatalogItem(
        code: qualityRepairOrdersTabCode,
        name: '维修订单',
        pageType: 'tab',
        parentCode: 'quality',
        alwaysVisible: false,
        sortOrder: 43,
      ),
      PageCatalogItem(
        code: 'craft',
        name: '工艺',
        pageType: 'sidebar',
        parentCode: null,
        alwaysVisible: false,
        sortOrder: 50,
      ),
      PageCatalogItem(
        code: processManagementTabCode,
        name: '工序管理',
        pageType: 'tab',
        parentCode: 'craft',
        alwaysVisible: false,
        sortOrder: 51,
      ),
      PageCatalogItem(
        code: 'message',
        name: '消息',
        pageType: 'sidebar',
        parentCode: null,
        alwaysVisible: false,
        sortOrder: 80,
      ),
      PageCatalogItem(
        code: 'message_center',
        name: '消息中心',
        pageType: 'tab',
        parentCode: 'message',
        alwaysVisible: false,
        sortOrder: 81,
      ),
    ];
  }
}

class _IntegrationMessageService extends MessageService {
  _IntegrationMessageService({
    required List<MessageItem> items,
    Map<int, MessageJumpResult>? jumpResults,
  }) : _items = List<MessageItem>.from(items),
       _jumpResults = jumpResults ?? <int, MessageJumpResult>{},
       super(
         AppSession(
           baseUrl: 'http://example.test/api/v1',
           accessToken: 'token',
         ),
       );

  final List<MessageItem> _items;
  final Map<int, MessageJumpResult> _jumpResults;

  @override
  Future<int> getUnreadCount() async {
    return _items.where((item) => !item.isRead).length;
  }

  @override
  Future<MessageSummaryResult> getSummary() async {
    final unreadCount = _items.where((item) => !item.isRead).length;
    return MessageSummaryResult(
      totalCount: _items.length,
      unreadCount: unreadCount,
      todoUnreadCount: unreadCount,
      urgentUnreadCount: _items
          .where((item) => !item.isRead && item.priority == 'urgent')
          .length,
    );
  }

  @override
  Future<MessageListResult> listMessages({
    int page = 1,
    int pageSize = 20,
    String? keyword,
    String? status,
    String? messageType,
    String? priority,
    String? sourceModule,
    DateTime? startTime,
    DateTime? endTime,
    bool todoOnly = false,
    bool activeOnly = true,
  }) async {
    return MessageListResult(
      items: _items,
      total: _items.length,
      page: page,
      pageSize: pageSize,
    );
  }

  @override
  Future<MessageJumpResult> getMessageJumpTarget(int messageId) async {
    return _jumpResults[messageId] ??
        const MessageJumpResult(
          canJump: false,
          disabledReason: 'missing_target',
          targetPageCode: null,
          targetTabCode: null,
          targetRoutePayloadJson: null,
        );
  }
}

class _IntegrationProductionService extends ProductionService {
  _IntegrationProductionService()
    : super(
        AppSession(baseUrl: 'http://example.test/api/v1', accessToken: 'token'),
      );

  @override
  Future<AssistAuthorizationListResult> listAssistAuthorizations({
    required int page,
    required int pageSize,
    String? status,
    DateTime? createdAtFrom,
    DateTime? createdAtTo,
    String? helperUsername,
    String? orderCode,
    String? processName,
    String? requesterUsername,
  }) async {
    return AssistAuthorizationListResult(
      total: 1,
      items: [
        AssistAuthorizationItem(
          id: 501,
          orderId: 9001,
          orderCode: 'PO-ASSIST-501',
          orderProcessId: 3001,
          processCode: 'GX-08',
          processName: '焊接',
          targetOperatorUserId: 18,
          targetOperatorUsername: 'operator-b',
          requesterUserId: 19,
          requesterUsername: 'requester-b',
          helperUserId: 20,
          helperUsername: 'helper-b',
          status: 'approved',
          reason: '夜班代班',
          reviewRemark: '已确认',
          reviewerUserId: 1,
          reviewerUsername: 'admin',
          reviewedAt: DateTime(2026, 4, 6, 9, 10),
          firstArticleUsedAt: null,
          endProductionUsedAt: null,
          consumedAt: null,
          createdAt: DateTime(2026, 4, 6, 8, 50),
          updatedAt: DateTime(2026, 4, 6, 9, 10),
        ),
      ],
    );
  }
}

class _IntegrationProductService extends ProductService {
  _IntegrationProductService()
    : super(
        AppSession(baseUrl: 'http://example.test/api/v1', accessToken: 'token'),
      );

  @override
  Future<ProductListResult> listProducts({
    required int page,
    required int pageSize,
    String? keyword,
    String? category,
    String? lifecycleStatus,
    bool? hasEffectiveVersion,
    DateTime? updatedAfter,
    DateTime? updatedBefore,
    String? currentVersionKeyword,
    String? currentParamNameKeyword,
    String? currentParamCategoryKeyword,
  }) async {
    return ProductListResult(total: 1, items: [_product66]);
  }

  @override
  Future<ProductItem> getProduct({required int productId}) async {
    return _product66;
  }

  @override
  Future<ProductVersionListResult> listProductVersions({
    required int productId,
  }) async {
    return ProductVersionListResult(
      total: 3,
      items: [
        ProductVersionItem(
          version: 3,
          versionLabel: 'V3.0',
          lifecycleStatus: 'draft',
          action: 'copy',
          note: '待确认参数',
          effectiveAt: null,
          sourceVersion: 2,
          sourceVersionLabel: 'V2.0',
          createdByUserId: 1,
          createdByUsername: 'tester',
          createdAt: DateTime(2026, 4, 6, 9, 0),
          updatedAt: DateTime(2026, 4, 6, 9, 5),
        ),
        ProductVersionItem(
          version: 2,
          versionLabel: 'V2.0',
          lifecycleStatus: 'effective',
          action: 'activate',
          note: '当前生效',
          effectiveAt: DateTime(2026, 4, 1, 8, 0),
          sourceVersion: 1,
          sourceVersionLabel: 'V1.0',
          createdByUserId: 1,
          createdByUsername: 'tester',
          createdAt: DateTime(2026, 4, 1, 8, 0),
          updatedAt: DateTime(2026, 4, 1, 8, 10),
        ),
      ],
    );
  }
}

class _IntegrationCraftService extends CraftService {
  _IntegrationCraftService()
    : super(
        AppSession(baseUrl: 'http://example.test/api/v1', accessToken: 'token'),
      );

  @override
  Future<CraftStageListResult> listStages({
    int page = 1,
    int pageSize = 200,
    String? keyword,
    bool? enabled,
  }) async {
    return CraftStageListResult(
      total: 1,
      items: [
        CraftStageItem(
          id: 7,
          code: 'ST-07',
          name: '总装',
          sortOrder: 1,
          isEnabled: true,
          processCount: 1,
          createdAt: DateTime(2026, 4, 1, 8, 0),
          updatedAt: DateTime(2026, 4, 1, 8, 0),
        ),
      ],
    );
  }

  @override
  Future<CraftProcessListResult> listProcesses({
    int page = 1,
    int pageSize = 20,
    String? keyword,
    int? stageId,
    bool? enabled,
  }) async {
    return CraftProcessListResult(
      total: 1,
      items: [
        CraftProcessItem(
          id: 71,
          code: 'GX-71',
          name: '装配检验',
          stageId: 7,
          stageCode: 'ST-07',
          stageName: '总装',
          isEnabled: true,
          createdAt: DateTime(2026, 4, 6, 8, 0),
          updatedAt: DateTime(2026, 4, 6, 8, 0),
        ),
      ],
    );
  }
}

class _IntegrationEquipmentService extends EquipmentService {
  _IntegrationEquipmentService()
    : super(
        AppSession(baseUrl: 'http://example.test/api/v1', accessToken: 'token'),
      );

  @override
  Future<MaintenanceWorkOrderListResult> listExecutions({
    required int page,
    required int pageSize,
    String? keyword,
    String? status,
    bool? mineOnly,
    DateTime? dueDateStart,
    DateTime? dueDateEnd,
    String? stageCode,
  }) async {
    return MaintenanceWorkOrderListResult(
      total: 1,
      items: [
        MaintenanceWorkOrderItem(
          id: 4,
          planId: 14,
          equipmentId: 101,
          equipmentName: '数控冲床-01',
          sourceEquipmentCode: 'EQ-101',
          itemId: 8,
          itemName: '润滑巡检',
          sourceItemName: '润滑巡检',
          sourceExecutionProcessCode: 'GX-71',
          dueDate: DateTime(2026, 4, 6),
          status: 'pending',
          executorUserId: 1,
          executorUsername: 'tester',
          startedAt: null,
          completedAt: null,
          resultSummary: null,
          resultRemark: null,
          attachmentLink: null,
          attachmentName: null,
          createdAt: DateTime(2026, 4, 6, 8, 0),
          updatedAt: DateTime(2026, 4, 6, 8, 0),
        ),
      ],
    );
  }

  @override
  Future<MaintenanceWorkOrderDetail> getWorkOrderDetail({
    required int workOrderId,
  }) async {
    return MaintenanceWorkOrderDetail(
      id: workOrderId,
      planId: 14,
      equipmentId: 101,
      equipmentName: '数控冲床-01',
      sourceEquipmentCode: 'EQ-101',
      itemId: 8,
      itemName: '润滑巡检',
      sourceItemName: '润滑巡检',
      sourceExecutionProcessCode: 'GX-71',
      dueDate: DateTime(2026, 4, 6),
      status: 'pending',
      executorUserId: 1,
      executorUsername: 'tester',
      startedAt: null,
      completedAt: null,
      resultSummary: null,
      resultRemark: null,
      attachmentLink: null,
      attachmentName: null,
      createdAt: DateTime(2026, 4, 6, 8, 0),
      updatedAt: DateTime(2026, 4, 6, 8, 0),
      sourcePlanId: 14,
      sourcePlanCycleDays: 30,
      sourcePlanStartDate: DateTime(2026, 4, 1),
      sourcePlanSummary: '月度点检',
      sourceEquipmentName: '数控冲床-01',
      sourceItemId: 8,
      recordId: null,
    );
  }
}

class _IntegrationQualityService extends QualityService {
  _IntegrationQualityService()
    : super(
        AppSession(baseUrl: 'http://example.test/api/v1', accessToken: 'token'),
      );

  @override
  Future<FirstArticleListResult> listFirstArticles({
    DateTime? date,
    String? keyword,
    String? result,
    String? productName,
    String? processCode,
    String? operatorUsername,
    int page = 1,
    int pageSize = 20,
  }) async {
    return FirstArticleListResult(
      queryDate: DateTime(2026, 4, 6),
      verificationCode: 'FA-301',
      verificationCodeSource: 'stored',
      total: 1,
      items: [
        FirstArticleListItem(
          id: 301,
          orderId: 7001,
          orderCode: 'PO-FA-301',
          productId: 20,
          productName: '产品A',
          orderProcessId: 30,
          processCode: 'GX-01',
          processName: '装配',
          operatorUserId: 40,
          operatorUsername: 'tester',
          result: 'failed',
          verificationDate: DateTime(2026, 4, 6),
          remark: '首件异常',
          createdAt: DateTime(2026, 4, 6, 8, 0),
        ),
      ],
    );
  }

  @override
  Future<FirstArticleDetail> getFirstArticleDetail(int recordId) async {
    return _buildDetail(recordId);
  }

  @override
  Future<FirstArticleDetail> getFirstArticleDispositionDetail(
    int recordId,
  ) async {
    return _buildDetail(recordId);
  }

  @override
  Future<ScrapStatisticsListResult> getScrapStatistics({
    required int page,
    required int pageSize,
    String? keyword,
    String? productName,
    String? processCode,
    String progress = 'all',
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    return ScrapStatisticsListResult(
      total: 1,
      items: [await getScrapStatisticsDetail(scrapId: 21)],
    );
  }

  @override
  Future<ScrapStatisticsItem> getScrapStatisticsDetail({
    required int scrapId,
  }) async {
    return ScrapStatisticsItem.fromJson({
      'id': scrapId,
      'order_code': 'PO-21',
      'product_name': '产品Q',
      'process_name': '检验',
      'scrap_reason': '破损',
      'scrap_quantity': 3,
      'progress': 'pending_apply',
      'created_at': '2026-03-05T08:00:00Z',
      'updated_at': '2026-03-05T08:10:00Z',
      'related_repair_orders': [
        {
          'id': 7,
          'repair_order_code': 'RW-21',
          'status': 'completed',
          'repair_quantity': 3,
          'repaired_quantity': 2,
          'scrap_quantity': 1,
          'repair_time': '2026-03-05T09:00:00Z',
        },
      ],
    });
  }

  @override
  Future<RepairOrderListResult> getRepairOrders({
    required int page,
    required int pageSize,
    String? keyword,
    String status = 'all',
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    return RepairOrderListResult(
      total: 1,
      items: [
        RepairOrderItem.fromJson({
          'id': 7,
          'repair_order_code': 'RW-21',
          'source_order_code': 'PO-21',
          'product_name': '产品Q',
          'source_process_code': 'QA-01',
          'source_process_name': '检验',
          'production_quantity': 10,
          'repair_quantity': 3,
          'repaired_quantity': 2,
          'scrap_quantity': 1,
          'scrap_replenished': false,
          'repair_time': '2026-03-05T09:00:00Z',
          'status': 'completed',
          'created_at': '2026-03-05T09:00:00Z',
          'updated_at': '2026-03-05T10:00:00Z',
        }),
      ],
    );
  }

  @override
  Future<RepairOrderDetailItem> getRepairOrderDetail({
    required int repairOrderId,
  }) async {
    return RepairOrderDetailItem.fromJson({
      'id': repairOrderId,
      'repair_order_code': 'RW-21',
      'source_order_code': 'PO-21',
      'product_name': '产品Q',
      'source_process_code': 'QA-01',
      'source_process_name': '检验',
      'production_quantity': 10,
      'repair_quantity': 3,
      'repaired_quantity': 2,
      'scrap_quantity': 1,
      'scrap_replenished': false,
      'repair_time': '2026-03-05T09:00:00Z',
      'status': 'completed',
      'created_at': '2026-03-05T09:00:00Z',
      'updated_at': '2026-03-05T10:00:00Z',
      'defect_rows': [
        {
          'id': 1,
          'phenomenon': '虚焊',
          'quantity': 3,
          'production_record_id': 31,
          'production_record_type': 'production',
          'production_record_quantity': 10,
          'production_record_created_at': '2026-03-05T08:50:00Z',
        },
      ],
      'cause_rows': [
        {
          'id': 1,
          'phenomenon': '虚焊',
          'reason': '治具偏移',
          'quantity': 2,
          'is_scrap': false,
        },
      ],
      'return_routes': [
        {
          'id': 1,
          'target_process_code': 'QA-00',
          'target_process_name': '返修前段',
          'return_quantity': 2,
        },
      ],
    });
  }

  FirstArticleDetail _buildDetail(int recordId) {
    return FirstArticleDetail(
      id: recordId,
      verificationCode: 'FA-$recordId',
      productionOrderId: 7001,
      productionOrderCode: 'PO-FA-$recordId',
      productId: 20,
      productCode: 'P-001',
      productName: '产品A',
      processId: 30,
      processName: '装配',
      operatorUserId: 40,
      operatorUsername: 'tester',
      checkResult: 'failed',
      defectDescription: '尺寸偏差',
      checkAt: DateTime(2026, 4, 6, 8, 0),
      templateId: 501,
      templateName: '默认首件模板',
      checkContent: '外观、尺寸、装配确认',
      testValue: '9.86',
      participants: const [
        FirstArticleParticipantItem(
          userId: 41,
          username: 'helper_a',
          fullName: '张三',
        ),
      ],
      disposition: const FirstArticleDispositionInfo(
        dispositionOpinion: '已复核',
        dispositionUsername: 'quality',
        dispositionAt: null,
        recheckResult: 'passed',
        finalJudgment: 'accept',
      ),
      dispositionHistory: const [],
    );
  }
}

class _IntegrationUserService extends UserService {
  _IntegrationUserService()
    : super(
        AppSession(baseUrl: 'http://example.test/api/v1', accessToken: 'token'),
      );

  @override
  Future<ProfileResult> getMyProfile() async {
    return ProfileResult(
      id: 1,
      username: 'tester',
      fullName: '测试用户',
      roleCode: 'user_admin',
      roleName: '系统管理员',
      stageId: null,
      stageName: null,
      isActive: true,
      createdAt: DateTime(2026, 1, 1, 8),
      lastLoginAt: DateTime(2026, 4, 6, 8, 50),
      lastLoginIp: '127.0.0.1',
      passwordChangedAt: DateTime(2026, 3, 21, 9),
    );
  }

  @override
  Future<CurrentSessionResult> getMySession() async {
    return CurrentSessionResult(
      sessionTokenId: 'session-token-1',
      loginTime: DateTime(2026, 4, 6, 8, 50),
      lastActiveAt: DateTime(2026, 4, 6, 9, 0),
      expiresAt: DateTime(2026, 4, 6, 17, 0),
      status: 'active',
      remainingSeconds: 3600,
    );
  }

  @override
  Future<void> changeMyPassword({
    required String oldPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {}
}

final ProductItem _product66 = ProductItem(
  id: 66,
  name: '产品66',
  category: '标准件',
  remark: '消息跳转联调',
  lifecycleStatus: 'active',
  currentVersion: 3,
  currentVersionLabel: 'V3.0',
  effectiveVersion: 2,
  effectiveVersionLabel: 'V2.0',
  effectiveAt: DateTime(2026, 4, 1, 8, 0),
  inactiveReason: null,
  lastParameterSummary: '参数已更新',
  createdAt: DateTime(2026, 3, 1, 8, 0),
  updatedAt: DateTime(2026, 4, 6, 9, 0),
);

class _IntegrationMessageWsService extends MessageWsService {
  _IntegrationMessageWsService({
    required super.baseUrl,
    required super.accessToken,
    required super.onEvent,
    required super.onDisconnected,
  });

  @override
  void connect() {
    onEvent(const WsEvent(event: 'connected', userId: 1, unreadCount: 0));
  }

  @override
  void disconnect() {}

  @override
  void reconnect() {}
}
