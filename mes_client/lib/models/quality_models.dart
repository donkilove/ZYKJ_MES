DateTime? _parseDateTimeOrNull(Object? value) {
  if (value == null) {
    return null;
  }
  final text = value.toString().trim();
  if (text.isEmpty) {
    return null;
  }
  return DateTime.tryParse(text);
}

String firstArticleResultLabel(String result) {
  switch (result) {
    case 'passed':
      return '通过';
    case 'failed':
      return '不通过';
    default:
      return result;
  }
}

String verificationCodeSourceLabel(String source) {
  switch (source) {
    case 'stored':
      return '系统记录';
    case 'default':
      return '默认值';
    case 'none':
      return '无';
    default:
      return source;
  }
}

class FirstArticleListItem {
  FirstArticleListItem({
    required this.id,
    required this.orderId,
    required this.orderCode,
    required this.productId,
    required this.productName,
    required this.orderProcessId,
    required this.processCode,
    required this.processName,
    required this.operatorUserId,
    required this.operatorUsername,
    required this.result,
    required this.verificationDate,
    required this.remark,
    required this.createdAt,
  });

  final int id;
  final int orderId;
  final String orderCode;
  final int productId;
  final String productName;
  final int orderProcessId;
  final String processCode;
  final String processName;
  final int operatorUserId;
  final String operatorUsername;
  final String result;
  final DateTime verificationDate;
  final String? remark;
  final DateTime createdAt;

  factory FirstArticleListItem.fromJson(Map<String, dynamic> json) {
    return FirstArticleListItem(
      id: (json['id'] as int?) ?? 0,
      orderId: (json['order_id'] as int?) ?? 0,
      orderCode: (json['order_code'] as String?) ?? '',
      productId: (json['product_id'] as int?) ?? 0,
      productName: (json['product_name'] as String?) ?? '',
      orderProcessId: (json['order_process_id'] as int?) ?? 0,
      processCode: (json['process_code'] as String?) ?? '',
      processName: (json['process_name'] as String?) ?? '',
      operatorUserId: (json['operator_user_id'] as int?) ?? 0,
      operatorUsername: (json['operator_username'] as String?) ?? '',
      result: (json['result'] as String?) ?? '',
      verificationDate:
          _parseDateTimeOrNull(json['verification_date']) ??
          DateTime(1970, 1, 1),
      remark: json['remark'] as String?,
      createdAt:
          _parseDateTimeOrNull(json['created_at']) ?? DateTime(1970, 1, 1),
    );
  }
}

class FirstArticleListResult {
  FirstArticleListResult({
    required this.queryDate,
    required this.verificationCode,
    required this.verificationCodeSource,
    required this.total,
    required this.items,
  });

  final DateTime queryDate;
  final String? verificationCode;
  final String verificationCodeSource;
  final int total;
  final List<FirstArticleListItem> items;

  factory FirstArticleListResult.fromJson(Map<String, dynamic> json) {
    return FirstArticleListResult(
      queryDate: _parseDateTimeOrNull(json['query_date']) ?? DateTime.now(),
      verificationCode: json['verification_code'] as String?,
      verificationCodeSource:
          (json['verification_code_source'] as String?) ?? 'none',
      total: (json['total'] as int?) ?? 0,
      items: (json['items'] as List<dynamic>? ?? const [])
          .map(
            (entry) =>
                FirstArticleListItem.fromJson(entry as Map<String, dynamic>),
          )
          .toList(),
    );
  }
}

class QualityStatsOverview {
  QualityStatsOverview({
    required this.firstArticleTotal,
    required this.passedTotal,
    required this.failedTotal,
    required this.passRatePercent,
    required this.coveredOrderCount,
    required this.coveredProcessCount,
    required this.coveredOperatorCount,
    required this.latestFirstArticleAt,
  });

  final int firstArticleTotal;
  final int passedTotal;
  final int failedTotal;
  final double passRatePercent;
  final int coveredOrderCount;
  final int coveredProcessCount;
  final int coveredOperatorCount;
  final DateTime? latestFirstArticleAt;

