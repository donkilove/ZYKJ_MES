import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/models/quality_models.dart';

void main() {
  test('quality label helpers map known codes and preserve unknown codes', () {
    expect(firstArticleResultLabel('passed'), isNot('passed'));
    expect(firstArticleResultLabel('failed'), isNot('failed'));
    expect(firstArticleResultLabel('custom'), 'custom');

    expect(verificationCodeSourceLabel('stored'), isNot('stored'));
    expect(verificationCodeSourceLabel('default'), isNot('default'));
    expect(verificationCodeSourceLabel('none'), isNot('none'));
    expect(verificationCodeSourceLabel('manual'), 'manual');
  });

  test('FirstArticleListItem applies fallbacks for invalid date values', () {
    final item = FirstArticleListItem.fromJson({
      'id': 5,
      'order_id': 11,
      'order_code': 'PO-1',
      'product_id': 6,
      'product_name': '产品A',
      'order_process_id': 22,
      'process_code': '01-01',
      'process_name': '切割',
      'operator_user_id': 33,
      'operator_username': 'op',
      'result': 'passed',
      'verification_date': 'invalid-date',
      'remark': 'ok',
      'created_at': '',
    });

    expect(item.id, 5);
    expect(item.verificationDate, DateTime(1970, 1, 1));
    expect(item.createdAt, DateTime(1970, 1, 1));
  });

  test('FirstArticleListResult parses list and defaults query date', () {
    final before = DateTime.now();
    final result = FirstArticleListResult.fromJson({
      'verification_code': 'A100',
      'verification_code_source': 'stored',
      'total': 1,
      'items': [
        {
          'id': 1,
          'order_id': 2,
          'order_code': 'PO-2',
          'product_id': 3,
          'product_name': '产品B',
          'order_process_id': 4,
          'process_code': '01-02',
          'process_name': '焊接',
          'operator_user_id': 5,
          'operator_username': 'user',
          'result': 'failed',
          'verification_date': '2026-03-01T10:00:00Z',
          'created_at': '2026-03-01T10:05:00Z',
        },
      ],
    });
    final after = DateTime.now();

    expect(result.total, 1);
    expect(result.items.single.processName, '焊接');
    expect(
      result.queryDate.isAfter(before.subtract(const Duration(seconds: 1))),
      isTrue,
    );
    expect(
      result.queryDate.isBefore(after.add(const Duration(seconds: 1))),
      isTrue,
    );
  });

  test('quality stats models parse nullable timestamps and defaults', () {
    final overview = QualityStatsOverview.fromJson({
      'first_article_total': 5,
      'passed_total': 4,
      'failed_total': 1,
      'pass_rate_percent': 80.5,
      'covered_order_count': 3,
      'covered_process_count': 2,
      'covered_operator_count': 2,
      'latest_first_article_at': '2026-03-02T10:00:00Z',
    });
    final processStat = QualityProcessStatItem.fromJson({
      'process_code': '01-01',
      'process_name': '切割',
      'first_article_total': 2,
      'passed_total': 1,
      'failed_total': 1,
      'pass_rate_percent': 50,
      'latest_first_article_at': null,
    });
    final operatorStat = QualityOperatorStatItem.fromJson({
      'operator_user_id': 8,
      'operator_username': 'tester',
      'first_article_total': 2,
      'passed_total': 2,
      'failed_total': 0,
      'pass_rate_percent': 100,
      'latest_first_article_at': '',
    });

    expect(overview.firstArticleTotal, 5);
    expect(
      overview.latestFirstArticleAt,
      DateTime.parse('2026-03-02T10:00:00Z'),
    );
    expect(processStat.latestFirstArticleAt, isNull);
    expect(operatorStat.latestFirstArticleAt, isNull);
    expect(operatorStat.passRatePercent, 100);
  });

  test('QualityProductStatItem parses quality totals from backend', () {
    final item = QualityProductStatItem.fromJson({
      'product_id': 9,
      'product_name': '产品C',
      'first_article_total': 10,
      'passed_total': 8,
      'failed_total': 2,
      'pass_rate_percent': 80,
      'defect_total': 4,
      'scrap_total': 3,
      'repair_total': 6,
    });

    expect(item.productId, 9);
    expect(item.productName, '产品C');
    expect(item.defectTotal, 4);
    expect(item.repairTotal, 6);
  });

  test('QualityTrendItem parses stat_date field from backend', () {
    final item = QualityTrendItem.fromJson({
      'stat_date': '2026-03-01',
      'first_article_total': 4,
      'passed_total': 3,
      'failed_total': 1,
      'pass_rate_percent': 75,
      'defect_total': 5,
      'scrap_total': 2,
    });

    expect(item.date, '2026-03-01');
    expect(item.firstArticleTotal, 4);
    expect(item.defectTotal, 5);
    expect(item.scrapTotal, 2);
  });

  test('DefectAnalysisResult parses operator and date dimensions', () {
    final result = DefectAnalysisResult.fromJson({
      'total_defect_quantity': 12,
      'top_defects': [
        {'phenomenon': '虚焊', 'quantity': 6, 'ratio': 50},
      ],
      'top_reasons': [
        {'reason': '治具偏移', 'quantity': 5, 'ratio': 41.67},
      ],
      'product_quality_comparison': [
        {
          'product_id': 3,
          'product_name': '产品A',
          'first_article_total': 7,
          'passed_total': 5,
          'failed_total': 2,
          'pass_rate_percent': 71.43,
          'defect_total': 3,
          'scrap_total': 1,
          'repair_total': 4,
        },
      ],
      'by_process': [
        {'process_code': '01-01', 'process_name': '切割', 'quantity': 4},
      ],
      'by_product': [
        {'product_id': 3, 'product_name': '产品A', 'quantity': 7},
      ],
      'by_operator': [
        {'operator_user_id': 8, 'operator_username': 'worker', 'quantity': 5},
      ],
      'by_date': [
        {'stat_date': '2026-03-01', 'quantity': 9},
      ],
    });

    expect(result.byOperator.single.operatorUsername, 'worker');
    expect(result.byDate.single.date, '2026-03-01');
    expect(result.byDate.single.quantity, 9);
    expect(result.topReasons.single.reason, '治具偏移');
    expect(result.productQualityComparison.single.repairTotal, 4);
  });

  test('FirstArticleDetail parses backend detail payload fields', () {
    final detail = FirstArticleDetail.fromJson({
      'id': 88,
      'order_id': 32,
      'order_code': 'Q-ORD-88',
      'product_id': 11,
      'product_name': '产品X',
      'order_process_id': 19,
      'process_code': '61-01',
      'process_name': '外观检验',
      'operator_user_id': 7,
      'operator_username': 'quality_user',
      'result': 'failed',
      'verification_date': '2026-03-06',
      'verification_code': 'VCX',
      'template_id': 18,
      'template_name': '品质首件模板',
      'check_content': '外观、尺寸、装配确认',
      'test_value': '9.86',
      'participants': [
        {'user_id': 7, 'username': 'quality_user', 'full_name': '质检员'},
        {'user_id': 8, 'username': 'worker_b'},
      ],
      'remark': '尺寸偏差',
      'created_at': '2026-03-06T09:30:00Z',
      'disposition_opinion': '复检后返工',
      'disposition_username': 'quality_admin',
      'disposition_at': '2026-03-06T10:00:00Z',
      'recheck_result': 'failed',
      'final_judgment': 'rework',
    });

    expect(detail.id, 88);
    expect(detail.productionOrderCode, 'Q-ORD-88');
    expect(detail.checkResult, 'failed');
    expect(detail.templateId, 18);
    expect(detail.templateName, '品质首件模板');
    expect(detail.checkContent, '外观、尺寸、装配确认');
    expect(detail.testValue, '9.86');
    expect(detail.participants, hasLength(2));
    expect(detail.participants.first.displayName, 'quality_user (质检员)');
    expect(detail.defectDescription, '尺寸偏差');
    expect(detail.disposition, isNotNull);
    expect(detail.disposition!.finalJudgment, 'rework');
  });
}
