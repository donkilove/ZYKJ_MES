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
    case 'pass':
    case 'passed':
      return '通过';
    case 'fail':
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

class QualityExportFile {
  const QualityExportFile({
    required this.filename,
    required this.contentBase64,
  });

  final String filename;
  final String contentBase64;

  factory QualityExportFile.fromJson(
    Map<String, dynamic> json, {
    required String fallbackFilename,
  }) {
    return QualityExportFile(
      filename:
          (json['filename'] as String?) ??
          (json['file_name'] as String?) ??
          fallbackFilename,
      contentBase64:
          (json['content_base64'] as String?) ??
          (json['data'] as String?) ??
          '',
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
      repairTotal:
          (json['repair_total'] as int?) ??
          (json['repair_order_count'] as int?) ??
          0,
    );
  }
}

class QualityTrendItem {
  const QualityTrendItem({
    required this.date,
    required this.firstArticleTotal,
    required this.passedTotal,
    required this.failedTotal,
    required this.passRatePercent,
    required this.defectTotal,
    required this.scrapTotal,
    required this.repairTotal,
  });

  final String date;
  final int firstArticleTotal;
  final int passedTotal;
  final int failedTotal;
  final double passRatePercent;
  final int defectTotal;
  final int scrapTotal;
  final int repairTotal;

