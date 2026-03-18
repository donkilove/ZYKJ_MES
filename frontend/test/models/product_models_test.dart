import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/models/product_models.dart';

void main() {
  test('ProductItem and ProductListResult parse correctly', () {
    final item = ProductItem.fromJson({
      'id': 7,
      'name': '测试产品',
      'last_parameter_summary': '温度=200',
      'created_at': '2026-03-01T00:00:00Z',
      'updated_at': '2026-03-02T00:00:00Z',
    });
    final result = ProductListResult(total: 1, items: [item]);

    expect(item.id, 7);
    expect(item.name, '测试产品');
    expect(result.total, 1);
    expect(result.items.single.lastParameterSummary, '温度=200');
  });

  test('ProductParameterItem defaults optional fields', () {
    final item = ProductParameterItem.fromJson({'name': '参数A'});

    expect(item.name, '参数A');
    expect(item.category, '');
    expect(item.type, 'Text');
    expect(item.value, '');
    expect(item.sortOrder, 0);
    expect(item.isPreset, isFalse);
  });

  test('ProductParameterUpdateItem serializes to json', () {
    final item = ProductParameterUpdateItem(
      name: '参数B',
      category: '尺寸',
      type: 'Number',
      value: '10',
    );

    expect(item.toJson(), {
      'name': '参数B',
      'category': '尺寸',
      'type': 'Number',
      'value': '10',
      'description': '',
    });
  });

  test('ProductParameterListResult and history/update models parse', () {
    final list = ProductParameterListResult.fromJson({
      'product_id': 5,
      'product_name': '产品X',
      'version': 3,
      'version_label': 'V1.3',
      'lifecycle_status': 'draft',
      'total': 2,
      'items': [
        {
          'name': '参数1',
          'category': '分类1',
          'type': 'Text',
          'value': 'v1',
          'sort_order': 1,
          'is_preset': true,
        },
      ],
    });

    final history = ProductParameterHistoryItem.fromJson({
      'id': 10,
      'version': 3,
      'version_label': 'V1.3',
      'remark': '变更备注',
      'changed_keys': ['参数1'],
      'operator_username': null,
      'created_at': '2026-03-02T10:00:00Z',
    });

    final update = ProductParameterUpdateResult.fromJson({
      'updated_count': 3,
      'changed_keys': ['参数1', '参数2'],
    });

    final historyList = ProductParameterHistoryListResult(
      version: 3,
      versionLabel: 'V1.3',
      lifecycleStatus: 'draft',
      total: 1,
      items: [history],
    );

    expect(list.productId, 5);
    expect(list.versionLabel, 'V1.3');
    expect(list.items.single.isPreset, isTrue);
    expect(history.operatorUsername, '-');
    expect(history.versionLabel, 'V1.3');
    expect(historyList.total, 1);
    expect(update.updatedCount, 3);
    expect(update.changedKeys.length, 2);
  });

  test('ProductJumpCommand stores immutable navigation payload', () {
    const command = ProductJumpCommand(
      seq: 8,
      targetTabCode: 'product_management',
      action: 'view',
      productId: 123,
      productName: '产品Y',
    );

    expect(command.seq, 8);
    expect(command.targetTabCode, 'product_management');
    expect(command.productId, 123);
  });
}
