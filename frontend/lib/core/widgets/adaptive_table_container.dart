import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:mes_client/core/widgets/unified_list_table_header_style.dart';

const double _adaptiveTableResizeHandleHitWidth = 20;
const double _adaptiveTableResizeHandleVisualWidth = 4;

class AdaptiveTableContainer extends StatefulWidget {
  const AdaptiveTableContainer({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.enableUnifiedHeaderStyle = false,
    this.enableResizableColumns = true,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool enableUnifiedHeaderStyle;
  final bool enableResizableColumns;

  @override
  State<AdaptiveTableContainer> createState() => _AdaptiveTableContainerState();
}

class _AdaptiveTableContainerState extends State<AdaptiveTableContainer> {
  static const double _defaultHorizontalMargin = 24;
  static const double _defaultColumnSpacing = 56;
  static const double _defaultHeadingRowHeight = 56;
  static const double _defaultHeaderFontSize = 14;

  final ScrollController _verticalController = ScrollController();
  final ScrollController _horizontalController = ScrollController();

  List<double>? _columnWidths;
  List<double>? _minimumColumnWidths;
  double? _lastAutoAvailableWidth;
  bool _hasManualColumnResize = false;
  int? _hoveredResizeHandleIndex;
  int? _draggingResizeHandleIndex;

  @override
  void dispose() {
    _verticalController.dispose();
    _horizontalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rawDataTable = _extractDataTable(widget.child);
    if (rawDataTable != null) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final resolvedLayout = _resolveDataTableLayout(context, rawDataTable);
          final availableWidth = constraints.hasBoundedWidth
              ? constraints.maxWidth
              : 0.0;
          final columnWidths = _resolveColumnWidths(
            dataTable: rawDataTable,
            resolvedLayout: resolvedLayout,
            availableWidth: availableWidth,
          );
          final dataTable = _normalizeDataTable(
            rawDataTable,
            resolvedLayout: resolvedLayout,
            columnWidths: columnWidths,
          );
          return _buildStickyHeaderLayout(
            dataTable,
            resolvedLayout: resolvedLayout,
            columnWidths: columnWidths,
          );
        },
      );
    }
    final content = _wrapContent(context, widget.child);
    return _buildNormalLayout(content);
  }

  DataTable? _extractDataTable(Widget child) {
    if (child is DataTable) {
      return child;
    }
    if (child is SingleChildScrollView && child.child is DataTable) {
      return child.child as DataTable;
    }
    return null;
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

  _ResolvedDataTableLayout _resolveDataTableLayout(
    BuildContext context,
    DataTable dataTable,
  ) {
    final theme = Theme.of(context);
    final dataTableTheme = DataTableTheme.of(context);
    final resolvedTheme = widget.enableUnifiedHeaderStyle
        ? UnifiedListTableHeaderStyle.dataTableTheme(theme)
        : const DataTableThemeData();
    return _ResolvedDataTableLayout(
      horizontalMargin:
          dataTable.horizontalMargin ??
          resolvedTheme.horizontalMargin ??
          dataTableTheme.horizontalMargin ??
          theme.dataTableTheme.horizontalMargin ??
          _defaultHorizontalMargin,
      columnSpacing:
          dataTable.columnSpacing ??
          resolvedTheme.columnSpacing ??
          dataTableTheme.columnSpacing ??
          theme.dataTableTheme.columnSpacing ??
          _defaultColumnSpacing,
      headingRowHeight:
          dataTable.headingRowHeight ??
          resolvedTheme.headingRowHeight ??
          dataTableTheme.headingRowHeight ??
          theme.dataTableTheme.headingRowHeight ??
          _defaultHeadingRowHeight,
      checkboxHorizontalMargin:
          dataTable.checkboxHorizontalMargin ??
          resolvedTheme.checkboxHorizontalMargin ??
          dataTableTheme.checkboxHorizontalMargin ??
          theme.dataTableTheme.checkboxHorizontalMargin,
      dividerThickness:
          dataTable.dividerThickness ??
          resolvedTheme.dividerThickness ??
          dataTableTheme.dividerThickness ??
          theme.dataTableTheme.dividerThickness,
      headingTextStyle:
          dataTable.headingTextStyle ??
          resolvedTheme.headingTextStyle ??
          dataTableTheme.headingTextStyle ??
          theme.dataTableTheme.headingTextStyle ??
          theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
          ),
    );
  }

  List<double> _resolveColumnWidths({
    required DataTable dataTable,
    required _ResolvedDataTableLayout resolvedLayout,
    required double availableWidth,
  }) {
    final columnCount = dataTable.columns.length;
    final minimumWidths = _resolveMinimumColumnWidths(
      context,
      dataTable,
      resolvedLayout: resolvedLayout,
    );
    _minimumColumnWidths = minimumWidths;
    final defaultWidths = _resolveDefaultColumnWidths(
      availableWidth: availableWidth,
      horizontalMargin: resolvedLayout.horizontalMargin,
      columnSpacing: resolvedLayout.columnSpacing,
      minimumWidths: minimumWidths,
      columnCount: columnCount,
    );

    if (!widget.enableResizableColumns) {
      return defaultWidths;
    }

    final currentWidths = _columnWidths;
    if (currentWidths == null || currentWidths.length != columnCount) {
      _columnWidths = defaultWidths;
      _lastAutoAvailableWidth = availableWidth;
      _hasManualColumnResize = false;
      return defaultWidths;
    }

    if (!_hasManualColumnResize && _lastAutoAvailableWidth != availableWidth) {
      _columnWidths = defaultWidths;
      _lastAutoAvailableWidth = availableWidth;
      return defaultWidths;
    }

    _lastAutoAvailableWidth = availableWidth;
    return currentWidths
        .map(
          (width) => width < UnifiedListTableHeaderStyle.minimumColumnWidth
              ? UnifiedListTableHeaderStyle.minimumColumnWidth
              : width,
        )
        .toList(growable: false);
  }

  Widget _buildStickyHeaderLayout(
    DataTable dataTable, {
    required _ResolvedDataTableLayout resolvedLayout,
    required List<double> columnWidths,
  }) {
    final theme = Theme.of(context);
    final bodyTable = _buildBodyOnlyDataTable(dataTable);
    final stickyLayout = LayoutBuilder(
      builder: (context, constraints) {
        final horizontalConstraints = BoxConstraints(
          minWidth: constraints.hasBoundedWidth ? constraints.maxWidth : 0,
        );

        return Scrollbar(
          controller: _verticalController,
          thumbVisibility: true,
          child: CustomScrollView(
            controller: _verticalController,
            slivers: [
              SliverPersistentHeader(
                pinned: true,
                delegate: _DataTableHeaderDelegate(
                  dataTable: dataTable,
                  theme: theme,
                  resolvedLayout: resolvedLayout,
                  horizontalController: _horizontalController,
                  horizontalConstraints: horizontalConstraints,
                  columnWidths: columnWidths,
                  enableResizableColumns: widget.enableResizableColumns,
                  onColumnResize: _handleColumnResize,
                  hoveredResizeHandleIndex: _hoveredResizeHandleIndex,
                  draggingResizeHandleIndex: _draggingResizeHandleIndex,
                  onResizeHandleHoverChanged: _handleResizeHandleHoverChanged,
                  onResizeHandleDragChanged: _handleResizeHandleDragChanged,
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

  void _handleColumnResize(int columnIndex, double delta) {
    if (!widget.enableResizableColumns) {
      return;
    }
    final currentWidths = _columnWidths;
    if (currentWidths == null ||
        columnIndex < 0 ||
        columnIndex >= currentWidths.length) {
      return;
    }
    final nextWidths = List<double>.from(currentWidths, growable: false);
    final minimumWidth =
        _minimumColumnWidths != null &&
            columnIndex < _minimumColumnWidths!.length
        ? _minimumColumnWidths![columnIndex]
        : UnifiedListTableHeaderStyle.minimumColumnWidth;
    final nextWidth = math.max(minimumWidth, nextWidths[columnIndex] + delta);
    if (nextWidth == nextWidths[columnIndex]) {
      return;
    }
    setState(() {
      nextWidths[columnIndex] = nextWidth;
      _columnWidths = nextWidths;
      _hasManualColumnResize = true;
    });
  }

  void _handleResizeHandleHoverChanged(int? columnIndex) {
    if (_hoveredResizeHandleIndex == columnIndex) {
      return;
    }
    setState(() {
      _hoveredResizeHandleIndex = columnIndex;
    });
  }

  void _handleResizeHandleDragChanged(int? columnIndex) {
    if (_draggingResizeHandleIndex == columnIndex) {
      return;
    }
    setState(() {
      _draggingResizeHandleIndex = columnIndex;
      if (columnIndex != null) {
        _hoveredResizeHandleIndex = columnIndex;
      }
    });
  }

  DataTable _normalizeDataTable(
    DataTable dataTable, {
    required _ResolvedDataTableLayout resolvedLayout,
    required List<double> columnWidths,
  }) {
    return DataTable(
      key: dataTable.key,
      columns: dataTable.columns
          .asMap()
          .entries
          .map((entry) {
            final index = entry.key;
            final column = entry.value;
            return UnifiedListTableHeaderStyle.normalizeColumn(
              column,
              columnWidth: FixedColumnWidth(columnWidths[index]),
            );
          })
          .toList(growable: false),
      rows: dataTable.rows
          .map(
            (row) => DataRow(
              key: row.key,
              selected: row.selected,
              onSelectChanged: row.onSelectChanged,
              onLongPress: row.onLongPress,
              color: row.color,
              mouseCursor: row.mouseCursor,
              cells: row.cells
                  .map(UnifiedListTableHeaderStyle.normalizeCell)
                  .toList(growable: false),
            ),
          )
          .toList(growable: false),
      sortColumnIndex: dataTable.sortColumnIndex,
      sortAscending: dataTable.sortAscending,
      onSelectAll: dataTable.onSelectAll,
      decoration: dataTable.decoration,
      dataRowColor: dataTable.dataRowColor,
      dataRowMinHeight: UnifiedListTableHeaderStyle.defaultDataRowMinHeight,
      dataRowMaxHeight: UnifiedListTableHeaderStyle.defaultDataRowMaxHeight,
      dataTextStyle: dataTable.dataTextStyle,
      headingRowColor: dataTable.headingRowColor,
      headingRowHeight: resolvedLayout.headingRowHeight,
      headingTextStyle: dataTable.headingTextStyle,
      horizontalMargin: resolvedLayout.horizontalMargin,
      columnSpacing: resolvedLayout.columnSpacing,
      showCheckboxColumn: dataTable.showCheckboxColumn,
      showBottomBorder: dataTable.showBottomBorder,
      dividerThickness: resolvedLayout.dividerThickness,
      checkboxHorizontalMargin: resolvedLayout.checkboxHorizontalMargin,
      border: dataTable.border,
      clipBehavior: dataTable.clipBehavior,
    );
  }

  List<double> _resolveDefaultColumnWidths({
    required double availableWidth,
    required double? horizontalMargin,
    required double? columnSpacing,
    required List<double> minimumWidths,
    required int columnCount,
  }) {
    if (columnCount <= 0 || availableWidth <= 0) {
      return minimumWidths;
    }
    final resolvedHorizontalMargin =
        horizontalMargin ?? _defaultHorizontalMargin;
    final resolvedColumnSpacing = columnSpacing ?? _defaultColumnSpacing;
    final spacingWidth = columnCount > 1
        ? resolvedColumnSpacing * (columnCount - 1)
        : 0.0;
    final usableWidth =
        availableWidth - (resolvedHorizontalMargin * 2) - spacingWidth;
    final totalMinimumWidth = minimumWidths.fold<double>(
      0,
      (sum, width) => sum + width,
    );
    if (usableWidth <= totalMinimumWidth) {
      return minimumWidths;
    }
    final extraWidthPerColumn = (usableWidth - totalMinimumWidth) / columnCount;
    return minimumWidths
        .map((width) => width + extraWidthPerColumn)
        .toList(growable: false);
  }

  List<double> _resolveMinimumColumnWidths(
    BuildContext context,
    DataTable dataTable, {
    required _ResolvedDataTableLayout resolvedLayout,
  }) {
    return dataTable.columns
        .map(
          (column) => _resolveMinimumColumnWidth(
            context,
            column,
            resolvedLayout: resolvedLayout,
          ),
        )
        .toList(growable: false);
  }

  double _resolveMinimumColumnWidth(
    BuildContext context,
    DataColumn column, {
    required _ResolvedDataTableLayout resolvedLayout,
  }) {
    final labelText = _extractPlainTextFromWidget(column.label);
    if (labelText == null || labelText.trim().isEmpty) {
      return UnifiedListTableHeaderStyle.minimumColumnWidth;
    }
    final textStyle =
        _extractTextStyleFromWidget(column.label) ??
        resolvedLayout.headingTextStyle ??
        const TextStyle(fontSize: _defaultHeaderFontSize);
    final textPainter = TextPainter(
      text: TextSpan(text: labelText, style: textStyle),
      maxLines: 1,
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.maybeTextScalerOf(context) ?? TextScaler.noScaling,
    )..layout();
    final safePadding = UnifiedListTableHeaderStyle.headerHorizontalPadding * 2;
    final measuredWidth = textPainter.width + safePadding;
    return math.max(
      UnifiedListTableHeaderStyle.minimumColumnWidth,
      measuredWidth,
    );
  }

  String? _extractPlainTextFromWidget(Widget widget) {
    if (widget is Text) {
      return widget.data ?? widget.textSpan?.toPlainText();
    }
    if (widget is Tooltip) {
      final child = widget.child;
      if (child != null) {
        final childText = _extractPlainTextFromWidget(child);
        if (childText != null && childText.isNotEmpty) {
          return childText;
        }
      }
      return widget.message;
    }
    if (widget is Flexible) {
      final child = widget.child;
      if (child != null) {
        return _extractPlainTextFromWidget(child);
      }
    }
    if (widget is Expanded) {
      final child = widget.child;
      if (child != null) {
        return _extractPlainTextFromWidget(child);
      }
    }
    if (widget is Align) {
      final child = widget.child;
      if (child != null) {
        return _extractPlainTextFromWidget(child);
      }
    }
    if (widget is Padding) {
      final child = widget.child;
      if (child != null) {
        return _extractPlainTextFromWidget(child);
      }
    }
    return null;
  }

  TextStyle? _extractTextStyleFromWidget(Widget widget) {
    if (widget is Text) {
      return widget.style;
    }
    if (widget is Tooltip) {
      final child = widget.child;
      if (child != null) {
        return _extractTextStyleFromWidget(child);
      }
    }
    if (widget is Flexible) {
      final child = widget.child;
      if (child != null) {
        return _extractTextStyleFromWidget(child);
      }
    }
    if (widget is Expanded) {
      final child = widget.child;
      if (child != null) {
        return _extractTextStyleFromWidget(child);
      }
    }
    if (widget is Align) {
      final child = widget.child;
      if (child != null) {
        return _extractTextStyleFromWidget(child);
      }
    }
    if (widget is Padding) {
      final child = widget.child;
      if (child != null) {
        return _extractTextStyleFromWidget(child);
      }
    }
    return null;
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
    required this.resolvedLayout,
    required this.horizontalController,
    required this.horizontalConstraints,
    required this.columnWidths,
    required this.enableResizableColumns,
    required this.onColumnResize,
    required this.hoveredResizeHandleIndex,
    required this.draggingResizeHandleIndex,
    required this.onResizeHandleHoverChanged,
    required this.onResizeHandleDragChanged,
  });

  final DataTable dataTable;
  final ThemeData theme;
  final _ResolvedDataTableLayout resolvedLayout;
  final ScrollController horizontalController;
  final BoxConstraints horizontalConstraints;
  final List<double> columnWidths;
  final bool enableResizableColumns;
  final void Function(int columnIndex, double delta) onColumnResize;
  final int? hoveredResizeHandleIndex;
  final int? draggingResizeHandleIndex;
  final ValueChanged<int?> onResizeHandleHoverChanged;
  final ValueChanged<int?> onResizeHandleDragChanged;

  @override
  double get maxExtent => resolvedLayout.headingRowHeight;

  @override
  double get minExtent => resolvedLayout.headingRowHeight;

  @override
  bool shouldRebuild(covariant _DataTableHeaderDelegate oldDelegate) {
    return dataTable != oldDelegate.dataTable ||
        theme != oldDelegate.theme ||
        resolvedLayout != oldDelegate.resolvedLayout ||
        horizontalController != oldDelegate.horizontalController ||
        horizontalConstraints != oldDelegate.horizontalConstraints ||
        columnWidths != oldDelegate.columnWidths ||
        enableResizableColumns != oldDelegate.enableResizableColumns ||
        hoveredResizeHandleIndex != oldDelegate.hoveredResizeHandleIndex ||
        draggingResizeHandleIndex != oldDelegate.draggingResizeHandleIndex;
  }

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final tableWidth = _calculateTableWidth();
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
        ),
        child: ListenableBuilder(
          listenable: horizontalController,
          builder: (context, _) {
            final offset = horizontalController.hasClients
                ? horizontalController.offset
                : 0.0;
            return ClipRect(
              child: Stack(
                children: [
                  Transform.translate(
                    offset: Offset(-offset, 0),
                    child: SizedBox(
                      width: tableWidth,
                      child: DataTable(
                        columnSpacing: resolvedLayout.columnSpacing,
                        dataRowMinHeight: 0,
                        dataRowMaxHeight: 0,
                        headingRowHeight: resolvedLayout.headingRowHeight,
                        horizontalMargin: resolvedLayout.horizontalMargin,
                        checkboxHorizontalMargin:
                            resolvedLayout.checkboxHorizontalMargin,
                        dividerThickness: resolvedLayout.dividerThickness,
                        columns: dataTable.columns,
                        rows: const [],
                      ),
                    ),
                  ),
                  if (enableResizableColumns)
                    Transform.translate(
                      offset: Offset(-offset, 0),
                      child: SizedBox(
                        width: math.max(
                          tableWidth,
                          horizontalConstraints.minWidth,
                        ),
                        height: resolvedLayout.headingRowHeight,
                        child: Stack(children: _buildResizeHandles()),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  List<Widget> _buildResizeHandles() {
    if (columnWidths.isEmpty) {
      return const [];
    }
    final handles = <Widget>[];
    var currentLeft = resolvedLayout.horizontalMargin;
    final lastIndex = columnWidths.length - 1;
    for (var index = 0; index < columnWidths.length; index += 1) {
      currentLeft += columnWidths[index];
      final isActive =
          hoveredResizeHandleIndex == index ||
          draggingResizeHandleIndex == index;
      final trailingGap = index == lastIndex
          ? resolvedLayout.horizontalMargin
          : resolvedLayout.columnSpacing;
      final handleCenter = currentLeft + (trailingGap / 2);
      final left = math.max(
        0.0,
        handleCenter - (_adaptiveTableResizeHandleHitWidth / 2),
      );
      handles.add(
        Positioned(
          key: ValueKey('adaptive-table-resize-handle-$index'),
          left: left,
          top: 0,
          bottom: 0,
          width: _adaptiveTableResizeHandleHitWidth,
          child: MouseRegion(
            cursor: SystemMouseCursors.resizeColumn,
            onEnter: (_) => onResizeHandleHoverChanged(index),
            onExit: (_) {
              if (draggingResizeHandleIndex != index) {
                onResizeHandleHoverChanged(null);
              }
            },
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onHorizontalDragStart: (_) => onResizeHandleDragChanged(index),
              onHorizontalDragUpdate: (details) =>
                  onColumnResize(index, details.delta.dx),
              onHorizontalDragEnd: (_) {
                onResizeHandleDragChanged(null);
                onResizeHandleHoverChanged(null);
              },
              onHorizontalDragCancel: () {
                onResizeHandleDragChanged(null);
                onResizeHandleHoverChanged(null);
              },
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  width: isActive
                      ? _adaptiveTableResizeHandleVisualWidth
                      : _adaptiveTableResizeHandleVisualWidth - 1,
                  height: isActive ? 18 : 14,
                  margin: const EdgeInsets.only(bottom: 6),
                  decoration: BoxDecoration(
                    color: isActive
                        ? theme.colorScheme.outline
                        : theme.colorScheme.outlineVariant.withValues(
                            alpha: 0.55,
                          ),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      currentLeft += resolvedLayout.columnSpacing;
    }
    return handles;
  }

  double _calculateTableWidth() {
    if (columnWidths.isEmpty) {
      return 0;
    }
    final spacingWidth = columnWidths.length > 1
        ? resolvedLayout.columnSpacing * (columnWidths.length - 1)
        : 0.0;
    return (resolvedLayout.horizontalMargin * 2) +
        columnWidths.fold<double>(0, (sum, width) => sum + width) +
        spacingWidth;
  }
}

class _ResolvedDataTableLayout {
  const _ResolvedDataTableLayout({
    required this.horizontalMargin,
    required this.columnSpacing,
    required this.headingRowHeight,
    this.checkboxHorizontalMargin,
    this.dividerThickness,
    this.headingTextStyle,
  });

  final double horizontalMargin;
  final double columnSpacing;
  final double headingRowHeight;
  final double? checkboxHorizontalMargin;
  final double? dividerThickness;
  final TextStyle? headingTextStyle;
}
