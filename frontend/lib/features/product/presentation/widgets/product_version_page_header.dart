import 'package:flutter/material.dart';
import 'package:mes_client/core/ui/patterns/mes_refresh_page_header.dart';

class ProductVersionPageHeader extends StatelessWidget {
  const ProductVersionPageHeader({
    super.key,
    required this.loading,
    required this.onRefresh,
    required this.hasDraft,
  });

  final bool loading;
  final VoidCallback onRefresh;
  final bool hasDraft;

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: const ValueKey('product-version-page-header'),
      child: MesRefreshPageHeader(
        onRefresh: loading ? null : onRefresh,
        leading: hasDraft
            ? Container(
                key: const ValueKey('product-version-header-warning'),
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFF6C68A)),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      size: 18,
                      color: Color(0xFFB97100),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '已存在草稿版本，请先完成或删除当前草稿后再新建版本。',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Color(0xFFB97100),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            : const SizedBox.shrink(),
      ),
    );
  }
}