  factory QualityTrendItem.fromJson(Map<String, dynamic> json) {
    return QualityTrendItem(
      date: (json['date'] as String?) ?? (json['stat_date'] as String?) ?? '',
      firstArticleTotal: (json['first_article_total'] as int?) ?? 0,
      passedTotal: (json['passed_total'] as int?) ?? 0,
      failedTotal: (json['failed_total'] as int?) ?? 0,
      passRatePercent: ((json['pass_rate_percent'] as num?) ?? 0).toDouble(),
      defectTotal: (json['defect_total'] as int?) ?? 0,
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

class FirstArticleDispositionHistoryItem {
  const FirstArticleDispositionHistoryItem({
    required this.id,
    required this.version,
    required this.dispositionOpinion,
    required this.dispositionUsername,
    required this.dispositionAt,
    required this.recheckResult,
    required this.finalJudgment,
  });

  final int id;
  final int version;
  final String dispositionOpinion;
  final String dispositionUsername;
  final DateTime? dispositionAt;
  final String recheckResult;
  final String finalJudgment;

  factory FirstArticleDispositionHistoryItem.fromJson(
    Map<String, dynamic> json,
  ) {
    return FirstArticleDispositionHistoryItem(
      id: (json['id'] as int?) ?? 0,
      version: (json['version'] as int?) ?? 0,
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
    this.dispositionHistory = const [],
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
  final List<FirstArticleDispositionHistoryItem> dispositionHistory;

  factory FirstArticleDetail.fromJson(Map<String, dynamic> json) {
    final nestedDisposition = json['disposition'];
    FirstArticleDispositionInfo? disposition;
    if (nestedDisposition is Map) {
      disposition = FirstArticleDispositionInfo.fromJson(
        Map<String, dynamic>.from(nestedDisposition),
      );
    } else {
      final flatDispositionOpinion = json['disposition_opinion'] as String?;
      final flatDispositionUsername = json['disposition_username'] as String?;
      final flatRecheckResult = json['recheck_result'] as String?;
      final flatFinalJudgment = json['final_judgment'] as String?;
      final flatDispositionAt = _parseDateTimeOrNull(json['disposition_at']);
      final hasFlatDisposition =
          (flatDispositionOpinion != null &&
              flatDispositionOpinion.isNotEmpty) ||
          (flatDispositionUsername != null &&
              flatDispositionUsername.isNotEmpty) ||
          (flatRecheckResult != null && flatRecheckResult.isNotEmpty) ||
          (flatFinalJudgment != null && flatFinalJudgment.isNotEmpty) ||
          flatDispositionAt != null;
      if (hasFlatDisposition) {
        disposition = FirstArticleDispositionInfo(
          dispositionOpinion: flatDispositionOpinion ?? '',
          dispositionUsername: flatDispositionUsername ?? '',
          dispositionAt: flatDispositionAt,
          recheckResult: flatRecheckResult ?? '',
          finalJudgment: flatFinalJudgment ?? '',
        );
      }
    }

    return FirstArticleDetail(
      id: (json['id'] as int?) ?? 0,
      verificationCode: (json['verification_code'] as String?) ?? '',
      productionOrderId:
          (json['production_order_id'] as int?) ?? (json['order_id'] as int?),
      productionOrderCode:
          (json['production_order_code'] as String?) ??
          (json['order_code'] as String?) ??
          '',
      productId: json['product_id'] as int?,
      productCode: (json['product_code'] as String?) ?? '',
      productName: (json['product_name'] as String?) ?? '',
      processId:
          (json['process_id'] as int?) ?? (json['order_process_id'] as int?),
      processName: (json['process_name'] as String?) ?? '',
      operatorUserId: json['operator_user_id'] as int?,
      operatorUsername: (json['operator_username'] as String?) ?? '',
      checkResult:
          (json['check_result'] as String?) ??
          (json['result'] as String?) ??
          '',
      defectDescription:
          (json['defect_description'] as String?) ??
          (json['remark'] as String?) ??
          '',
      checkAt:
          _parseDateTimeOrNull(json['check_at']) ??
          _parseDateTimeOrNull(json['created_at']),
      disposition: disposition,
      dispositionHistory:
          (json['disposition_history'] as List<dynamic>? ?? const [])
              .map(
                (entry) => FirstArticleDispositionHistoryItem.fromJson(
                  entry as Map<String, dynamic>,
                ),
              )
              .toList(),
    );
  }
}

class DefectTopItem {
  DefectTopItem({
    required this.phenomenon,
    required this.quantity,
    required this.ratio,
  });

  final String phenomenon;
  final int quantity;
  final double ratio;

  factory DefectTopItem.fromJson(Map<String, dynamic> json) {
    return DefectTopItem(
      phenomenon: (json['phenomenon'] as String?) ?? '',
      quantity: (json['quantity'] as int?) ?? 0,
      ratio: ((json['ratio'] as num?) ?? 0).toDouble(),
    );
  }
}

class DefectReasonItem {
  DefectReasonItem({
    required this.reason,
    required this.quantity,
    required this.ratio,
  });

  final String reason;
  final int quantity;
  final double ratio;

  factory DefectReasonItem.fromJson(Map<String, dynamic> json) {
    return DefectReasonItem(
      reason: (json['reason'] as String?) ?? '',
      quantity: (json['quantity'] as int?) ?? 0,
      ratio: ((json['ratio'] as num?) ?? 0).toDouble(),
    );
  }
}

class DefectByProcessItem {
  DefectByProcessItem({
    required this.processCode,
    required this.processName,
    required this.quantity,
  });

  final String processCode;
  final String? processName;
  final int quantity;

  factory DefectByProcessItem.fromJson(Map<String, dynamic> json) {
    return DefectByProcessItem(
      processCode: (json['process_code'] as String?) ?? '',
      processName: json['process_name'] as String?,
      quantity: (json['quantity'] as int?) ?? 0,
    );
  }
}

class DefectByProductItem {
  DefectByProductItem({
    required this.productId,
    required this.productName,
    required this.quantity,
  });

  final int? productId;
  final String? productName;
  final int quantity;

  factory DefectByProductItem.fromJson(Map<String, dynamic> json) {
    return DefectByProductItem(
      productId: json['product_id'] as int?,
      productName: json['product_name'] as String?,
      quantity: (json['quantity'] as int?) ?? 0,
    );
  }
}

class DefectByOperatorItem {
  DefectByOperatorItem({
    required this.operatorUserId,
    required this.operatorUsername,
    required this.quantity,
  });

  final int? operatorUserId;
  final String? operatorUsername;
  final int quantity;

  factory DefectByOperatorItem.fromJson(Map<String, dynamic> json) {
    return DefectByOperatorItem(
      operatorUserId: json['operator_user_id'] as int?,
      operatorUsername: json['operator_username'] as String?,
      quantity: (json['quantity'] as int?) ?? 0,
    );
  }
}

class DefectByDateItem {
  DefectByDateItem({required this.date, required this.quantity});

  final String date;
  final int quantity;

  factory DefectByDateItem.fromJson(Map<String, dynamic> json) {
    return DefectByDateItem(
      date: (json['date'] as String?) ?? (json['stat_date'] as String?) ?? '',
      quantity: (json['quantity'] as int?) ?? 0,
    );
  }
}

class DefectAnalysisResult {
  DefectAnalysisResult({
    required this.totalDefectQuantity,
    required this.topDefects,
    required this.topReasons,
    required this.productQualityComparison,
    required this.byProcess,
    required this.byProduct,
    required this.byOperator,
    required this.byDate,
  });

  final int totalDefectQuantity;
  final List<DefectTopItem> topDefects;
  final List<DefectReasonItem> topReasons;
  final List<QualityProductStatItem> productQualityComparison;
  final List<DefectByProcessItem> byProcess;
  final List<DefectByProductItem> byProduct;
  final List<DefectByOperatorItem> byOperator;
  final List<DefectByDateItem> byDate;

  factory DefectAnalysisResult.fromJson(Map<String, dynamic> json) {
    return DefectAnalysisResult(
      totalDefectQuantity: (json['total_defect_quantity'] as int?) ?? 0,
      topDefects: (json['top_defects'] as List? ?? [])
          .map((e) => DefectTopItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      topReasons: (json['top_reasons'] as List? ?? [])
          .map((e) => DefectReasonItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      productQualityComparison:
          (json['product_quality_comparison'] as List? ?? [])
              .map(
                (e) =>
                    QualityProductStatItem.fromJson(e as Map<String, dynamic>),
              )
              .toList(),
      byProcess: (json['by_process'] as List? ?? [])
          .map((e) => DefectByProcessItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      byProduct: (json['by_product'] as List? ?? [])
          .map((e) => DefectByProductItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      byOperator: (json['by_operator'] as List? ?? [])
          .map((e) => DefectByOperatorItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      byDate: (json['by_date'] as List? ?? [])
          .map((e) => DefectByDateItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
