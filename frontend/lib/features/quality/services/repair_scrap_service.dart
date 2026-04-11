import 'package:mes_client/features/production/models/production_models.dart';

abstract class RepairScrapService {
  Future<ScrapStatisticsListResult> getScrapStatistics({
    required int page,
    required int pageSize,
    String? keyword,
    String? productName,
    String? processCode,
    String progress = 'all',
    DateTime? startDate,
    DateTime? endDate,
  });

  Future<ProductionExportResult> exportScrapStatistics({
    String? keyword,
    String? productName,
    String? processCode,
    String progress = 'all',
    DateTime? startDate,
    DateTime? endDate,
  });

  Future<ScrapStatisticsItem> getScrapStatisticsDetail({required int scrapId});

  Future<RepairOrderListResult> getRepairOrders({
    required int page,
    required int pageSize,
    String? keyword,
    String status = 'all',
    DateTime? startDate,
    DateTime? endDate,
  });

  Future<RepairOrderDetailItem> getRepairOrderDetail({
    required int repairOrderId,
  });

  Future<RepairOrderPhenomenaSummaryResult> getRepairOrderPhenomenaSummary({
    required int repairOrderId,
  });

  Future<ProductionOrderDetail> getOrderDetail({required int orderId});

  Future<RepairOrderItem> completeRepairOrder({
    required int repairOrderId,
    required List<RepairCauseItemInput> causeItems,
    required bool scrapReplenished,
    required List<RepairReturnAllocationInput> returnAllocations,
  });

  Future<ProductionExportResult> exportRepairOrders({
    String? keyword,
    String status = 'all',
    DateTime? startDate,
    DateTime? endDate,
  });
}
