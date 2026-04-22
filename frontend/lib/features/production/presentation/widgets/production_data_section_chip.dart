import 'package:flutter/material.dart';
import 'package:mes_client/core/ui/primitives/mes_status_chip.dart';

enum ProductionDataSection { processStats, todayRealtime, operatorStats }

class ProductionDataSectionChip extends StatelessWidget {
  const ProductionDataSectionChip({
    super.key,
    required this.section,
  });

  final ProductionDataSection section;

  @override
  Widget build(BuildContext context) {
    return MesStatusChip.success(label: _label(section));
  }

  String _label(ProductionDataSection section) {
    switch (section) {
      case ProductionDataSection.processStats:
        return '工序统计';
      case ProductionDataSection.todayRealtime:
        return '今日实时产量';
      case ProductionDataSection.operatorStats:
        return '人员统计';
    }
  }
}

class ProductionDataSectionSelector extends StatelessWidget {
  const ProductionDataSectionSelector({
    super.key,
    required this.selectedSection,
    required this.onSectionChanged,
  });

  final ProductionDataSection selectedSection;
  final ValueChanged<ProductionDataSection> onSectionChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<ProductionDataSection>(
      segments: const [
        ButtonSegment(
          value: ProductionDataSection.processStats,
          label: Text('工序统计'),
        ),
        ButtonSegment(
          value: ProductionDataSection.todayRealtime,
          label: Text('今日实时产量'),
        ),
        ButtonSegment(
          value: ProductionDataSection.operatorStats,
          label: Text('人员统计'),
        ),
      ],
      selected: {selectedSection},
      onSelectionChanged: (selection) {
        onSectionChanged(selection.first);
      },
    );
  }
}

String productionDataSectionLabel(ProductionDataSection section) {
  switch (section) {
    case ProductionDataSection.processStats:
      return '工序统计';
    case ProductionDataSection.todayRealtime:
      return '今日实时产量';
    case ProductionDataSection.operatorStats:
      return '人员统计';
  }
}
