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
      'change_type': 'add',
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
    expect(history.changeType, 'add');
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

  test('ProductDetailResult parses aggregated detail payload', () {
    final detail = ProductDetailResult.fromJson({
      'product': {
        'id': 7,
        'name': '测试产品',
        'created_at': '2026-03-01T00:00:00Z',
        'updated_at': '2026-03-02T00:00:00Z',
      },
      'detail_parameters': {
        'product_id': 7,
        'product_name': '测试产品',
        'parameter_scope': 'version',
        'version': 2,
        'version_label': 'V1.1',
        'lifecycle_status': 'draft',
        'total': 1,
        'items': [
          {
            'name': '参数A',
            'category': '基础参数',
            'type': 'Text',
            'value': '1',
            'sort_order': 1,
            'is_preset': false,
          },
        ],
      },
      'detail_parameter_message': '当前无生效版本',
      'latest_version_changed_at': '2026-03-02T01:00:00Z',
      'version_total': 1,
      'versions': [
        {
          'version': 2,
          'version_label': 'V1.1',
          'lifecycle_status': 'draft',
          'action': 'copy',
          'created_at': '2026-03-02T00:00:00Z',
        },
      ],
      'history_total': 1,
      'history_items': [
        {
          'id': 11,
          'remark': '变更',
          'changed_keys': ['参数A'],
          'operator_username': 'admin',
          'created_at': '2026-03-02T00:00:00Z',
        },
      ],
      'related_info_sections': [
        {
          'code': 'process_templates',
          'title': '关联工艺路线',
          'total': 1,
          'items': [
            {'label': '贴片工艺', 'value': '版本 3 | 默认 | published'},
          ],
        },
      ],
    });

    expect(detail.product.name, '测试产品');
    expect(detail.detailParameters.versionLabel, 'V1.1');
    expect(detail.detailParameterMessage, '当前无生效版本');
    expect(detail.versions.single.version, 2);
    expect(detail.historyItems.single.remark, '变更');
    expect(detail.relatedInfoSections.single.title, '关联工艺路线');
    expect(detail.relatedInfoSections.single.items.single.label, '贴片工艺');
  });
}
