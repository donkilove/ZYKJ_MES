class PageCatalogItem {
  const PageCatalogItem({
    required this.code,

    required this.name,

    required this.pageType,

    required this.parentCode,

    required this.alwaysVisible,

    required this.sortOrder,
  });

  final String code;

  final String name;

  final String pageType;

  final String? parentCode;

  final bool alwaysVisible;

  final int sortOrder;

  factory PageCatalogItem.fromJson(Map<String, dynamic> json) {
    return PageCatalogItem(
      code: json['code'] as String,

      name: json['name'] as String,

      pageType: json['page_type'] as String,

      parentCode: json['parent_code'] as String?,

      alwaysVisible: (json['always_visible'] as bool?) ?? false,

      sortOrder: (json['sort_order'] as int?) ?? 0,
    );
  }
}

const fallbackPageCatalog = <PageCatalogItem>[
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
    code: 'user_management',

    name: '用户管理',

    pageType: 'tab',

    parentCode: 'user',

    alwaysVisible: false,

    sortOrder: 21,
  ),

  PageCatalogItem(
    code: 'registration_approval',

    name: '注册审批',

    pageType: 'tab',

    parentCode: 'user',

    alwaysVisible: false,

    sortOrder: 22,
  ),

  PageCatalogItem(
    code: 'role_management',

    name: '角色管理',

    pageType: 'tab',

    parentCode: 'user',

    alwaysVisible: false,

    sortOrder: 23,
  ),

  PageCatalogItem(
    code: 'audit_log',

    name: '审计日志',

    pageType: 'tab',

    parentCode: 'user',

    alwaysVisible: false,

    sortOrder: 24,
  ),

  PageCatalogItem(
    code: 'account_settings',

    name: '个人中心',

    pageType: 'tab',

    parentCode: 'user',

    alwaysVisible: false,

    sortOrder: 25,
  ),

  PageCatalogItem(
    code: 'login_session',

    name: '登录会话',

    pageType: 'tab',

    parentCode: 'user',

    alwaysVisible: false,

    sortOrder: 26,
  ),

  PageCatalogItem(
    code: 'function_permission_config',

    name: '功能权限配置',

    pageType: 'tab',

    parentCode: 'user',

    alwaysVisible: false,

    sortOrder: 27,
  ),

  PageCatalogItem(
    code: 'product',

    name: '产品',

    pageType: 'sidebar',

    parentCode: null,

    alwaysVisible: false,

    sortOrder: 30,
  ),

  PageCatalogItem(
    code: 'product_management',

    name: '产品管理',

    pageType: 'tab',

    parentCode: 'product',

    alwaysVisible: false,

    sortOrder: 31,
  ),

  PageCatalogItem(
    code: 'product_version_management',

    name: '版本管理',

    pageType: 'tab',

    parentCode: 'product',

    alwaysVisible: false,

    sortOrder: 32,
  ),

  PageCatalogItem(
    code: 'product_parameter_management',

    name: '产品参数管理',

    pageType: 'tab',

    parentCode: 'product',

    alwaysVisible: false,

    sortOrder: 33,
  ),

  PageCatalogItem(
    code: 'product_parameter_query',

    name: '产品参数查询',

    pageType: 'tab',

    parentCode: 'product',

    alwaysVisible: false,

    sortOrder: 34,
  ),

  PageCatalogItem(
    code: 'equipment',

    name: '设备',

    pageType: 'sidebar',

    parentCode: null,

    alwaysVisible: false,

    sortOrder: 70,
  ),

  PageCatalogItem(
    code: 'equipment_ledger',

    name: '设备台账',

    pageType: 'tab',

    parentCode: 'equipment',

    alwaysVisible: false,

    sortOrder: 41,
  ),

  PageCatalogItem(
    code: 'maintenance_item',

    name: '保养项目',

    pageType: 'tab',

    parentCode: 'equipment',

    alwaysVisible: false,

    sortOrder: 42,
  ),

  PageCatalogItem(
    code: 'maintenance_plan',

    name: '保养计划',

    pageType: 'tab',

    parentCode: 'equipment',

    alwaysVisible: false,

    sortOrder: 43,
  ),

  PageCatalogItem(
    code: 'maintenance_execution',

    name: '保养执行',

    pageType: 'tab',

    parentCode: 'equipment',

    alwaysVisible: false,

    sortOrder: 44,
  ),

  PageCatalogItem(
    code: 'maintenance_record',

    name: '保养记录',

    pageType: 'tab',

    parentCode: 'equipment',

    alwaysVisible: false,

    sortOrder: 45,
  ),

  PageCatalogItem(
    code: 'equipment_rule_parameter',

    name: '规则与参数',

    pageType: 'tab',

    parentCode: 'equipment',

    alwaysVisible: false,

    sortOrder: 46,
  ),

  PageCatalogItem(
    code: 'production',

    name: '生产',

    pageType: 'sidebar',

    parentCode: null,

    alwaysVisible: false,

    sortOrder: 50,
  ),

  PageCatalogItem(
    code: 'production_order_management',

    name: '订单管理',

    pageType: 'tab',

    parentCode: 'production',

    alwaysVisible: false,

    sortOrder: 51,
  ),

  PageCatalogItem(
    code: 'production_order_query',

    name: '订单查询',

    pageType: 'tab',

    parentCode: 'production',

    alwaysVisible: false,

    sortOrder: 52,
  ),

  PageCatalogItem(
    code: 'production_assist_approval',

    name: '代班记录',

    pageType: 'tab',

    parentCode: 'production',

    alwaysVisible: false,

    sortOrder: 53,
  ),

  PageCatalogItem(
    code: 'production_data_query',

    name: '生产数据',

    pageType: 'tab',

    parentCode: 'production',

    alwaysVisible: false,

    sortOrder: 54,
  ),

  PageCatalogItem(
    code: 'production_scrap_statistics',

    name: '报废统计',

    pageType: 'tab',

    parentCode: 'production',

    alwaysVisible: false,

    sortOrder: 55,
  ),

  PageCatalogItem(
    code: 'production_repair_orders',

    name: '维修订单',

    pageType: 'tab',

    parentCode: 'production',

    alwaysVisible: false,

    sortOrder: 56,
  ),

  PageCatalogItem(
    code: 'production_pipeline_instances',

    name: '并行实例追踪',

    pageType: 'tab',

    parentCode: 'production',

    alwaysVisible: false,

    sortOrder: 57,
  ),

  PageCatalogItem(
    code: 'quality',

    name: '品质',

    pageType: 'sidebar',

    parentCode: null,

    alwaysVisible: false,

    sortOrder: 60,
  ),

  PageCatalogItem(
    code: 'first_article_management',

    name: '每日首件',

    pageType: 'tab',

    parentCode: 'quality',

    alwaysVisible: false,

    sortOrder: 61,
  ),

  PageCatalogItem(
    code: 'quality_data_query',

    name: '品质数据',

    pageType: 'tab',

    parentCode: 'quality',

    alwaysVisible: false,

    sortOrder: 62,
  ),

  PageCatalogItem(
    code: 'quality_scrap_statistics',

    name: '报废统计',

    pageType: 'tab',

    parentCode: 'quality',

    alwaysVisible: false,

    sortOrder: 63,
  ),

  PageCatalogItem(
    code: 'quality_repair_orders',

    name: '维修订单',

    pageType: 'tab',

    parentCode: 'quality',

    alwaysVisible: false,

    sortOrder: 64,
  ),

  PageCatalogItem(
    code: 'quality_trend',

    name: '质量趋势',

    pageType: 'tab',

    parentCode: 'quality',

    alwaysVisible: false,

    sortOrder: 65,
  ),

  PageCatalogItem(
    code: 'quality_defect_analysis',

    name: '不良分析',

    pageType: 'tab',

    parentCode: 'quality',

    alwaysVisible: false,

    sortOrder: 66,
  ),

  PageCatalogItem(
    code: 'quality_supplier_management',

    name: '供应商管理',

    pageType: 'tab',

    parentCode: 'quality',

    alwaysVisible: true,

    sortOrder: 67,
  ),

  PageCatalogItem(
    code: 'craft',

    name: '工艺',

    pageType: 'sidebar',

    parentCode: null,

    alwaysVisible: false,

    sortOrder: 40,
  ),

  PageCatalogItem(
    code: 'process_management',

    name: '工序管理',

    pageType: 'tab',

    parentCode: 'craft',

    alwaysVisible: false,

    sortOrder: 71,
  ),

  PageCatalogItem(
    code: 'production_process_config',

    name: '生产工序配置',

    pageType: 'tab',

    parentCode: 'craft',

    alwaysVisible: false,

    sortOrder: 72,
  ),

  PageCatalogItem(
    code: 'craft_kanban',

    name: '工艺看板',

    pageType: 'tab',

    parentCode: 'craft',

    alwaysVisible: false,

    sortOrder: 73,
  ),

  PageCatalogItem(
    code: 'craft_reference_analysis',

    name: '引用分析',

    pageType: 'tab',

    parentCode: 'craft',

    alwaysVisible: false,

    sortOrder: 74,
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
