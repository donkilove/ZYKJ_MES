import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/features/equipment/presentation/maintenance_category_options.dart';
import 'package:mes_client/features/product/presentation/product_category_options.dart';

void main() {
  test('产品分类选项保持统一定义', () {
    expect(productCategoryOptions, const ['贴片', 'DTU', '套件']);
  });

  test('保养分类选项保持统一定义', () {
    expect(maintenanceItemCategoryOptions, const ['点检', '润滑', '校准', '清洁']);
  });
}
