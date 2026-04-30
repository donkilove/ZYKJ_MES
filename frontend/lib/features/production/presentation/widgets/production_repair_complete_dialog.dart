import 'package:flutter/material.dart';

import 'package:mes_client/core/ui/patterns/mes_dialog.dart';
import 'package:mes_client/core/ui/patterns/mes_locked_form_dialog.dart';
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
  late final List<_RepairCauseDraft> _causeDrafts;
  late final List<_ReturnAllocationDraft> _allocationDrafts;
  bool _scrapReplenished = false;
  String _dialogError = '';

  @override
  void initState() {
    super.initState();
    _causeDrafts = widget.phenomena
        .map(
          (entry) => _RepairCauseDraft(
            phenomenon: entry.phenomenon,
            quantity: entry.quantity,
          ),
        )
        .toList();
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
    var total = 0;
    var scrapTotal = 0;
    for (final draft in _causeDrafts) {
      final reason = draft.reasonController.text.trim();
      if (reason.isEmpty) {
        setState(() {
          _dialogError = '请填写每条现象的维修原因';
        });
        return;
      }
      causeItems.add(
        RepairCauseItemInput(
          phenomenon: draft.phenomenon,
          reason: reason,
          quantity: draft.quantity,
          isScrap: draft.isScrap,
        ),
      );
      total += draft.quantity;
      if (draft.isScrap) {
        scrapTotal += draft.quantity;
      }
    }
    if (total != widget.repairOrder.repairQuantity) {
      setState(() {
        _dialogError = '原因数量合计必须等于送修数量 ${widget.repairOrder.repairQuantity}';
      });
      return;
    }

    final repairedQuantity = widget.repairOrder.repairQuantity - scrapTotal;
    final allocations = <RepairReturnAllocationInput>[];
    if (repairedQuantity > 0) {
      if (_allocationDrafts.isEmpty) {
        setState(() {
          _dialogError = '存在可回流数量时必须至少配置一条回流分配';
        });
        return;
      }
      final seenTargets = <int>{};
      var allocationTotal = 0;
      for (final draft in _allocationDrafts) {
        final targetProcessId = draft.targetProcessId;
        final allocationQty = int.tryParse(draft.quantityController.text.trim());
        if (targetProcessId == null || allocationQty == null || allocationQty <= 0) {
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
          _dialogError = '回流数量合计必须等于非报废数量 $repairedQuantity';
        });
        return;
      }
    }

    Navigator.of(context).pop(
      ProductionRepairCompleteDialogResult(
        causeItems: causeItems,
        scrapReplenished: _scrapReplenished,
        returnAllocations: allocations,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MesDialog(
      title: Text('完成维修 - ${widget.repairOrder.repairOrderCode}'),
      width: 760,
      content: SizedBox(
        key: const ValueKey('production-repair-complete-dialog'),
        width: 760,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('送修数量：${widget.repairOrder.repairQuantity}'),
              const SizedBox(height: 12),
              ..._causeDrafts.map((draft) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(flex: 3, child: Text(draft.phenomenon)),
                      Expanded(
                        flex: 2,
                        child: Text('数量：${draft.quantity}'),
                      ),
                      Expanded(
                        flex: 4,
                        child: TextField(
                          controller: draft.reasonController,
                          decoration: const InputDecoration(
                            labelText: '原因',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        children: [
                          Checkbox(
                            value: draft.isScrap,
                            onChanged: (value) {
                              setState(() {
                                draft.isScrap = value ?? false;
                              });
                            },
                          ),
                          const Text('报废'),
                        ],
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 8),
              Row(
                children: [
                  Checkbox(
                    value: _scrapReplenished,
                    onChanged: (value) {
                      setState(() {
                        _scrapReplenished = value ?? false;
                      });
                    },
                  ),
                  const Text('报废已补充'),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Text('回流分配（仅对非报废数量生效）'),
                  const Spacer(),
                  OutlinedButton.icon(
                    onPressed: widget.processOptions.isEmpty ? null : _addAllocation,
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
        FilledButton(
          onPressed: _submit,
          child: const Text('提交完成'),
        ),
      ],
    );
  }
}

class _RepairCauseDraft {
  _RepairCauseDraft({required this.phenomenon, required this.quantity})
    : reasonController = TextEditingController();

  final String phenomenon;
  final int quantity;
  final TextEditingController reasonController;
  bool isScrap = false;

  void dispose() {
    reasonController.dispose();
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