  factory QualityStatsOverview.fromJson(Map<String, dynamic> json) {
    return QualityStatsOverview(
      firstArticleTotal: (json['first_article_total'] as int?) ?? 0,
      passedTotal: (json['passed_total'] as int?) ?? 0,
      failedTotal: (json['failed_total'] as int?) ?? 0,
      passRatePercent: ((json['pass_rate_percent'] as num?) ?? 0).toDouble(),
      coveredOrderCount: (json['covered_order_count'] as int?) ?? 0,
      coveredProcessCount: (json['covered_process_count'] as int?) ?? 0,
      coveredOperatorCount: (json['covered_operator_count'] as int?) ?? 0,
      latestFirstArticleAt: _parseDateTimeOrNull(
        json['latest_first_article_at'],
      ),
    );
  }
}

class QualityProcessStatItem {
  QualityProcessStatItem({
    required this.processCode,
    required this.processName,
    required this.firstArticleTotal,
    required this.passedTotal,
    required this.failedTotal,
    required this.passRatePercent,
    required this.latestFirstArticleAt,
  });

  final String processCode;
  final String processName;
  final int firstArticleTotal;
  final int passedTotal;
  final int failedTotal;
  final double passRatePercent;
  final DateTime? latestFirstArticleAt;

  factory QualityProcessStatItem.fromJson(Map<String, dynamic> json) {
    return QualityProcessStatItem(
      processCode: (json['process_code'] as String?) ?? '',
      processName: (json['process_name'] as String?) ?? '',
      firstArticleTotal: (json['first_article_total'] as int?) ?? 0,
      passedTotal: (json['passed_total'] as int?) ?? 0,
      failedTotal: (json['failed_total'] as int?) ?? 0,
      passRatePercent: ((json['pass_rate_percent'] as num?) ?? 0).toDouble(),
      latestFirstArticleAt: _parseDateTimeOrNull(
        json['latest_first_article_at'],
      ),
    );
  }
}

class QualityOperatorStatItem {
  QualityOperatorStatItem({
    required this.operatorUserId,
    required this.operatorUsername,
    required this.firstArticleTotal,
    required this.passedTotal,
    required this.failedTotal,
    required this.passRatePercent,
    required this.latestFirstArticleAt,
  });

  final int operatorUserId;
  final String operatorUsername;
  final int firstArticleTotal;
  final int passedTotal;
  final int failedTotal;
  final double passRatePercent;
  final DateTime? latestFirstArticleAt;

  factory QualityOperatorStatItem.fromJson(Map<String, dynamic> json) {
    return QualityOperatorStatItem(
      operatorUserId: (json['operator_user_id'] as int?) ?? 0,
      operatorUsername: (json['operator_username'] as String?) ?? '',
      firstArticleTotal: (json['first_article_total'] as int?) ?? 0,
      passedTotal: (json['passed_total'] as int?) ?? 0,
      failedTotal: (json['failed_total'] as int?) ?? 0,
      passRatePercent: ((json['pass_rate_percent'] as num?) ?? 0).toDouble(),
      latestFirstArticleAt: _parseDateTimeOrNull(
        json['latest_first_article_at'],
      ),
    );
  }
}

class QualityProductStatItem {
  const QualityProductStatItem({
    required this.productId,
    required this.productCode,
    required this.productName,
    required this.firstArticleTotal,
    required this.passedTotal,
    required this.failedTotal,
    required this.passRatePercent,
    required this.scrapTotal,
    required this.repairTotal,
  });

  final int productId;
  final String productCode;
  final String productName;
  final int firstArticleTotal;
  final int passedTotal;
  final int failedTotal;
  final double passRatePercent;
  final int scrapTotal;
  final int repairTotal;

  factory QualityProductStatItem.fromJson(Map<String, dynamic> json) {
    return QualityProductStatItem(
      productId: (json['product_id'] as int?) ?? 0,
      productCode: (json['product_code'] as String?) ?? '',
      productName: (json['product_name'] as String?) ?? '',
      firstArticleTotal: (json['first_article_total'] as int?) ?? 0,
      passedTotal: (json['passed_total'] as int?) ?? 0,
      failedTotal: (json['failed_total'] as int?) ?? 0,
      passRatePercent: ((json['pass_rate_percent'] as num?) ?? 0).toDouble(),
      scrapTotal: (json['scrap_total'] as int?) ?? 0,
      repairTotal: (json['repair_total'] as int?) ?? 0,
    );
  }
}

