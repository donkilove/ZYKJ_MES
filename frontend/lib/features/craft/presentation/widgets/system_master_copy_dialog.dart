import 'package:flutter/material.dart';
import 'package:mes_client/core/network/api_exception.dart';
import 'package:mes_client/features/craft/services/craft_service.dart';
import 'package:mes_client/features/production/models/production_models.dart';
import 'package:mes_client/core/ui/patterns/mes_dialog.dart';

Future<bool?> showSystemMasterCopyDialog({
  required BuildContext context,
  required CraftService craftService,
  required List<ProductionProductOption> products,
  required int? initialProductId,
  required VoidCallback onLogout,
}) async {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => _SystemMasterCopyDialog(
      craftService: craftService,
      products: products,
      initialProductId: initialProductId,
      onLogout: onLogout,
    ),
  );
}

class _SystemMasterCopyDialog extends StatefulWidget {
  const _SystemMasterCopyDialog({
    required this.craftService,
    required this.products,
    required this.initialProductId,
    required this.onLogout,
  });

  final CraftService craftService;
  final List<ProductionProductOption> products;
  final int? initialProductId;
  final VoidCallback onLogout;

  @override
  State<_SystemMasterCopyDialog> createState() => _SystemMasterCopyDialogState();
}

class _SystemMasterCopyDialogState extends State<_SystemMasterCopyDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late int _selectedProductId;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: '系统母版套版');
    _selectedProductId = widget.initialProductId ?? widget.products.first.id;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);
    try {
      await widget.craftService.copySystemMasterToProduct(
        productId: _selectedProductId,
        newName: _nameController.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      if (e is ApiException && e.statusCode == 401) {
        widget.onLogout();
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('套版失败: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return MesDialog(
      title: const Text('从系统母版套版'),
      width: 480,
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer.withAlpha(50),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Theme.of(context).colorScheme.primary, size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      '将当前系统母版的工艺步骤复制到目标产品下，并生成一个新的草稿模板。',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<int>(
              initialValue: _selectedProductId,
              decoration: const InputDecoration(
                labelText: '目标产品',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.inventory_2_outlined),
              ),
              items: widget.products
                  .map((p) => DropdownMenuItem(
                        value: p.id,
                        child: Text(p.name),
                      ))
                  .toList(),
              onChanged: _submitting
                  ? null
                  : (val) {
                      if (val != null) setState(() => _selectedProductId = val);
                    },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              enabled: !_submitting,
              decoration: const InputDecoration(
                labelText: '新模板名称',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.edit_note_outlined),
              ),
              validator: (val) {
                if (val == null || val.trim().isEmpty) return '请输入名称';
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton.icon(
          onPressed: _submitting ? null : _submit,
          icon: _submitting
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.copy_rounded, size: 18),
          label: Text(_submitting ? '套版中...' : '开始套版'),
        ),
      ],
    );
  }
}
