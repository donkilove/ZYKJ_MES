import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/models/page_catalog_models.dart';

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

  test('fallback page catalog provides predefined pages', () {
    expect(fallbackPageCatalog, isNotEmpty);
    expect(fallbackPageCatalog.any((entry) => entry.code == 'home'), isTrue);
    expect(
      fallbackPageCatalog.any((entry) => entry.code == 'process_management'),
      isTrue,
    );
    expect(
      fallbackPageCatalog.any(
        (entry) => entry.code == 'production_process_config',
      ),
      isTrue,
    );
    expect(
      fallbackPageCatalog.any(
        (entry) => entry.code == 'page_visibility_config',
      ),
      isFalse,
    );
  });

  test('fallback sidebar order matches expected navigation order', () {
    final sidebarCodes =
        fallbackPageCatalog
            .where((entry) => entry.pageType == 'sidebar')
            .toList()
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    expect(
      sidebarCodes.map((entry) => entry.code).toList(),
      equals([
        'home',
        'user',
        'product',
        'craft',
        'quality',
        'production',
        'equipment',
        'message',
      ]),
    );
  });
}
