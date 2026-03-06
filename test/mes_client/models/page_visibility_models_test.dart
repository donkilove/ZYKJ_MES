import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/models/page_visibility_models.dart';

void main() {
  test('PageCatalogItem parses fields', () {
    final item = PageCatalogItem.fromJson({
      'code': 'production',
      'name': '生产',
      'page_type': 'sidebar',
      'parent_code': null,
      'always_visible': true,
      'sort_order': 10,
    });

    expect(item.code, 'production');
    expect(item.pageType, 'sidebar');
    expect(item.alwaysVisible, isTrue);
    expect(item.sortOrder, 10);
  });

  test('PageVisibilityMeResult parses tab map', () {
    final result = PageVisibilityMeResult.fromJson({
      'sidebar_codes': ['home', 'production'],
      'tab_codes_by_parent': {
        'production': ['production_order_management', 'production_order_query'],
      },
    });

    expect(result.sidebarCodes.length, 2);
    expect(result.tabCodesByParent['production'], hasLength(2));
  });

  test('PageVisibilityConfigItem and update item conversion', () {
    final config = PageVisibilityConfigItem.fromJson({
      'role_code': 'system_admin',
      'role_name': '系统管理员',
      'page_code': 'process_management',
      'page_name': '工序管理',
      'page_type': 'tab',
      'parent_code': 'craft',
      'editable': true,
      'is_visible': true,
      'always_visible': false,
    });
    const update = PageVisibilityConfigUpdateItem(
      roleCode: 'system_admin',
      pageCode: 'process_management',
      isVisible: false,
    );

    expect(config.roleCode, 'system_admin');
    expect(config.parentCode, 'craft');
    expect(update.toJson(), {
      'role_code': 'system_admin',
      'page_code': 'process_management',
      'is_visible': false,
    });
  });

  test('fallback page catalog provides predefined pages', () {
    expect(fallbackPageCatalog, isNotEmpty);
    expect(
      fallbackPageCatalog.any((entry) => entry.code == 'home'),
      isTrue,
    );
    expect(
      fallbackPageCatalog.any((entry) => entry.code == 'process_management'),
      isTrue,
    );
    expect(
      fallbackPageCatalog.any((entry) => entry.code == 'production_process_config'),
      isTrue,
    );
  });
}
