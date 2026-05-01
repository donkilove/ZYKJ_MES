import 'package:flutter/material.dart';
import 'package:mes_client/core/widgets/unified_list_table_header_style.dart';

class AdaptiveTableContainer extends StatefulWidget {
  const AdaptiveTableContainer({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.enableUnifiedHeaderStyle = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool enableUnifiedHeaderStyle;

  @override
  State<AdaptiveTableContainer> createState() => _AdaptiveTableContainerState();
}

class _AdaptiveTableContainerState extends State<AdaptiveTableContainer> {
  final ScrollController _verticalController = ScrollController();
  final ScrollController _horizontalController = ScrollController();

  @override
  void dispose() {
    _verticalController.dispose();
    _horizontalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dataTable = widget.child is DataTable
        ? widget.child as DataTable
        : null;
    if (dataTable != null) {
      return _buildStickyHeaderLayout(dataTable);
    }
    final content = _wrapContent(context, widget.child);
    return _buildNormalLayout(content);
  }

  Widget _wrapContent(BuildContext context, Widget child) {
    if (!widget.enableUnifiedHeaderStyle) {
      return child;
    }
    return UnifiedListTableHeaderStyle.wrap(
      theme: Theme.of(context),
      child: child,
    );
  }

  Widget _buildNormalLayout(Widget content) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final verticalConstraints = BoxConstraints(
          minHeight: constraints.hasBoundedHeight ? constraints.maxHeight : 0,
        );
        final horizontalConstraints = BoxConstraints(
          minWidth: constraints.hasBoundedWidth ? constraints.maxWidth : 0,
        );

        return Scrollbar(
          controller: _verticalController,
          thumbVisibility: true,
          child: SingleChildScrollView(
            controller: _verticalController,
            padding: widget.padding,
            child: ConstrainedBox(
              constraints: verticalConstraints,
              child: Scrollbar(
                controller: _horizontalController,
                thumbVisibility: true,
                notificationPredicate: (notification) =>
                    notification.depth == 1,
                child: SingleChildScrollView(
                  controller: _horizontalController,
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: horizontalConstraints,
                    child: content,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStickyHeaderLayout(DataTable dataTable) {
    final theme = Theme.of(context);
    final bodyTable = _buildBodyOnlyDataTable(dataTable);
    final stickyLayout = LayoutBuilder(
      builder: (context, constraints) {
        final horizontalConstraints = BoxConstraints(
          minWidth: constraints.hasBoundedWidth ? constraints.maxWidth : 0,
        );

        return Scrollbar(
          thumbVisibility: true,
          child: CustomScrollView(
            slivers: [
              SliverPersistentHeader(
                pinned: true,
                delegate: _DataTableHeaderDelegate(
                  dataTable: dataTable,
                  theme: theme,
                  horizontalController: _horizontalController,
                  horizontalConstraints: horizontalConstraints,
                ),
              ),
              SliverToBoxAdapter(
                child: Scrollbar(
                  controller: _horizontalController,
                  thumbVisibility: true,
                  notificationPredicate: (n) => n.depth == 1,
                  child: SingleChildScrollView(
                    controller: _horizontalController,
                    scrollDirection: Axis.horizontal,
                    child: ConstrainedBox(
                      constraints: horizontalConstraints,
                      child: bodyTable,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
    if (!widget.enableUnifiedHeaderStyle) {
      return stickyLayout;
    }
    return DataTableTheme(
      data: UnifiedListTableHeaderStyle.dataTableTheme(theme),
      child: stickyLayout,
    );
  }

  DataTable _buildBodyOnlyDataTable(DataTable dataTable) {
    return DataTable(
      columns: dataTable.columns,
      rows: dataTable.rows,
      sortColumnIndex: dataTable.sortColumnIndex,
      sortAscending: dataTable.sortAscending,
      onSelectAll: dataTable.onSelectAll,
      decoration: dataTable.decoration,
      dataRowColor: dataTable.dataRowColor,
      dataRowMinHeight: dataTable.dataRowMinHeight,
      dataRowMaxHeight: dataTable.dataRowMaxHeight,
      dataTextStyle: dataTable.dataTextStyle,
      headingRowColor: dataTable.headingRowColor,
      headingRowHeight: 0,
      headingTextStyle: dataTable.headingTextStyle,
      horizontalMargin: dataTable.horizontalMargin,
      columnSpacing: dataTable.columnSpacing,
      showCheckboxColumn: dataTable.showCheckboxColumn,
      showBottomBorder: dataTable.showBottomBorder,
      dividerThickness: dataTable.dividerThickness,
      checkboxHorizontalMargin: dataTable.checkboxHorizontalMargin,
      border: dataTable.border,
      clipBehavior: dataTable.clipBehavior,
    );
  }
}

class _DataTableHeaderDelegate extends SliverPersistentHeaderDelegate {
  _DataTableHeaderDelegate({
    required this.dataTable,
    required this.theme,
    required this.horizontalController,
    required this.horizontalConstraints,
  });

  final DataTable dataTable;
  final ThemeData theme;
  final ScrollController horizontalController;
  final BoxConstraints horizontalConstraints;

  @override
  double get maxExtent => dataTable.headingRowHeight ?? 56;

  @override
  double get minExtent => dataTable.headingRowHeight ?? 56;

  @override
  bool shouldRebuild(covariant _DataTableHeaderDelegate oldDelegate) {
    return dataTable != oldDelegate.dataTable;
  }

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Material(
      elevation: overlapsContent ? 2 : 0,
      child: DataTableTheme(
        data: DataTableThemeData(
          headingRowColor: WidgetStatePropertyAll(
            theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.65),
          ),
          headingTextStyle: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
          ),
          horizontalMargin: dataTable.horizontalMargin,
          headingRowHeight: dataTable.headingRowHeight,
          columnSpacing: dataTable.columnSpacing,
        ),
        child: ListenableBuilder(
          listenable: horizontalController,
          builder: (context, _) {
            final offset = horizontalController.hasClients
                ? horizontalController.offset
                : 0.0;
            return ClipRect(
              child: Transform.translate(
                offset: Offset(-offset, 0),
                child: DataTable(
                  columnSpacing: dataTable.columnSpacing,
                  dataRowMinHeight: 0,
                  dataRowMaxHeight: 0,
                  headingRowHeight: dataTable.headingRowHeight,
                  horizontalMargin: dataTable.horizontalMargin,
                  columns: dataTable.columns,
                  rows: const [],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
