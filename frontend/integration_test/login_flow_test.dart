import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mes_client/models/app_session.dart';
import 'package:mes_client/models/authz_models.dart';
import 'package:mes_client/models/craft_models.dart';
import 'package:mes_client/models/equipment_models.dart';
import 'package:mes_client/models/message_models.dart';
import 'package:mes_client/models/product_models.dart';
import 'package:mes_client/models/production_models.dart';
import 'package:mes_client/models/quality_models.dart';
import 'package:mes_client/models/user_models.dart';
import 'package:mes_client/pages/account_settings_page.dart';
import 'package:mes_client/pages/audit_log_page.dart';
import 'package:mes_client/pages/craft_kanban_page.dart';
import 'package:mes_client/pages/craft_page.dart';
import 'package:mes_client/pages/craft_reference_analysis_page.dart';
import 'package:mes_client/pages/equipment_page.dart';
import 'package:mes_client/pages/equipment_rule_parameter_page.dart';
import 'package:mes_client/pages/force_change_password_page.dart';
import 'package:mes_client/pages/function_permission_config_page.dart';
import 'package:mes_client/pages/login_page.dart';
import 'package:mes_client/pages/login_session_page.dart';
import 'package:mes_client/pages/message_center_page.dart';
import 'package:mes_client/pages/maintenance_execution_page.dart';
import 'package:mes_client/pages/process_configuration_page.dart';
import 'package:mes_client/pages/process_management_page.dart';
import 'package:mes_client/pages/production_order_query_page.dart';
import 'package:mes_client/pages/production_page.dart';
import 'package:mes_client/pages/quality_page.dart';
import 'package:mes_client/pages/product_parameter_query_page.dart';
import 'package:mes_client/pages/product_page.dart';
import 'package:mes_client/pages/role_management_page.dart';
import 'package:mes_client/pages/user_page.dart';
import 'package:mes_client/services/api_exception.dart';
import 'package:mes_client/services/auth_service.dart';
import 'package:mes_client/services/authz_service.dart';
import 'package:mes_client/services/craft_service.dart';
import 'package:mes_client/services/equipment_service.dart';
import 'package:mes_client/services/message_service.dart';
import 'package:mes_client/services/product_service.dart';
import 'package:mes_client/services/production_service.dart';
import 'package:mes_client/services/quality_service.dart';
import 'package:mes_client/services/quality_supplier_service.dart';
import 'package:mes_client/services/user_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('登录成功后进入后续页面', (tester) async {
    final authService = _FakeAuthService();

    await _pumpTestApp(
      tester,
      authService: authService,
      userService: _FakeUserService(),
    );

    await tester.enterText(
      find.byKey(const Key('login-account-field')),
      'tester',
    );
    await tester.enterText(
      find.byKey(const Key('login-password-field')),
      'Pass123',
    );
    await tester.tap(find.byKey(const Key('login-submit-button')));
    await tester.pumpAndSettle();

    expect(find.text('已进入首页'), findsOneWidget);
    expect(authService.lastUsername, 'tester');
    expect(authService.lastPassword, 'Pass123');
  });

  testWidgets('登录后进入消息中心并完成详情查看、单条已读与跳转到账户设置', (tester) async {
    final authService = _FakeAuthService();
    final userService = _FakeUserService();
    final messageService = _FakeIntegrationMessageService();

    await _pumpTestApp(
      tester,
      authService: authService,
      userService: userService,
      homeBuilder: (session) {
        return _MessageCenterIntegrationHost(
          session: session,
          userService: userService,
          messageService: messageService,
        );
      },
    );

    await tester.enterText(
      find.byKey(const Key('login-account-field')),
      'tester',
    );
    await tester.enterText(
      find.byKey(const Key('login-password-field')),
      'Pass123',
    );
    await tester.pump();
    await _tapAndSettle(tester, find.byKey(const Key('login-submit-button')));

    expect(find.text('消息中心'), findsOneWidget);
    expect(find.text('未读消息'), findsOneWidget);

    await _tapAndSettle(
      tester,
      find.byKey(const ValueKey('message-center-tile-301')),
    );
    expect(find.text('请立即完成密码更新'), findsWidgets);

    await _tapAndSettle(
      tester,
      find.byKey(const ValueKey('message-center-preview-detail-301')),
    );
    expect(find.text('消息详情'), findsOneWidget);
    expect(find.text('账号已创建，请及时修改初始密码。'), findsWidgets);
    await _tapAndSettle(tester, find.text('关闭'));

    await _tapAndSettle(
      tester,
      find.byKey(const ValueKey('message-center-preview-read-301')),
    );
    expect(messageService.markReadCalls, 1);
    expect(find.text('未读消息'), findsOneWidget);
    expect(find.text('0'), findsWidgets);

    await _tapAndSettle(
      tester,
      find.byKey(const ValueKey('message-center-preview-jump-301')),
    );
    expect(find.text('修改密码'), findsWidgets);
    expect(
      find.byKey(const ValueKey('account-settings-change-password-anchor')),
      findsOneWidget,
    );
  });

  testWidgets('登录后进入产品总页并完成关键页签切换与查看动作', (tester) async {
    final authService = _FakeAuthService();
    final productService = _FakeIntegrationProductService();

    await _pumpTestApp(
      tester,
      authService: authService,
      userService: _FakeUserService(),
      homeBuilder: (session) {
        return Scaffold(
          body: ProductPage(
            session: session,
            onLogout: () {},
            visibleTabCodes: const [
              productVersionManagementTabCode,
              productParameterQueryTabCode,
            ],
            capabilityCodes: const <String>{},
            preferredTabCode: productVersionManagementTabCode,
            routePayloadJson:
                '{"target_tab_code":"product_parameter_query","action":"view","product_id":101,"product_name":"产品101"}',
            productVersionService: productService,
            tabChildBuilder: (tabCode) => Center(child: Text('tab:$tabCode')),
            tabPageBuilder: (tabCode, child) {
              if (tabCode == productParameterQueryTabCode) {
                return ProductParameterQueryPage(
                  session: session,
                  onLogout: () {},
                  tabCode: productParameterQueryTabCode,
                  jumpCommand: child is ProductParameterQueryPage
                      ? child.jumpCommand
                      : null,
                  onJumpHandled: child is ProductParameterQueryPage
                      ? child.onJumpHandled
                      : null,
                  service: productService,
                  canExportParameters: true,
                );
              }
              return Center(child: Text('tab:$tabCode'));
            },
          ),
        );
      },
    );

    await tester.enterText(
      find.byKey(const Key('login-account-field')),
      'tester',
    );
    await tester.enterText(
      find.byKey(const Key('login-password-field')),
      'Pass123',
    );
    await tester.tap(find.byKey(const Key('login-submit-button')));
    await tester.pumpAndSettle();

    expect(find.text('产品参数查询'), findsWidgets);
    expect(find.textContaining('产品参数 - 产品101'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, '关闭'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('版本管理'));
    await tester.pumpAndSettle();
    expect(find.text('tab:$productVersionManagementTabCode'), findsOneWidget);

    await tester.tap(find.text('产品参数查询'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextButton, '查看参数'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, '查看参数'));
    await tester.pumpAndSettle();
    expect(productService.parameterDetailCalls, 2);
  });

  testWidgets('登录后进入用户总页并切换多个页签完成权限保存', (tester) async {
    final authService = _FakeAuthService();
    final userService = _FakeUserService();
    final authzService = _FakeIntegrationAuthzService();

    await _pumpTestApp(
      tester,
      authService: authService,
      userService: userService,
      homeBuilder: (session) {
        return Scaffold(
          body: UserPage(
            session: session,
            onLogout: () {},
            visibleTabCodes: const [
              'role_management',
              'audit_log',
              'login_session',
              'function_permission_config',
            ],
            capabilityCodes: const {
              UserFeaturePermissionCodes.roleManagementCreate,
              UserFeaturePermissionCodes.roleManagementUpdate,
              UserFeaturePermissionCodes.roleManagementLifecycle,
              UserFeaturePermissionCodes.roleManagementDelete,
              UserFeaturePermissionCodes.loginSessionOnlineView,
              UserFeaturePermissionCodes.loginSessionForceOffline,
            },
            preferredTabCode: 'role_management',
            tabPageBuilder: (tabCode, child) {
              if (child is RoleManagementPage) {
                return RoleManagementPage(
                  session: child.session,
                  onLogout: child.onLogout,
                  canCreateRole: child.canCreateRole,
                  canEditRole: child.canEditRole,
                  canToggleRole: child.canToggleRole,
                  canDeleteRole: child.canDeleteRole,
                  userService: userService,
                );
              }
              if (child is LoginSessionPage) {
                return LoginSessionPage(
                  session: child.session,
                  onLogout: child.onLogout,
                  canViewOnlineSessions: child.canViewOnlineSessions,
                  canForceOffline: child.canForceOffline,
                  userService: userService,
                );
              }
              if (child is AuditLogPage) {
                return AuditLogPage(
                  session: child.session,
                  onLogout: child.onLogout,
                  userService: userService,
                );
              }
              if (child is FunctionPermissionConfigPage) {
                return FunctionPermissionConfigPage(
                  session: child.session,
                  onLogout: child.onLogout,
                  onPermissionsChanged: child.onPermissionsChanged,
                  authzService: authzService,
                  userService: userService,
                );
              }
              if (child is AccountSettingsPage) {
                return const SizedBox.shrink();
              }
              return Center(child: Text('tab:$tabCode'));
            },
          ),
        );
      },
    );

    await tester.enterText(
      find.byKey(const Key('login-account-field')),
      'tester',
    );
    await tester.enterText(
      find.byKey(const Key('login-password-field')),
      'Pass123',
    );
    await tester.tap(find.byKey(const Key('login-submit-button')));
    await tester.pumpAndSettle();

    expect(find.text('维修员'), findsOneWidget);

    await tester.tap(find.text('登录会话'));
    await tester.pumpAndSettle();
    expect(find.text('tester'), findsOneWidget);

    await tester.tap(find.text('审计日志'));
    await tester.pumpAndSettle();
    expect(find.text('停用用户'), findsOneWidget);

    await tester.tap(find.text('功能权限配置'));
    await tester.pumpAndSettle();
    expect(find.byType(FunctionPermissionConfigPage), findsOneWidget);

    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '确认保存'));
    await tester.pumpAndSettle();

    expect(authzService.applyCapabilityPacksCalls, 1);
    expect(find.text('保存成功。'), findsOneWidget);
    expect(authService.lastUsername, 'tester');
  });

  testWidgets('登录后进入工艺总页并切换关键页签完成关键动作', (tester) async {
    final authService = _FakeAuthService();
    final craftService = _FakeIntegrationCraftService();
    final productionService = _FakeIntegrationProductionService();

    await _pumpTestApp(
      tester,
      authService: authService,
      userService: _FakeUserService(),
      homeBuilder: (session) {
        return Scaffold(
          body: CraftPage(
            session: session,
            onLogout: () {},
            visibleTabCodes: const [
              processManagementTabCode,
              productionProcessConfigTabCode,
              craftKanbanTabCode,
              craftReferenceAnalysisTabCode,
            ],
            capabilityCodes: const {
              CraftFeaturePermissionCodes.processBasicsManage,
              CraftFeaturePermissionCodes.processTemplatesManage,
              CraftFeaturePermissionCodes.processTemplatesView,
            },
            preferredTabCode: craftKanbanTabCode,
            routePayloadJson:
                '{"target_tab_code":"process_management","process_id":"11"}',
            tabPageBuilder: (tabCode, child) {
              if (child is ProcessManagementPage) {
                return ProcessManagementPage(
                  session: child.session,
                  onLogout: child.onLogout,
                  canWrite: child.canWrite,
                  craftService: craftService,
                  processId: child.processId,
                  jumpRequestId: child.jumpRequestId,
                );
              }
              if (child is CraftKanbanPage) {
                return CraftKanbanPage(
                  session: child.session,
                  onLogout: child.onLogout,
                  craftService: craftService,
                  productionService: productionService,
                );
              }
              if (child is CraftReferenceAnalysisPage) {
                return CraftReferenceAnalysisPage(
                  session: child.session,
                  onLogout: child.onLogout,
                  craftService: craftService,
                  onNavigate: child.onNavigate,
                );
              }
              if (child is ProcessConfigurationPage) {
                return Center(
                  child: Text(
                    '配置跳转:${child.templateId}:${child.version}:${child.systemMasterVersions}:${child.jumpRequestId}',
                  ),
                );
              }
              return child;
            },
          ),
        );
      },
    );

    await tester.enterText(
      find.byKey(const Key('login-account-field')),
      'tester',
    );
    await tester.enterText(
      find.byKey(const Key('login-password-field')),
      'Pass123',
    );
    await tester.tap(find.byKey(const Key('login-submit-button')));
    await tester.pumpAndSettle();

    expect(find.textContaining('已定位工序 #11 激光切割'), findsOneWidget);

    await tester.tap(find.text('工艺看板'));
    await tester.pumpAndSettle();
    expect(find.text('工序趋势对比（平均工时/产能）'), findsOneWidget);

    await tester.tap(find.text('导出数据'));
    await tester.pumpAndSettle();
    expect(craftService.lastExportLimit, 100);
    await tester.tap(find.widgetWithText(TextButton, '关闭'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('引用分析'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('按产品'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('产品A'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('按产品查询：产品A'), findsOneWidget);
    await tester.tap(find.text('模板A (published)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('跳转工艺模块'));
    await tester.pumpAndSettle();

    expect(find.text('配置跳转:22:null:false:1'), findsOneWidget);
    expect(authService.lastUsername, 'tester');
  });

  testWidgets('登录后进入生产总页并切换关键页签完成详情链路', (tester) async {
    final authService = _FakeAuthService();
    final productionService = _FakeIntegrationProductionPageService();

    await _pumpTestApp(
      tester,
      authService: authService,
      userService: _FakeUserService(),
      homeBuilder: (session) {
        return Scaffold(
          body: ProductionPage(
            session: session,
            onLogout: () {},
            visibleTabCodes: const [
              productionOrderManagementTabCode,
              productionOrderQueryTabCode,
              productionAssistRecordsTabCode,
            ],
            capabilityCodes: const {
              ProductionFeaturePermissionCodes.orderQueryExecute,
              ProductionFeaturePermissionCodes.repairOrdersCreateManual,
              ProductionFeaturePermissionCodes.assistLaunch,
            },
            preferredTabCode: productionOrderQueryTabCode,
            tabChildBuilder: (tabCode) => Center(child: Text('tab:$tabCode')),
            tabPageBuilder: (tabCode, child) {
              if (child is ProductionOrderQueryPage) {
                return ProductionOrderQueryPage(
                  session: child.session,
                  onLogout: child.onLogout,
                  canFirstArticle: child.canFirstArticle,
                  canEndProduction: child.canEndProduction,
                  canCreateManualRepairOrder: child.canCreateManualRepairOrder,
                  canCreateAssistAuthorization:
                      child.canCreateAssistAuthorization,
                  canProxyView: child.canProxyView,
                  canExportCsv: child.canExportCsv,
                  service: productionService,
                  pollInterval: Duration.zero,
                );
              }
              return Center(child: Text('tab:$tabCode'));
            },
          ),
        );
      },
    );

    await tester.enterText(
      find.byKey(const Key('login-account-field')),
      'tester',
    );
    await tester.enterText(
      find.byKey(const Key('login-password-field')),
      'Pass123',
    );
    await tester.tap(find.byKey(const Key('login-submit-button')));
    await tester.pumpAndSettle();

    expect(find.text('生产订单查询'), findsOneWidget);

    await tester.tap(find.text('订单管理'));
    await tester.pumpAndSettle();
    expect(find.text('tab:$productionOrderManagementTabCode'), findsOneWidget);

    await tester.tap(find.text('订单查询'));
    await tester.pumpAndSettle();
    expect(find.text('PO-INTEGRATION-001'), findsOneWidget);

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('历史').last);
    await tester.pumpAndSettle();

    expect(find.text('创建订单'), findsOneWidget);
    expect(productionService.orderDetailCalls, 1);
    expect(authService.lastUsername, 'tester');
  });

  testWidgets('登录后进入质量总页并切换页签完成供应商管理链路', (tester) async {
    final authService = _FakeAuthService();
    final firstArticleService = _FakeIntegrationQualityService();
    final supplierService = _FakeIntegrationQualitySupplierService([
      QualitySupplierItem(
        id: 1,
        name: '初始供应商',
        remark: '初始备注',
        isEnabled: true,
        createdAt: DateTime.parse('2026-03-01T00:00:00Z'),
        updatedAt: DateTime.parse('2026-03-01T00:00:00Z'),
      ),
    ]);

    await _pumpTestApp(
      tester,
      authService: authService,
      userService: _FakeUserService(),
      homeBuilder: (session) {
        return QualityPage(
          session: session,
          onLogout: () {},
          visibleTabCodes: const [
            firstArticleManagementTabCode,
            qualitySupplierManagementTabCode,
          ],
          capabilityCodes: const {
            'quality.first_articles.detail',
            'quality.first_articles.disposition',
          },
          preferredTabCode: qualitySupplierManagementTabCode,
          firstArticleService: firstArticleService,
          supplierService: supplierService,
        );
      },
    );

    await tester.enterText(
      find.byKey(const Key('login-account-field')),
      'tester',
    );
    await tester.enterText(
      find.byKey(const Key('login-password-field')),
      'Pass123',
    );
    await tester.tap(find.byKey(const Key('login-submit-button')));
    await tester.pumpAndSettle();

    expect(find.text('初始供应商'), findsOneWidget);

    await tester.tap(find.text('每日首件'));
    await tester.pumpAndSettle();
    expect(find.text('PO-001'), findsOneWidget);
    expect(find.text('详情'), findsOneWidget);

    await tester.tap(find.text('供应商管理'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('新增供应商'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, '名称'), '集成供应商B');
    await tester.enterText(find.widgetWithText(TextFormField, '备注'), '集成新增备注');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(supplierService.createCalls, 1);
    expect(find.text('集成供应商B'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, '编辑').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, '名称'), '集成供应商B2');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(supplierService.updateCalls, 1);
    expect(find.text('集成供应商B2'), findsOneWidget);
    expect(authService.lastUsername, 'tester');
  });

  testWidgets('登录后进入设备总页并完成详情链路与规则参数关键动作', (tester) async {
    final authService = _FakeAuthService();
    final equipmentService = _FakeIntegrationEquipmentService();
    final craftService = _FakeIntegrationCraftService();

    await _pumpTestApp(
      tester,
      authService: authService,
      userService: _FakeUserService(),
      homeBuilder: (session) {
        return EquipmentPage(
          session: session,
          onLogout: () {},
          visibleTabCodes: const [
            equipmentLedgerTabCode,
            maintenanceExecutionTabCode,
            equipmentRuleParameterTabCode,
          ],
          capabilityCodes: const {
            EquipmentFeaturePermissionCodes.executionsOperate,
            EquipmentFeaturePermissionCodes.rulesView,
            EquipmentFeaturePermissionCodes.rulesManage,
            EquipmentFeaturePermissionCodes.runtimeParametersView,
            EquipmentFeaturePermissionCodes.runtimeParametersManage,
          },
          preferredTabCode: maintenanceExecutionTabCode,
          routePayloadJson: '{"action":"detail","work_order_id":4}',
          tabPageBuilder: (tabCode, child) {
            if (child is MaintenanceExecutionPage) {
              return MaintenanceExecutionPage(
                session: child.session,
                onLogout: child.onLogout,
                canExecute: child.canExecute,
                jumpPayloadJson: child.jumpPayloadJson,
                equipmentService: equipmentService,
                craftService: craftService,
              );
            }
            if (child is EquipmentRuleParameterPage) {
              return EquipmentRuleParameterPage(
                session: child.session,
                onLogout: child.onLogout,
                canViewRules: child.canViewRules,
                canManageRules: child.canManageRules,
                canViewParameters: child.canViewParameters,
                canManageParameters: child.canManageParameters,
                service: equipmentService,
              );
            }
            return child;
          },
        );
      },
    );

    await tester.enterText(
      find.byKey(const Key('login-account-field')),
      'tester',
    );
    await tester.enterText(
      find.byKey(const Key('login-password-field')),
      'Pass123',
    );
    await tester.tap(find.byKey(const Key('login-submit-button')));
    await tester.pumpAndSettle();

    expect(find.text('保养执行详情 #4'), findsOneWidget);
    expect(equipmentService.detailCalls, 1);

    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(Tab, '规则与参数'));
    await tester.pumpAndSettle();
    expect(find.text('压力规则'), findsOneWidget);

    await tester.tap(
      find.byKey(const Key('equipment-rule-open-parameters-11')),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('当前按规则作用范围查看参数'), findsOneWidget);
    expect(find.text('压力'), findsOneWidget);

    expect(authService.lastUsername, 'tester');
  });

  testWidgets('登录失败时显示错误消息', (tester) async {
    final authService = _FakeAuthService()
      ..loginError = ApiException('账号或密码错误', 401);

    await _pumpTestApp(
      tester,
      authService: authService,
      userService: _FakeUserService(),
    );

    await tester.enterText(
      find.byKey(const Key('login-account-field')),
      'tester',
    );
    await tester.enterText(
      find.byKey(const Key('login-password-field')),
      'wrongpass',
    );
    await tester.tap(find.byKey(const Key('login-submit-button')));
    await tester.pumpAndSettle();

    expect(find.text('登录失败：账号或密码错误'), findsOneWidget);
  });

  testWidgets('mustChangePassword 分流后可回到登录页', (tester) async {
    final authService = _FakeAuthService()..mustChangePassword = true;
    final userService = _FakeUserService();

    await _pumpTestApp(
      tester,
      authService: authService,
      userService: userService,
    );

    await tester.enterText(
      find.byKey(const Key('login-account-field')),
      'tester',
    );
    await tester.enterText(
      find.byKey(const Key('login-password-field')),
      'Init123',
    );
    await tester.tap(find.byKey(const Key('login-submit-button')));
    await tester.pumpAndSettle();

    expect(find.text('首次登录，请修改密码'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('force-old-password-field')),
      'Init123',
    );
    await tester.enterText(
      find.byKey(const Key('force-new-password-field')),
      'NewPass123',
    );
    await tester.enterText(
      find.byKey(const Key('force-confirm-password-field')),
      'NewPass123',
    );
    await tester.tap(find.byKey(const Key('force-submit-button')));
    await tester.pumpAndSettle();

    expect(find.text('密码已修改，请使用新密码重新登录。'), findsOneWidget);
    expect(userService.changePasswordCalls, 1);
  });

  testWidgets('去注册后返回登录页并显示提交提示', (tester) async {
    final authService = _FakeAuthService();

    await _pumpTestApp(
      tester,
      authService: authService,
      userService: _FakeUserService(),
    );

    await tester.tap(find.byKey(const Key('go-register-button')));
    await tester.pumpAndSettle();

    expect(find.text('注册申请'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('register-account-field')),
      'new_user',
    );
    await tester.enterText(
      find.byKey(const Key('register-password-field')),
      'Pass123',
    );
    await tester.enterText(
      find.byKey(const Key('register-confirm-password-field')),
      'Pass123',
    );
    await tester.tap(find.byKey(const Key('register-submit-button')));
    await tester.pumpAndSettle();

    expect(find.text('注册申请已提交，请等待系统管理员审批后再登录。'), findsOneWidget);
    expect(authService.registerCalls, 1);
    expect(authService.registeredAccounts, contains('new_user'));
    expect(
      tester
          .widget<TextFormField>(find.byKey(const Key('login-account-field')))
          .controller!
          .text,
      'new_user',
    );
  });
}

Future<void> _pumpTestApp(
  WidgetTester tester, {
  required _FakeAuthService authService,
  required _FakeUserService userService,
  Widget Function(AppSession session)? homeBuilder,
}) async {
  tester.view.physicalSize = const Size(1440, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await tester.pumpWidget(
    MaterialApp(
      home: _IntegrationTestApp(
        authService: authService,
        userService: userService,
        homeBuilder: homeBuilder,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _tapAndSettle(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder.hitTestable());
  await tester.pumpAndSettle();
}

class _IntegrationTestApp extends StatefulWidget {
  const _IntegrationTestApp({
    required this.authService,
    required this.userService,
    this.homeBuilder,
  });

  final _FakeAuthService authService;
  final _FakeUserService userService;
  final Widget Function(AppSession session)? homeBuilder;

  @override
  State<_IntegrationTestApp> createState() => _IntegrationTestAppState();
}

class _IntegrationTestAppState extends State<_IntegrationTestApp> {
  AppSession? _session;
  String? _loginNotice;

  void _handleLoginSuccess(AppSession session) {
    setState(() {
      _session = session;
      _loginNotice = null;
    });
  }

  void _handleRequireRelogin() {
    setState(() {
      _session = null;
      _loginNotice = '密码已修改，请使用新密码重新登录。';
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_session == null) {
      return LoginPage(
        defaultBaseUrl: 'http://example.test/api/v1',
        authService: widget.authService,
        initialMessage: _loginNotice,
        onLoginSuccess: _handleLoginSuccess,
      );
    }

    if (_session!.mustChangePassword) {
      return ForceChangePasswordPage(
        session: _session!,
        userService: widget.userService,
        onRequireRelogin: _handleRequireRelogin,
      );
    }

    final homeBuilder = widget.homeBuilder;
    if (homeBuilder != null) {
      return Scaffold(body: homeBuilder(_session!));
    }

    return const Scaffold(body: Center(child: Text('已进入首页')));
  }
}

class _FakeIntegrationProductService extends ProductService {
  _FakeIntegrationProductService()
    : super(
        AppSession(baseUrl: 'http://example.test/api/v1', accessToken: 'token'),
      );

  int parameterDetailCalls = 0;

  @override
  Future<ProductListResult> listProductsForParameterQuery({
    required int page,
    required int pageSize,
    String? keyword,
    String? category,
    String? lifecycleStatus,
    bool? hasEffectiveVersion,
    String? effectiveVersionKeyword,
  }) async {
    return ProductListResult(
      total: 1,
      items: [
        ProductItem(
          id: 101,
          name: '产品101',
          category: '贴片',
          remark: '',
          lifecycleStatus: 'active',
          currentVersion: 2,
          currentVersionLabel: 'V1.1',
          effectiveVersion: 1,
          effectiveVersionLabel: 'V1.0',
          effectiveAt: DateTime.parse('2026-03-01T00:00:00Z'),
          inactiveReason: null,
          lastParameterSummary: null,
          createdAt: DateTime.parse('2026-03-01T00:00:00Z'),
          updatedAt: DateTime.parse('2026-03-01T00:00:00Z'),
        ),
      ],
    );
  }

  @override
  Future<ProductParameterListResult> listProductParameters({
    required int productId,
    int? version,
    bool effectiveOnly = false,
  }) async {
    parameterDetailCalls += 1;
    return ProductParameterListResult(
      productId: productId,
      productName: '产品101',
      parameterScope: 'effective',
      version: 1,
      versionLabel: 'V1.0',
      lifecycleStatus: 'effective',
      total: 1,
      items: [
        ProductParameterItem(
          name: '产品芯片',
          category: '基础参数',
          type: 'Text',
          value: 'CHIP-X',
          description: '',
          sortOrder: 1,
          isPreset: false,
        ),
      ],
    );
  }
}

class _FakeIntegrationCraftService extends CraftService {
  _FakeIntegrationCraftService()
    : super(
        AppSession(baseUrl: 'http://example.test/api/v1', accessToken: 'token'),
      );

  int? lastExportLimit;

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
          id: 1,
          code: 'CUT',
          name: '切割段',
          sortOrder: 1,
          isEnabled: true,
          processCount: 1,
          createdAt: DateTime.parse('2026-03-01T00:00:00Z'),
          updatedAt: DateTime.parse('2026-03-01T00:00:00Z'),
        ),
      ],
    );
  }

  @override
  Future<CraftProcessListResult> listProcesses({
    int page = 1,
    int pageSize = 500,
    String? keyword,
    int? stageId,
    bool? enabled,
  }) async {
    return CraftProcessListResult(
      total: 1,
      items: [
        CraftProcessItem(
          id: 11,
          code: 'CUT-01',
          name: '激光切割',
          stageId: 1,
          stageCode: 'CUT',
          stageName: '切割段',
          isEnabled: true,
          createdAt: DateTime.parse('2026-03-01T00:00:00Z'),
          updatedAt: DateTime.parse('2026-03-01T00:00:00Z'),
        ),
      ],
    );
  }

  @override
  Future<CraftTemplateListResult> listTemplates({
    int page = 1,
    int pageSize = 500,
    int? productId,
    String? keyword,
    String? productCategory,
    bool? isDefault,
    bool? enabled = true,
    String? lifecycleStatus,
    DateTime? updatedFrom,
    DateTime? updatedTo,
  }) async {
    return CraftTemplateListResult(
      total: 1,
      items: [
        CraftTemplateItem(
          id: 21,
          productId: 5,
          productName: '产品A',
          templateName: '模板A',
          version: 2,
          lifecycleStatus: 'published',
          publishedVersion: 2,
          isDefault: true,
          isEnabled: true,
          createdByUserId: 1,
          createdByUsername: 'planner',
          updatedByUserId: 1,
          updatedByUsername: 'planner',
          createdAt: DateTime.parse('2026-03-01T00:00:00Z'),
          updatedAt: DateTime.parse('2026-03-01T00:00:00Z'),
        ),
      ],
    );
  }

  @override
  Future<CraftKanbanProcessMetricsResult> getCraftKanbanProcessMetrics({
    required int productId,
    int limit = 5,
    int? stageId,
    int? processId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    return CraftKanbanProcessMetricsResult(
      productId: productId,
      productName: '产品A',
      items: [
        CraftKanbanProcessItem(
          stageId: 1,
          stageCode: 'CUT',
          stageName: '切割段',
          processId: 11,
          processCode: 'CUT-01',
          processName: '激光切割',
          samples: [
            CraftKanbanSampleItem(
              orderProcessId: 101,
              orderId: 1001,
              orderCode: 'MO-1001',
              startAt: DateTime.parse('2026-03-01T08:00:00Z'),
              endAt: DateTime.parse('2026-03-01T09:00:00Z'),
              workMinutes: 60,
              productionQty: 120,
              capacityPerHour: 120,
            ),
          ],
        ),
      ],
    );
  }

  @override
  Future<String> exportCraftKanbanProcessMetrics({
    required int productId,
    int limit = 5,
    int? stageId,
    int? processId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    lastExportLimit = limit;
    return '';
  }

  @override
  Future<CraftProcessReferenceResult> getProcessReferences({
    required int processId,
  }) async {
    return CraftProcessReferenceResult(
      processId: processId,
      processCode: 'CUT-01',
      processName: '激光切割',
      total: 1,
      items: [
        CraftReferenceItem(
          refType: 'template',
          refId: 21,
          refCode: 'TPL-21',
          refName: '切割模板',
          detail: 'published',
        ),
      ],
    );
  }

  @override
  Future<CraftProductTemplateReferenceResult> getProductTemplateReferences({
    required int productId,
  }) async {
    return CraftProductTemplateReferenceResult(
      productId: productId,
      productName: '产品A',
      totalTemplates: 1,
      totalReferences: 1,
      items: [
        CraftProductTemplateReferenceRow(
          templateId: 21,
          templateName: '模板A',
          lifecycleStatus: 'published',
          refType: 'template_reuse',
          refId: 22,
          refCode: 'TMP-22',
          refName: '模板B',
          detail: '复用到 产品B · published',
          refStatus: '正在使用',
          jumpModule: 'craft',
          jumpTarget: 'process-configuration?template_id=22',
          riskLevel: 'medium',
          riskNote: '需同步模板版本',
        ),
      ],
    );
  }
}

class _FakeIntegrationProductionService extends ProductionService {
  _FakeIntegrationProductionService()
    : super(
        AppSession(baseUrl: 'http://example.test/api/v1', accessToken: 'token'),
      );

  @override
  Future<List<ProductionProductOption>> listProductOptions() async {
    return [ProductionProductOption(id: 5, name: '产品A')];
  }
}

class _FakeIntegrationProductionPageService extends ProductionService {
  _FakeIntegrationProductionPageService()
    : super(
        AppSession(baseUrl: 'http://example.test/api/v1', accessToken: 'token'),
      );

  int orderDetailCalls = 0;

  @override
  Future<MyOrderListResult> listMyOrders({
    required int page,
    required int pageSize,
    String? keyword,
    String? viewMode,
    int? proxyOperatorUserId,
    String? orderStatus,
    int? currentProcessId,
  }) async {
    return MyOrderListResult(
      total: 1,
      items: [
        MyOrderItem(
          orderId: 1,
          orderCode: 'PO-INTEGRATION-001',
          productId: 10,
          productName: '集成测试产品',
          supplierName: null,
          quantity: 12,
          orderStatus: 'in_progress',
          currentProcessId: 21,
          currentStageId: 5,
          currentStageCode: 'CUT',
          currentStageName: '切割段',
          currentProcessCode: 'CUT-01',
          currentProcessName: '切割',
          currentProcessOrder: 1,
          processStatus: 'in_progress',
          visibleQuantity: 12,
          processCompletedQuantity: 4,
          userSubOrderId: 31,
          userAssignedQuantity: 12,
          userCompletedQuantity: 4,
          operatorUserId: 8,
          operatorUsername: 'zhangsan',
          workView: 'own',
          assistAuthorizationId: null,
          pipelineInstanceId: 301,
          pipelineInstanceNo: 'PIPE-301',
          pipelineModeEnabled: true,
          pipelineStartAllowed: true,
          pipelineEndAllowed: true,
          maxProducibleQuantity: 8,
          canFirstArticle: true,
          canEndProduction: true,
          canApplyAssist: true,
          canCreateManualRepair: true,
          dueDate: DateTime.parse('2026-03-18T00:00:00Z'),
          remark: '',
          updatedAt: DateTime.parse('2026-03-01T08:00:00Z'),
        ),
      ],
    );
  }

  @override
  Future<ProductionOrderDetail> getOrderDetail({required int orderId}) async {
    orderDetailCalls += 1;
    return ProductionOrderDetail.fromJson({
      'order': {
        'id': orderId,
        'order_code': 'PO-$orderId',
        'product_id': 10,
        'product_name': '集成测试产品',
        'product_version': 1,
        'quantity': 12,
        'status': 'in_progress',
        'current_process_code': 'CUT-01',
        'current_process_name': '切割',
        'start_date': '2026-03-01',
        'due_date': '2026-03-18',
        'remark': '',
        'process_template_id': 1,
        'process_template_name': '默认模板',
        'process_template_version': 1,
        'pipeline_enabled': true,
        'pipeline_process_codes': [],
        'created_by_user_id': 1,
        'created_by_username': 'admin',
        'created_at': '2026-03-01T00:00:00Z',
        'updated_at': '2026-03-01T08:00:00Z',
      },
      'processes': [
        {
          'id': 11,
          'stage_id': 1,
          'stage_code': 'CUT',
          'stage_name': '切割段',
          'process_code': 'CUT-01',
          'process_name': '切割',
          'process_order': 1,
          'status': 'in_progress',
          'visible_quantity': 12,
          'completed_quantity': 4,
          'created_at': '2026-03-01T00:00:00Z',
          'updated_at': '2026-03-01T08:00:00Z',
        },
      ],
      'sub_orders': [
        {
          'id': 31,
          'order_process_id': 11,
          'process_code': 'CUT-01',
          'process_name': '切割',
          'operator_user_id': 8,
          'operator_username': 'zhangsan',
          'assigned_quantity': 12,
          'completed_quantity': 4,
          'status': 'in_progress',
          'is_visible': true,
          'created_at': '2026-03-01T00:00:00Z',
          'updated_at': '2026-03-01T08:00:00Z',
        },
      ],
      'records': [
        {
          'id': 41,
          'order_process_id': 11,
          'process_code': 'CUT-01',
          'process_name': '切割',
          'operator_user_id': 8,
          'operator_username': 'zhangsan',
          'production_quantity': 4,
          'record_type': 'production',
          'created_at': '2026-03-01T08:00:00Z',
        },
      ],
      'events': [
        {
          'id': 51,
          'event_type': 'created',
          'event_title': '创建订单',
          'event_detail': '订单已创建',
          'operator_user_id': 1,
          'operator_username': 'admin',
          'payload_json': '{}',
          'created_at': '2026-03-01T08:30:00Z',
        },
      ],
    });
  }
}

class _FakeIntegrationQualityService extends QualityService {
  _FakeIntegrationQualityService()
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
      queryDate: DateTime(2026, 3, 21),
      verificationCode: 'FA-001',
      verificationCodeSource: 'stored',
      total: 1,
      items: [
        FirstArticleListItem(
          id: 1,
          orderId: 10,
          orderCode: 'PO-001',
          productId: 20,
          productName: '产品A',
          orderProcessId: 30,
          processCode: 'GX-01',
          processName: '装配',
          operatorUserId: 40,
          operatorUsername: 'tester',
          result: 'failed',
          verificationDate: DateTime(2026, 3, 21),
          remark: '首件异常',
          createdAt: DateTime(2026, 3, 21, 8),
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

  FirstArticleDetail _buildDetail(int recordId) {
    return FirstArticleDetail(
      id: recordId,
      verificationCode: 'FA-001',
      productionOrderId: 10,
      productionOrderCode: 'PO-001',
      productId: 20,
      productCode: 'P-001',
      productName: '产品A',
      processId: 30,
      processName: '装配',
      operatorUserId: 40,
      operatorUsername: 'tester',
      checkResult: 'failed',
      defectDescription: '尺寸偏差',
      checkAt: DateTime(2026, 3, 21, 8),
      dispositionHistory: const [],
    );
  }
}

class _FakeIntegrationQualitySupplierService extends QualitySupplierService {
  _FakeIntegrationQualitySupplierService(List<QualitySupplierItem> initialItems)
    : _items = List<QualitySupplierItem>.from(initialItems),
      super(
        AppSession(baseUrl: 'http://example.test/api/v1', accessToken: 'token'),
      );

  final List<QualitySupplierItem> _items;
  int createCalls = 0;
  int updateCalls = 0;

  @override
  Future<QualitySupplierListResult> listSuppliers({
    String? keyword,
    bool? enabled,
  }) async {
    return QualitySupplierListResult(total: _items.length, items: [..._items]);
  }

  @override
  Future<QualitySupplierItem> createSupplier(
    QualitySupplierUpsertPayload payload,
  ) async {
    createCalls += 1;
    final item = QualitySupplierItem(
      id: _items.isEmpty ? 1 : _items.last.id + 1,
      name: payload.name,
      remark: payload.remark,
      isEnabled: payload.isEnabled,
      createdAt: DateTime.parse('2026-03-01T00:00:00Z'),
      updatedAt: DateTime.parse('2026-03-01T00:00:00Z'),
    );
    _items.add(item);
    return item;
  }

  @override
  Future<QualitySupplierItem> updateSupplier(
    int supplierId,
    QualitySupplierUpsertPayload payload,
  ) async {
    updateCalls += 1;
    final index = _items.indexWhere((item) => item.id == supplierId);
    final updated = QualitySupplierItem(
      id: supplierId,
      name: payload.name,
      remark: payload.remark,
      isEnabled: payload.isEnabled,
      createdAt: _items[index].createdAt,
      updatedAt: DateTime.parse('2026-03-02T00:00:00Z'),
    );
    _items[index] = updated;
    return updated;
  }
}

class _FakeIntegrationEquipmentService extends EquipmentService {
  _FakeIntegrationEquipmentService()
    : _rules = <EquipmentRuleItem>[
        EquipmentRuleItem(
          id: 11,
          equipmentId: 101,
          equipmentType: '冲压机',
          equipmentCode: 'EQ-101',
          equipmentName: '冲压机-1',
          ruleCode: 'RULE-11',
          ruleName: '压力规则',
          ruleType: '阈值',
          conditionDesc: '压力超限',
          isEnabled: true,
          effectiveAt: DateTime.parse('2026-03-01T00:00:00Z'),
          remark: '集成规则',
          createdAt: DateTime.parse('2026-03-01T00:00:00Z'),
          updatedAt: DateTime.parse('2026-03-01T00:00:00Z'),
        ),
      ],
      _parameters = <EquipmentRuntimeParameterItem>[
        EquipmentRuntimeParameterItem(
          id: 21,
          equipmentId: 101,
          equipmentType: '冲压机',
          equipmentCode: 'EQ-101',
          equipmentName: '冲压机-1',
          paramCode: 'PRESSURE',
          paramName: '压力',
          unit: 'bar',
          standardValue: '1.2',
          upperLimit: '1.5',
          lowerLimit: '1.0',
          effectiveAt: DateTime.parse('2026-03-01T00:00:00Z'),
          isEnabled: true,
          remark: '集成参数',
          createdAt: DateTime.parse('2026-03-01T00:00:00Z'),
          updatedAt: DateTime.parse('2026-03-01T00:00:00Z'),
        ),
      ],
      _workOrders = <MaintenanceWorkOrderItem>[
        MaintenanceWorkOrderItem(
          id: 4,
          planId: 3,
          equipmentId: 101,
          equipmentName: '冲压机-1',
          sourceEquipmentCode: 'EQ-101',
          itemId: 2,
          itemName: '月度润滑',
          sourceItemName: '月度润滑',
          sourceExecutionProcessCode: 'STAMPING',
          dueDate: DateTime.parse('2026-03-31T00:00:00Z'),
          status: 'pending',
          executorUserId: 7,
          executorUsername: 'tester',
          startedAt: null,
          completedAt: null,
          resultSummary: null,
          resultRemark: null,
          attachmentLink: null,
          attachmentName: null,
          createdAt: DateTime.parse('2026-03-01T08:00:00Z'),
          updatedAt: DateTime.parse('2026-03-03T10:00:00Z'),
        ),
      ],
      super(
        AppSession(baseUrl: 'http://example.test/api/v1', accessToken: 'token'),
      );

  int detailCalls = 0;
  int startCalls = 0;
  final List<EquipmentRuleItem> _rules;
  final List<EquipmentRuntimeParameterItem> _parameters;
  final List<MaintenanceWorkOrderItem> _workOrders;

  @override
  Future<EquipmentLedgerListResult> listEquipment({
    required int page,
    required int pageSize,
    String? keyword,
    bool? enabled,
    String? locationKeyword,
    String? ownerName,
  }) async {
    return EquipmentLedgerListResult(
      total: 1,
      items: [
        EquipmentLedgerItem(
          id: 101,
          code: 'EQ-101',
          name: '冲压机-1',
          model: 'MODEL-A',
          location: 'A区',
          ownerName: 'tester',
          remark: '',
          isEnabled: true,
          createdAt: DateTime.parse('2026-03-01T00:00:00Z'),
          updatedAt: DateTime.parse('2026-03-01T00:00:00Z'),
        ),
      ],
    );
  }

  @override
  Future<MaintenanceWorkOrderListResult> listExecutions({
    required int page,
    required int pageSize,
    String? keyword,
    String? status,
    bool mineOnly = false,
    DateTime? dueDateStart,
    DateTime? dueDateEnd,
    String? stageCode,
  }) async {
    return MaintenanceWorkOrderListResult(
      total: _workOrders.length,
      items: List<MaintenanceWorkOrderItem>.from(_workOrders),
    );
  }

  @override
  Future<void> startExecution({required int workOrderId}) async {
    startCalls += 1;
    final index = _workOrders.indexWhere((item) => item.id == workOrderId);
    final item = _workOrders[index];
    _workOrders[index] = MaintenanceWorkOrderItem(
      id: item.id,
      planId: item.planId,
      equipmentId: item.equipmentId,
      equipmentName: item.equipmentName,
      sourceEquipmentCode: item.sourceEquipmentCode,
      itemId: item.itemId,
      itemName: item.itemName,
      sourceItemName: item.sourceItemName,
      sourceExecutionProcessCode: item.sourceExecutionProcessCode,
      dueDate: item.dueDate,
      status: 'in_progress',
      executorUserId: item.executorUserId,
      executorUsername: item.executorUsername,
      startedAt: DateTime.parse('2026-03-31T08:00:00Z'),
      completedAt: null,
      resultSummary: null,
      resultRemark: null,
      attachmentLink: null,
      attachmentName: null,
      createdAt: item.createdAt,
      updatedAt: DateTime.parse('2026-03-31T08:00:00Z'),
    );
  }

  @override
  Future<MaintenanceWorkOrderDetail> getWorkOrderDetail({
    required int workOrderId,
  }) async {
    detailCalls += 1;
    final item = _workOrders.singleWhere((entry) => entry.id == workOrderId);
    return MaintenanceWorkOrderDetail(
      id: item.id,
      planId: item.planId,
      equipmentId: item.equipmentId,
      equipmentName: item.equipmentName,
      sourceEquipmentCode: item.sourceEquipmentCode,
      itemId: item.itemId,
      itemName: item.itemName,
      sourceItemName: item.sourceItemName,
      sourceExecutionProcessCode: item.sourceExecutionProcessCode,
      dueDate: item.dueDate,
      status: item.status,
      executorUserId: item.executorUserId,
      executorUsername: item.executorUsername,
      startedAt: item.startedAt,
      completedAt: item.completedAt,
      resultSummary: item.resultSummary,
      resultRemark: item.resultRemark,
      attachmentLink: item.attachmentLink,
      attachmentName: item.attachmentName,
      createdAt: item.createdAt,
      updatedAt: item.updatedAt,
      sourcePlanId: item.planId,
      sourcePlanCycleDays: 30,
      sourcePlanStartDate: DateTime.parse('2026-03-01T00:00:00Z'),
      sourcePlanSummary: '冲压机-1 / 月度润滑',
      sourceEquipmentName: item.equipmentName,
      sourceItemId: item.itemId,
      recordId: null,
    );
  }

  @override
  Future<EquipmentRuleListResult> listEquipmentRules({
    int? equipmentId,
    String? keyword,
    bool? isEnabled,
    int page = 1,
    int pageSize = 20,
  }) async {
    return EquipmentRuleListResult(total: _rules.length, items: _rules);
  }

  @override
  Future<EquipmentRuntimeParameterListResult> listRuntimeParameters({
    int? equipmentId,
    String? equipmentType,
    String? keyword,
    bool? isEnabled,
    int page = 1,
    int pageSize = 20,
  }) async {
    final filtered = _parameters.where((item) {
      final equipmentMatched =
          equipmentId == null || item.equipmentId == equipmentId;
      final typeMatched =
          equipmentType == null || item.equipmentType == equipmentType;
      final statusMatched = isEnabled == null || item.isEnabled == isEnabled;
      return equipmentMatched && typeMatched && statusMatched;
    }).toList();
    return EquipmentRuntimeParameterListResult(
      total: filtered.length,
      items: filtered,
    );
  }
}

class _FakeAuthService extends AuthService {
  int registerCalls = 0;
  String? lastUsername;
  String? lastPassword;
  bool mustChangePassword = false;
  Object? loginError;
  final List<String> registeredAccounts = <String>['tester'];

  @override
  Future<List<String>> listAccounts({required String baseUrl}) async {
    return List<String>.from(registeredAccounts);
  }

  @override
  Future<({String token, bool mustChangePassword})> login({
    required String baseUrl,
    required String username,
    required String password,
  }) async {
    lastUsername = username;
    lastPassword = password;
    if (loginError != null) {
      throw loginError!;
    }
    return (token: 'token-123', mustChangePassword: mustChangePassword);
  }

  @override
  Future<void> register({
    required String baseUrl,
    required String account,
    required String password,
  }) async {
    registerCalls += 1;
    registeredAccounts.add(account);
  }
}

class _FakeUserService extends UserService {
  _FakeUserService()
    : super(
        AppSession(baseUrl: 'http://example.test/api/v1', accessToken: 'token'),
      );

  int changePasswordCalls = 0;

  @override
  Future<ProfileResult> getMyProfile() async {
    return ProfileResult(
      id: 1,
      username: 'tester',
      fullName: '集成测试用户',
      roleCode: 'quality_admin',
      roleName: '品质管理员',
      stageId: null,
      stageName: null,
      isActive: true,
      createdAt: DateTime.parse('2026-03-01T08:00:00Z'),
      lastLoginAt: DateTime.parse('2026-03-20T08:00:00Z'),
      lastLoginIp: '127.0.0.1',
      passwordChangedAt: DateTime.parse('2026-03-10T08:00:00Z'),
    );
  }

  @override
  Future<CurrentSessionResult> getMySession() async {
    return CurrentSessionResult(
      sessionTokenId: 'session-1',
      loginTime: DateTime.parse('2026-03-20T08:00:00Z'),
      lastActiveAt: DateTime.parse('2026-03-20T08:10:00Z'),
      expiresAt: DateTime.parse('2026-03-20T10:00:00Z'),
      status: 'active',
      remainingSeconds: 5400,
    );
  }

  @override
  Future<RoleListResult> listRoles({
    int page = 1,
    int pageSize = 200,
    String? keyword,
  }) async {
    return RoleListResult(
      total: 1,
      items: [
        RoleItem(
          id: 1,
          code: 'maintenance_staff',
          name: '维修员',
          description: '维修角色',
          roleType: 'builtin',
          isBuiltin: true,
          isEnabled: true,
          userCount: 2,
          createdAt: null,
          updatedAt: null,
        ),
      ],
    );
  }

  @override
  Future<RoleListResult> listAllRoles({String? keyword}) async {
    return RoleListResult(
      total: 2,
      items: [
        RoleItem(
          id: 1,
          code: 'maintenance_staff',
          name: '维修员',
          description: '维修角色',
          roleType: 'builtin',
          isBuiltin: true,
          isEnabled: true,
          userCount: 2,
          createdAt: null,
          updatedAt: null,
        ),
        RoleItem(
          id: 2,
          code: 'quality_admin',
          name: '品质管理员',
          description: '品质角色',
          roleType: 'builtin',
          isBuiltin: true,
          isEnabled: true,
          userCount: 1,
          createdAt: null,
          updatedAt: null,
        ),
      ],
    );
  }

  @override
  Future<AuditLogListResult> listAuditLogs({
    required int page,
    required int pageSize,
    String? operatorUsername,
    String? actionCode,
    String? targetType,
    DateTime? startTime,
    DateTime? endTime,
  }) async {
    return AuditLogListResult(
      total: 1,
      items: [
        AuditLogItem(
          id: 1,
          occurredAt: DateTime.parse('2026-03-20T08:00:00Z'),
          operatorUserId: 1,
          operatorUsername: 'admin',
          actionCode: 'user.disable',
          actionName: '停用用户',
          targetType: 'user',
          targetId: '2',
          targetName: 'tester',
          result: 'success',
          beforeData: const {'enabled': true},
          afterData: const {'enabled': false},
          ipAddress: null,
          terminalInfo: null,
          remark: null,
        ),
      ],
    );
  }

  @override
  Future<OnlineSessionListResult> listOnlineSessions({
    required int page,
    required int pageSize,
    String? keyword,
    String? statusFilter,
  }) async {
    return OnlineSessionListResult(
      total: 1,
      items: [
        OnlineSessionItem(
          id: 1,
          sessionTokenId: 'session-1',
          userId: 1,
          username: 'tester',
          roleCode: 'quality_admin',
          roleName: '品质管理员',
          stageId: null,
          stageName: null,
          loginTime: DateTime.parse('2026-03-20T08:00:00Z'),
          lastActiveAt: DateTime.parse('2026-03-20T08:10:00Z'),
          expiresAt: DateTime.parse('2026-03-20T09:00:00Z'),
          ipAddress: '127.0.0.1',
          terminalInfo: 'integration-test',
          status: 'active',
        ),
      ],
    );
  }

  @override
  Future<void> changeMyPassword({
    required String oldPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    changePasswordCalls += 1;
  }
}

class _MessageCenterIntegrationHost extends StatefulWidget {
  const _MessageCenterIntegrationHost({
    required this.session,
    required this.userService,
    required this.messageService,
  });

  final AppSession session;
  final _FakeUserService userService;
  final _FakeIntegrationMessageService messageService;

  @override
  State<_MessageCenterIntegrationHost> createState() =>
      _MessageCenterIntegrationHostState();
}

class _MessageCenterIntegrationHostState
    extends State<_MessageCenterIntegrationHost> {
  String _pageCode = 'message_center';
  String? _tabCode;
  String? _routePayloadJson;

  @override
  Widget build(BuildContext context) {
    if (_pageCode == 'user' && _tabCode == 'account_settings') {
      return AccountSettingsPage(
        session: widget.session,
        onLogout: () {},
        canChangePassword: true,
        canViewSession: true,
        routePayloadJson: _routePayloadJson,
        userService: widget.userService,
      );
    }
    return MessageCenterPage(
      session: widget.session,
      onLogout: () {},
      canViewDetail: true,
      canUseJump: true,
      service: widget.messageService,
      userService: widget.userService,
      onNavigateToPage: (pageCode, {tabCode, routePayloadJson}) {
        setState(() {
          _pageCode = pageCode;
          _tabCode = tabCode;
          _routePayloadJson = routePayloadJson;
        });
      },
    );
  }
}

class _FakeIntegrationMessageService extends MessageService {
  _FakeIntegrationMessageService()
    : super(
        AppSession(baseUrl: 'http://example.test/api/v1', accessToken: 'token'),
      );

  int markReadCalls = 0;

  List<MessageItem> _items = <MessageItem>[
    MessageItem.fromJson({
      'id': 301,
      'message_type': 'notice',
      'priority': 'important',
      'title': '账户安全提醒',
      'summary': '请立即完成密码更新',
      'content': '账号已创建，请及时修改初始密码。',
      'source_module': 'user',
      'source_type': 'registration_request',
      'source_code': 'REG-301',
      'target_page_code': 'user',
      'target_tab_code': 'account_settings',
      'target_route_payload_json': '{"action":"change_password"}',
      'status': 'active',
      'published_at': '2026-03-20T08:00:00Z',
      'is_read': false,
      'delivery_status': 'delivered',
      'delivery_attempt_count': 1,
    }),
  ];

  MessageItem _copyItem(MessageItem item, {required bool isRead}) {
    return MessageItem.fromJson({
      'id': item.id,
      'message_type': item.messageType,
      'priority': item.priority,
      'title': item.title,
      'summary': item.summary,
      'content': item.content,
      'source_module': item.sourceModule,
      'source_type': item.sourceType,
      'source_code': item.sourceCode,
      'target_page_code': item.targetPageCode,
      'target_tab_code': item.targetTabCode,
      'target_route_payload_json': item.targetRoutePayloadJson,
      'status': item.status,
      'inactive_reason': item.inactiveReason,
      'published_at': item.publishedAt?.toUtc().toIso8601String(),
      'is_read': isRead,
      'read_at': isRead
          ? DateTime.parse('2026-03-20T08:30:00Z').toUtc().toIso8601String()
          : null,
      'delivery_status': item.deliveryStatus,
      'delivery_attempt_count': item.deliveryAttemptCount,
      'last_push_at': item.lastPushAt?.toUtc().toIso8601String(),
      'next_retry_at': item.nextRetryAt?.toUtc().toIso8601String(),
    });
  }

  @override
  Future<MessageSummaryResult> getSummary() async {
    final unreadCount = _items.where((item) => !item.isRead).length;
    return MessageSummaryResult(
      totalCount: _items.length,
      unreadCount: unreadCount,
      todoUnreadCount: 0,
      urgentUnreadCount: 0,
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
      items: List<MessageItem>.from(_items),
      total: _items.length,
      page: page,
      pageSize: pageSize,
    );
  }

  @override
  Future<MessageDetailResult> getMessageDetail(int messageId) async {
    final item = _items.singleWhere((entry) => entry.id == messageId);
    return MessageDetailResult(
      item: item,
      sourceId: 'REG-301',
      failureReasonHint: null,
    );
  }

  @override
  Future<void> markRead(int messageId) async {
    markReadCalls += 1;
    _items = _items
        .map(
          (item) => item.id == messageId ? _copyItem(item, isRead: true) : item,
        )
        .toList();
  }

  @override
  Future<MessageJumpResult> getMessageJumpTarget(int messageId) async {
    final item = _items.singleWhere((entry) => entry.id == messageId);
    return MessageJumpResult(
      canJump: true,
      disabledReason: null,
      targetPageCode: item.targetPageCode,
      targetTabCode: item.targetTabCode,
      targetRoutePayloadJson: item.targetRoutePayloadJson,
    );
  }
}

class _FakeIntegrationAuthzService extends AuthzService {
  _FakeIntegrationAuthzService()
    : super(
        AppSession(baseUrl: 'http://example.test/api/v1', accessToken: 'token'),
      );

  int applyCapabilityPacksCalls = 0;

  @override
  Future<CapabilityPackCatalogResult> loadCapabilityPackCatalog({
    required String moduleCode,
  }) async {
    return const CapabilityPackCatalogResult(
      moduleCode: 'user',
      moduleCodes: ['user', 'product', 'system'],
      moduleName: '用户管理',
      moduleRevision: 1,
      modulePermissionCode: 'module.user',
      capabilityPacks: [
        CapabilityPackItem(
          capabilityCode: 'feature.user.role_management.view',
          capabilityName: '查看角色管理',
          groupCode: 'user.roles',
          groupName: '角色管理',
          pageCode: 'role_management',
          pageName: '角色管理',
          description: '查看角色权限说明',
          dependencyCapabilityCodes: [],
          linkedActionPermissionCodes: [],
        ),
      ],
      roleTemplates: [],
    );
  }

  @override
  Future<CapabilityPackRoleConfigResult> loadCapabilityPackRoleConfig({
    required String roleCode,
    required String moduleCode,
  }) async {
    return CapabilityPackRoleConfigResult(
      roleCode: roleCode,
      roleName: roleCode == 'quality_admin' ? '品质管理员' : '维修员',
      readonly: false,
      moduleCode: moduleCode,
      moduleEnabled: true,
      grantedCapabilityCodes: const ['feature.user.role_management.view'],
      effectiveCapabilityCodes: const ['feature.user.role_management.view'],
      effectivePagePermissionCodes: const ['page.role_management.view'],
      autoLinkedDependencies: const [],
    );
  }

  @override
  Future<CapabilityPackPreviewResult> applyCapabilityPacks({
    required String moduleCode,
    required List<CapabilityPackRoleDraftItem> roleItems,
    required int expectedRevision,
    String? remark,
  }) async {
    applyCapabilityPacksCalls += 1;
    return const CapabilityPackPreviewResult(
      moduleCode: 'user',
      moduleRevision: 2,
      roleResults: [],
    );
  }
}
