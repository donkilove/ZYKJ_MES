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

class PageVisibilityMeResult {
  PageVisibilityMeResult({
    required this.sidebarCodes,
    required this.tabCodesByParent,
  });

  final List<String> sidebarCodes;
  final Map<String, List<String>> tabCodesByParent;

  factory PageVisibilityMeResult.fromJson(Map<String, dynamic> json) {
    final rawMap =
        (json['tab_codes_by_parent'] as Map<String, dynamic>? ?? const {});
    final mapped = <String, List<String>>{};
    rawMap.forEach((key, value) {
      final list = (value as List<dynamic>? ?? const []).cast<String>();
      mapped[key] = list;
    });
    return PageVisibilityMeResult(
      sidebarCodes:
          (json['sidebar_codes'] as List<dynamic>? ?? const []).cast<String>(),
      tabCodesByParent: mapped,
    );
  }
}

class PageVisibilityConfigItem {
  PageVisibilityConfigItem({
    required this.roleCode,
    required this.roleName,
    required this.pageCode,
    required this.pageName,
    required this.pageType,
    required this.parentCode,
    required this.editable,
    required this.isVisible,
    required this.alwaysVisible,
  });

  final String roleCode;
  final String roleName;
  final String pageCode;
  final String pageName;
  final String pageType;
  final String? parentCode;
  final bool editable;
  final bool isVisible;
  final bool alwaysVisible;

  factory PageVisibilityConfigItem.fromJson(Map<String, dynamic> json) {
    return PageVisibilityConfigItem(
      roleCode: json['role_code'] as String,
      roleName: json['role_name'] as String,
      pageCode: json['page_code'] as String,
      pageName: json['page_name'] as String,
      pageType: json['page_type'] as String,
      parentCode: json['parent_code'] as String?,
      editable: (json['editable'] as bool?) ?? false,
      isVisible: (json['is_visible'] as bool?) ?? false,
      alwaysVisible: (json['always_visible'] as bool?) ?? false,
    );
  }
}

class PageVisibilityConfigUpdateItem {
  const PageVisibilityConfigUpdateItem({
    required this.roleCode,
    required this.pageCode,
    required this.isVisible,
  });

  final String roleCode;
  final String pageCode;
  final bool isVisible;

  Map<String, dynamic> toJson() {
    return {
      'role_code': roleCode,
      'page_code': pageCode,
      'is_visible': isVisible,
    };
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
    code: 'page_visibility_config',
    name: '页面可见性配置',
    pageType: 'tab',
    parentCode: 'user',
    alwaysVisible: false,
    sortOrder: 23,
  ),
];
