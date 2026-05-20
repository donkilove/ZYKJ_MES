import 'package:flutter/material.dart';

import 'package:mes_client/core/ui/patterns/mes_dialog.dart';
import 'package:mes_client/core/ui/patterns/mes_locked_form_dialog.dart';
import 'package:mes_client/features/production/models/defect_catalog.dart';
import 'package:mes_client/features/production/models/production_models.dart';

class ProductionRepairReturnProcessOption {
  const ProductionRepairReturnProcessOption({
    required this.id,
    required this.code,
    required this.name,
  });

  final int id;
  final String code;
  final String name;
}

class ProductionRepairCompleteDialogResult {
  const ProductionRepairCompleteDialogResult({
    required this.causeItems,
    required this.scrapReplenished,
    required this.returnAllocations,
  });

  final List<RepairCauseItemInput> causeItems;
  final bool scrapReplenished;
  final List<RepairReturnAllocationInput> returnAllocations;
}

Future<ProductionRepairCompleteDialogResult?>
showProductionRepairCompleteDialog({
  required BuildContext context,
  required RepairOrderItem repairOrder,
  required List<RepairOrderPhenomenonSummaryItem> phenomena,
  required List<ProductionRepairReturnProcessOption> processOptions,
}) {
  return showMesLockedFormDialog<ProductionRepairCompleteDialogResult?>(
    context: context,
    wrapMesDialog: false,
    builder: (dialogContext) {
      return ProductionRepairCompleteDialog(
        repairOrder: repairOrder,
        phenomena: phenomena,
        processOptions: processOptions,
      );
    },
  );
}

class ProductionRepairCompleteDialog extends StatefulWidget {
  const ProductionRepairCompleteDialog({
    super.key,
    required this.repairOrder,
    required this.phenomena,
    required this.processOptions,
  });

  final RepairOrderItem repairOrder;
  final List<RepairOrderPhenomenonSummaryItem> phenomena;
  final List<ProductionRepairReturnProcessOption> processOptions;

  @override
  State<ProductionRepairCompleteDialog> createState() =>
      _ProductionRepairCompleteDialogState();
}

