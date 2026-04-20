import 'package:flutter/material.dart';
import 'package:mes_client/core/ui/patterns/mes_pagination_bar.dart';

class SimplePaginationBar extends StatelessWidget {
  const SimplePaginationBar({
    super.key,
    required this.page,
    required this.totalPages,
    required this.total,
    required this.loading,
    this.showTotal = true,
    this.onPrevious,
    this.onNext,
  });

  final int page;
  final int totalPages;
  final int total;
  final bool loading;
  final bool showTotal;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    return MesPaginationBar(
      page: page,
      totalPages: totalPages,
      total: total,
      loading: loading,
      showTotal: showTotal,
      onPrevious: onPrevious,
      onNext: onNext,
    );
  }
}