class QualityTrendItem {
  const QualityTrendItem({
    required this.date,
    required this.firstArticleTotal,
    required this.passedTotal,
    required this.failedTotal,
    required this.scrapTotal,
    required this.repairTotal,
  });

  final String date;
  final int firstArticleTotal;
  final int passedTotal;
  final int failedTotal;
  final int scrapTotal;
  final int repairTotal;

  factory QualityTrendItem.fromJson(Map<String, dynamic> json) {
    return QualityTrendItem(
      date: (json['date'] as String?) ?? '',
      firstArticleTotal: (json['first_article_total'] as int?) ?? 0,
      passedTotal: (json['passed_total'] as int?) ?? 0,
      failedTotal: (json['failed_total'] as int?) ?? 0,
      scrapTotal: (json['scrap_total'] as int?) ?? 0,
      repairTotal: (json['repair_total'] as int?) ?? 0,
    );
  }
}

class FirstArticleDispositionInfo {
  const FirstArticleDispositionInfo({
    required this.dispositionOpinion,
    required this.dispositionUsername,
    required this.dispositionAt,
    required this.recheckResult,
    required this.finalJudgment,
  });

  final String dispositionOpinion;
  final String dispositionUsername;
  final DateTime? dispositionAt;
  final String recheckResult;
  final String finalJudgment;

  factory FirstArticleDispositionInfo.fromJson(Map<String, dynamic> json) {
    return FirstArticleDispositionInfo(
      dispositionOpinion: (json['disposition_opinion'] as String?) ?? '',
      dispositionUsername: (json['disposition_username'] as String?) ?? '',
      dispositionAt: _parseDateTimeOrNull(json['disposition_at']),
      recheckResult: (json['recheck_result'] as String?) ?? '',
      finalJudgment: (json['final_judgment'] as String?) ?? '',
    );
  }
}

class FirstArticleDetail {
  const FirstArticleDetail({
    required this.id,
    required this.verificationCode,
    required this.productionOrderId,
    required this.productionOrderCode,
    required this.productId,
    required this.productCode,
    required this.productName,
    required this.processId,
    required this.processName,
    required this.operatorUserId,
    required this.operatorUsername,
    required this.checkResult,
    required this.defectDescription,
    required this.checkAt,
    this.disposition,
  });

  final int id;
  final String verificationCode;
  final int? productionOrderId;
  final String productionOrderCode;
  final int? productId;
  final String productCode;
  final String productName;
  final int? processId;
  final String processName;
  final int? operatorUserId;
  final String operatorUsername;
  final String checkResult;
  final String defectDescription;
  final DateTime? checkAt;
  final FirstArticleDispositionInfo? disposition;

  factory FirstArticleDetail.fromJson(Map<String, dynamic> json) {
    return FirstArticleDetail(
      id: (json['id'] as int?) ?? 0,
      verificationCode: (json['verification_code'] as String?) ?? '',
      productionOrderId: json['production_order_id'] as int?,
      productionOrderCode: (json['production_order_code'] as String?) ?? '',
      productId: json['product_id'] as int?,
      productCode: (json['product_code'] as String?) ?? '',
      productName: (json['product_name'] as String?) ?? '',
      processId: json['process_id'] as int?,
      processName: (json['process_name'] as String?) ?? '',
      operatorUserId: json['operator_user_id'] as int?,
      operatorUsername: (json['operator_username'] as String?) ?? '',
      checkResult: (json['check_result'] as String?) ?? '',
      defectDescription: (json['defect_description'] as String?) ?? '',
      checkAt: _parseDateTimeOrNull(json['check_at']),
      disposition: json['disposition'] != null
          ? FirstArticleDispositionInfo.fromJson(
              json['disposition'] as Map<String, dynamic>,
            )
          : null,
    );
  }
}