class _ProductionRepairCompleteDialogState
    extends State<ProductionRepairCompleteDialog> {
  static const double _dialogWidth = 1080;

  final List<_RepairCauseDraft> _causeDrafts = <_RepairCauseDraft>[];
  late final List<_ReturnAllocationDraft> _allocationDrafts;
  late final Map<String, int> _phenomenonTargets;
  late final List<String> _phenomenonOptions;
  bool _scrapReplenished = false;
  String _dialogError = '';

  @override
  void initState() {
    super.initState();
    _phenomenonTargets = _buildPhenomenonTargets();
    _phenomenonOptions = _buildPhenomenonOptions();
    if (_phenomenonTargets.isNotEmpty) {
      for (final entry in _phenomenonTargets.entries) {
        _causeDrafts.add(
          _RepairCauseDraft(
            phenomenon: entry.key,
            quantity: entry.value,
            reasonCategory: _defaultReasonCategory,
            reason: _defaultReason(_defaultReasonCategory),
          ),
        );
      }
    } else {
      _causeDrafts.add(
        _RepairCauseDraft(
          phenomenon: _defaultPhenomenon,
          reasonCategory: _defaultReasonCategory,
          reason: _defaultReason(_defaultReasonCategory),
        ),
      );
    }
    _allocationDrafts = widget.processOptions.isNotEmpty
        ? <_ReturnAllocationDraft>[
            _ReturnAllocationDraft(
              targetProcessId: widget.processOptions.first.id,
              quantity: widget.repairOrder.repairQuantity,
            ),
          ]
        : <_ReturnAllocationDraft>[];
  }

  @override
  void dispose() {
    for (final draft in _causeDrafts) {
      draft.dispose();
    }
    for (final draft in _allocationDrafts) {
      draft.dispose();
    }
    super.dispose();
  }

  Map<String, int> _buildPhenomenonTargets() {
    final targets = <String, int>{};
    for (final entry in widget.phenomena) {
      final phenomenon = entry.phenomenon.trim();
      if (phenomenon.isEmpty || entry.quantity <= 0) {
        continue;
      }
      targets[phenomenon] = (targets[phenomenon] ?? 0) + entry.quantity;
    }
    return targets;
  }

  List<String> _buildPhenomenonOptions() {
    final options = <String>[];
    for (final entry in widget.phenomena) {
      final phenomenon = entry.phenomenon.trim();
      if (phenomenon.isNotEmpty && !options.contains(phenomenon)) {
        options.add(phenomenon);
      }
    }
    for (final phenomenon in productionDefectPhenomena) {
      if (!options.contains(phenomenon)) {
        options.add(phenomenon);
      }
    }
    return options.isEmpty ? <String>['未归类'] : options;
  }

  String get _defaultPhenomenon {
    if (_phenomenonTargets.isNotEmpty) {
      return _phenomenonTargets.keys.first;
    }
    return _phenomenonOptions.first;
  }

  String get _defaultReasonCategory => productionDefectReasonCategories().first;

  String _defaultReason(String category) {
    final reasons = productionDefectReasonsForCategory(category);
    return reasons.isEmpty ? '' : reasons.first;
  }

  bool get _hasScrap => _causeDrafts.any((draft) => draft.isScrap);

  void _addCauseRow() {
    setState(() {
      _causeDrafts.add(
        _RepairCauseDraft(
          phenomenon: _defaultPhenomenon,
          reasonCategory: _defaultReasonCategory,
          reason: _defaultReason(_defaultReasonCategory),
        ),
      );
    });
  }

  void _removeCauseRow(int index) {
    if (_causeDrafts.length <= 1) {
      return;
    }
    setState(() {
      final removed = _causeDrafts.removeAt(index);
      removed.dispose();
      if (!_hasScrap) {
        _scrapReplenished = false;
      }
    });
  }

  void _addAllocation() {
    if (widget.processOptions.isEmpty) {
      return;
    }
    setState(() {
      _allocationDrafts.add(
        _ReturnAllocationDraft(targetProcessId: widget.processOptions.first.id),
      );
    });
  }

  void _removeAllocation(int index) {
    if (_allocationDrafts.length <= 1) {
      return;
    }
    setState(() {
      final removed = _allocationDrafts.removeAt(index);
      removed.dispose();
    });
  }

  void _submit() {
    final causeItems = <RepairCauseItemInput>[];
    final actualByPhenomenon = <String, int>{};
    var total = 0;
    var scrapTotal = 0;
    for (final draft in _causeDrafts) {
      final phenomenon = draft.phenomenon.trim();
      final reason = draft.reason.trim();
      final quantity = int.tryParse(draft.quantityController.text.trim());
      if (phenomenon.isEmpty ||
          reason.isEmpty ||
          quantity == null ||
          quantity <= 0) {
        setState(() {
          _dialogError = '请为每条原因填写不良现象、维修原因和正整数数量';
        });
        return;
      }
      causeItems.add(
        RepairCauseItemInput(
          phenomenon: phenomenon,
          reason: reason,
          quantity: quantity,
          isScrap: draft.isScrap,
        ),
      );
      actualByPhenomenon[phenomenon] =
          (actualByPhenomenon[phenomenon] ?? 0) + quantity;
      total += quantity;
      if (draft.isScrap) {
        scrapTotal += quantity;
      }
    }
    if (_phenomenonTargets.isNotEmpty) {
      final extra = actualByPhenomenon.keys
          .where((name) => !_phenomenonTargets.containsKey(name))
          .toList();
      if (extra.isNotEmpty) {
        setState(() {
          _dialogError = '存在未匹配送修记录的不良现象：${extra.join('、')}';
        });
        return;
      }
      final mismatch = <String>[];
      for (final entry in _phenomenonTargets.entries) {
        final current = actualByPhenomenon[entry.key] ?? 0;
        if (current != entry.value) {
          mismatch.add('${entry.key} 需 ${entry.value}，当前 $current');
        }
      }
      if (mismatch.isNotEmpty) {
        setState(() {
          _dialogError = '不良现象数量需与送修明细一致：${mismatch.join('；')}';
        });
        return;
      }
    }
    if (total != widget.repairOrder.repairQuantity) {
      setState(() {
        _dialogError = '原因数量合计必须等于送修数量 ${widget.repairOrder.repairQuantity}';
      });
      return;
    }

    final unreplenishedScrapQuantity = _scrapReplenished ? 0 : scrapTotal;
    final repairedQuantity =
        widget.repairOrder.repairQuantity - unreplenishedScrapQuantity;
    final allocations = <RepairReturnAllocationInput>[];
    if (repairedQuantity > 0) {
      if (_allocationDrafts.isEmpty) {
        setState(() {
          _dialogError = '存在有效回流数量时必须至少配置一条回流分配';
        });
        return;
      }
      final seenTargets = <int>{};
      var allocationTotal = 0;
      for (final draft in _allocationDrafts) {
        final targetProcessId = draft.targetProcessId;
        final allocationQty = int.tryParse(
          draft.quantityController.text.trim(),
        );
        if (targetProcessId == null ||
            allocationQty == null ||
            allocationQty <= 0) {
          setState(() {
            _dialogError = '请为每条回流分配填写目标工序和正整数数量';
          });
          return;
        }
        if (!seenTargets.add(targetProcessId)) {
          setState(() {
            _dialogError = '回流目标工序不可重复，请合并相同目标的数量';
          });
          return;
        }
        allocationTotal += allocationQty;
        allocations.add(
          RepairReturnAllocationInput(
            targetOrderProcessId: targetProcessId,
            quantity: allocationQty,
          ),
        );
      }
      if (allocationTotal != repairedQuantity) {
        setState(() {
          _dialogError =
              '回流数量合计必须等于送修数量 ${widget.repairOrder.repairQuantity}'
              ' - 未补充报废数量 $unreplenishedScrapQuantity = $repairedQuantity';
        });
        return;
      }
    }

    Navigator.of(context).pop(
      ProductionRepairCompleteDialogResult(
        causeItems: causeItems,
        scrapReplenished: scrapTotal > 0 && _scrapReplenished,
        returnAllocations: allocations,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MesDialog(
      title: Text('完成维修 - ${widget.repairOrder.repairOrderCode}'),
      width: _dialogWidth,
      content: SizedBox(
        key: const ValueKey('production-repair-complete-dialog'),
        width: _dialogWidth,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('送修数量：${widget.repairOrder.repairQuantity}'),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text('不良原因明细'),
                  const Spacer(),
                  OutlinedButton.icon(
                    onPressed: _addCauseRow,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('新增原因项'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...List.generate(_causeDrafts.length, (index) {
                final draft = _causeDrafts[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: DropdownButtonFormField<String>(
                          key: ValueKey(
                            'production-repair-cause-phenomenon-$index',
                          ),
                          initialValue: draft.phenomenon,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: '不良现象',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          items: _phenomenonOptions
                              .map(
                                (value) => DropdownMenuItem<String>(
                                  value: value,
                                  child: Text(value),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value == null) {
                              return;
                            }
                            setState(() {
                              draft.phenomenon = value;
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 3,
                        child: DropdownButtonFormField<String>(
                          key: ValueKey(
                            'production-repair-cause-category-$index',
                          ),
                          initialValue: draft.reasonCategory,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: '一级原因',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          items: productionDefectReasonCategories()
                              .map(
                                (value) => DropdownMenuItem<String>(
                                  value: value,
                                  child: Text(value),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value == null) {
                              return;
                            }
                            setState(() {
                              draft.reasonCategory = value;
                              draft.reason = _defaultReason(value);
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 3,
                        child: DropdownButtonFormField<String>(
                          key: ValueKey(
                            'production-repair-cause-reason-$index-${draft.reasonCategory}',
                          ),
                          initialValue: draft.reason,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: '二级原因',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          items:
                              productionDefectReasonsForCategory(
                                    draft.reasonCategory,
                                  )
                                  .map(
                                    (value) => DropdownMenuItem<String>(
                                      value: value,
                                      child: Text(value),
                                    ),
                                  )
                                  .toList(),
                          onChanged: (value) {
                            if (value == null) {
                              return;
                            }
                            setState(() {
                              draft.reason = value;
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: TextField(
                          key: ValueKey(
                            'production-repair-cause-quantity-$index',
                          ),
                          controller: draft.quantityController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: '数量',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        children: [
                          Checkbox(
                            key: ValueKey(
                              'production-repair-cause-scrap-$index',
                            ),
                            value: draft.isScrap,
                            onChanged: (value) {
                              setState(() {
                                draft.isScrap = value ?? false;
                                if (!_hasScrap) {
                                  _scrapReplenished = false;
                                }
                              });
                            },
                          ),
                          const Text('报废'),
                        ],
                      ),
                      IconButton(
                        onPressed: _causeDrafts.length <= 1
                            ? null
                            : () => _removeCauseRow(index),
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 8),
              Row(
                children: [
                  Checkbox(
                    key: const ValueKey('production-repair-scrap-replenished'),
                    value: _scrapReplenished,
                    onChanged: _hasScrap
                        ? (value) {
                            setState(() {
                              _scrapReplenished = value ?? false;
                            });
                          }
                        : null,
                  ),
                  const Text('报废已补充'),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Text('回流分配（合计需等于送修数量-未补充报废数量）'),
                  const Spacer(),
                  OutlinedButton.icon(
                    onPressed: widget.processOptions.isEmpty
                        ? null
                        : _addAllocation,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('新增回流项'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (widget.processOptions.isEmpty)
                const Text('当前无可选回流工序')
              else
                ...List.generate(_allocationDrafts.length, (index) {
                  final draft = _allocationDrafts[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 4,
                          child: DropdownButtonFormField<int>(
                            initialValue: draft.targetProcessId,
                            decoration: const InputDecoration(
                              labelText: '回流目标工序',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            items: widget.processOptions
                                .map(
                                  (entry) => DropdownMenuItem<int>(
                                    value: entry.id,
                                    child: Text('${entry.code} ${entry.name}'),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              setState(() {
                                draft.targetProcessId = value;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: draft.quantityController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: '数量',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: _allocationDrafts.length <= 1
                              ? null
                              : () => _removeAllocation(index),
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ],
                    ),
                  );
                }),
              if (_dialogError.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _dialogError,
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('取消'),
        ),
        FilledButton(onPressed: _submit, child: const Text('提交完成')),
      ],
    );
  }
}

class _RepairCauseDraft {
  _RepairCauseDraft({
    required this.phenomenon,
    required this.reasonCategory,
    required this.reason,
    int? quantity,
  }) : quantityController = TextEditingController(
         text: quantity == null || quantity <= 0 ? '' : '$quantity',
       );

  String phenomenon;
  String reasonCategory;
  String reason;
  final TextEditingController quantityController;
  bool isScrap = false;

  void dispose() {
    quantityController.dispose();
  }
}

class _ReturnAllocationDraft {
  _ReturnAllocationDraft({this.targetProcessId, int? quantity})
    : quantityController = TextEditingController(
        text: quantity == null || quantity <= 0 ? '' : '$quantity',
      );

  int? targetProcessId;
  final TextEditingController quantityController;

  void dispose() {
    quantityController.dispose();
  }
}
