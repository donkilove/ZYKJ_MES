class ProductItem {
  ProductItem({
    required this.id,
    required this.name,
    required this.lastParameterSummary,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final String name;
  final String? lastParameterSummary;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory ProductItem.fromJson(Map<String, dynamic> json) {
    return ProductItem(
      id: json['id'] as int,
      name: json['name'] as String,
      lastParameterSummary: json['last_parameter_summary'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}

class ProductListResult {
  ProductListResult({required this.total, required this.items});

  final int total;
  final List<ProductItem> items;
}

class ProductParameterItem {
  ProductParameterItem({
    required this.name,
    required this.category,
    required this.type,
    required this.value,
    required this.sortOrder,
    required this.isPreset,
  });

  final String name;
  final String category;
  final String type;
  final String value;
  final int sortOrder;
  final bool isPreset;

  factory ProductParameterItem.fromJson(Map<String, dynamic> json) {
    return ProductParameterItem(
      name: json['name'] as String,
      category: (json['category'] as String?) ?? '',
      type: (json['type'] as String?) ?? 'Text',
      value: (json['value'] as String?) ?? '',
      sortOrder: (json['sort_order'] as int?) ?? 0,
      isPreset: (json['is_preset'] as bool?) ?? false,
    );
  }
}

class ProductParameterUpdateItem {
  ProductParameterUpdateItem({
    required this.name,
    required this.category,
    required this.type,
    required this.value,
  });

  final String name;
  final String category;
  final String type;
  final String value;

  Map<String, dynamic> toJson() {
    return {'name': name, 'category': category, 'type': type, 'value': value};
  }
}

class ProductParameterListResult {
  ProductParameterListResult({
    required this.productId,
    required this.productName,
    required this.total,
    required this.items,
  });

  final int productId;
  final String productName;
  final int total;
  final List<ProductParameterItem> items;

  factory ProductParameterListResult.fromJson(Map<String, dynamic> json) {
    return ProductParameterListResult(
      productId: json['product_id'] as int,
      productName: json['product_name'] as String,
      total: (json['total'] as int?) ?? 0,
      items: (json['items'] as List<dynamic>? ?? const [])
          .map(
            (entry) =>
                ProductParameterItem.fromJson(entry as Map<String, dynamic>),
          )
          .toList(),
    );
  }
}

class ProductParameterHistoryItem {
  ProductParameterHistoryItem({
    required this.id,
    required this.remark,
    required this.changedKeys,
    required this.operatorUsername,
    required this.createdAt,
  });

  final int id;
  final String remark;
  final List<String> changedKeys;
  final String operatorUsername;
  final DateTime createdAt;

  factory ProductParameterHistoryItem.fromJson(Map<String, dynamic> json) {
    return ProductParameterHistoryItem(
      id: json['id'] as int,
      remark: json['remark'] as String,
      changedKeys: (json['changed_keys'] as List<dynamic>? ?? const [])
          .cast<String>(),
      operatorUsername: json['operator_username'] as String? ?? '-',
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class ProductParameterHistoryListResult {
  ProductParameterHistoryListResult({required this.total, required this.items});

  final int total;
  final List<ProductParameterHistoryItem> items;
}

class ProductParameterUpdateResult {
  ProductParameterUpdateResult({
    required this.updatedCount,
    required this.changedKeys,
  });

  final int updatedCount;
  final List<String> changedKeys;

  factory ProductParameterUpdateResult.fromJson(Map<String, dynamic> json) {
    return ProductParameterUpdateResult(
      updatedCount: (json['updated_count'] as int?) ?? 0,
      changedKeys: (json['changed_keys'] as List<dynamic>? ?? const [])
          .cast<String>(),
    );
  }
}

class ProductJumpCommand {
  const ProductJumpCommand({
    required this.seq,
    required this.targetTabCode,
    required this.action,
    required this.productId,
    required this.productName,
  });

  final int seq;
  final String targetTabCode;
  final String action;
  final int productId;
  final String productName;
}
