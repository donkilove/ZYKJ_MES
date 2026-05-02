import 'package:flutter/material.dart';

class UnifiedListTableHeaderStyle {
  const UnifiedListTableHeaderStyle._();

  static const double _headerRadius = 8;
  static const double _headerHorizontalPadding = 12;
  static const double _headerVerticalPadding = 8;
  static const double _headingRowHeight = 44;
  static const double _defaultDataRowMinHeight = 56;
  static const double _defaultDataRowMaxHeight = 72;
  static const double _actionButtonWidth = 64;
  static const double _actionButtonHeight = 28;
  static const double _actionButtonHorizontalPadding = 8;
  static const double _actionButtonVerticalPadding = 2;
  static const double _actionButtonFontSize = 12;
  static const double _actionButtonBorderRadius = 20;
  static const TableColumnWidth _uniformColumnWidth = FlexColumnWidth(1);
  static const double _minimumColumnWidth = 96;

  static double get defaultDataRowMinHeight => _defaultDataRowMinHeight;
  static double get defaultDataRowMaxHeight => _defaultDataRowMaxHeight;
  static double get defaultHeadingRowHeight => _headingRowHeight;
  static double get minimumColumnWidth => _minimumColumnWidth;
  static TableColumnWidth get uniformColumnWidth => _uniformColumnWidth;

  static DataTableThemeData dataTableTheme(ThemeData theme) {
    return DataTableThemeData(
      headingRowColor: WidgetStatePropertyAll(
        theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.65),
      ),
      headingTextStyle: theme.textTheme.bodyMedium?.copyWith(
        fontWeight: FontWeight.w600,
        color: theme.colorScheme.onSurface,
      ),
      horizontalMargin: _headerHorizontalPadding,
      headingRowHeight: _headingRowHeight,
    );
  }

  static Widget wrap({required ThemeData theme, required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(_headerRadius),
      child: DataTableTheme(data: dataTableTheme(theme), child: child),
    );
  }

  static Widget headerLabel(
    BuildContext context,
    String text, {
    TextAlign textAlign = TextAlign.start,
  }) {
    final theme = Theme.of(context);
    return Align(
      alignment: _alignmentForTextAlign(textAlign),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: _headerVerticalPadding),
        child: Text(
          text,
          textAlign: textAlign,
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
          softWrap: false,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  static Widget cellContent(
    Widget child, {
    TextAlign textAlign = TextAlign.start,
  }) {
    return Align(alignment: _alignmentForTextAlign(textAlign), child: child);
  }

  static DataColumn column(
    BuildContext context,
    String text, {
    TextAlign textAlign = TextAlign.start,
  }) {
    return DataColumn(
      columnWidth: uniformColumnWidth,
      label: headerLabel(context, text, textAlign: textAlign),
    );
  }

  static DataColumn normalizeColumn(
    DataColumn column, {
    required TableColumnWidth columnWidth,
  }) {
    return DataColumn(
      label: _normalizeHeaderChild(column.label),
      tooltip: column.tooltip,
      numeric: column.numeric,
      onSort: column.onSort,
      mouseCursor: column.mouseCursor,
      headingRowAlignment: column.headingRowAlignment,
      columnWidth: columnWidth,
    );
  }

  static DataCell normalizeCell(DataCell cell) {
    return DataCell(
      _normalizeCellChild(cell.child),
      placeholder: cell.placeholder,
      showEditIcon: cell.showEditIcon,
      onTap: cell.onTap,
      onDoubleTap: cell.onDoubleTap,
      onLongPress: cell.onLongPress,
      onTapDown: cell.onTapDown,
      onTapCancel: cell.onTapCancel,
    );
  }

  static Widget actionMenuButton<T>({
    required ThemeData theme,
    required List<PopupMenuEntry<T>> Function(BuildContext context) itemBuilder,
    required ValueChanged<T> onSelected,
    String label = '操作',
    double width = _actionButtonWidth,
    double height = _actionButtonHeight,
  }) {
    return PopupMenuButton<T>(
      color: theme.colorScheme.primaryContainer,
      padding: EdgeInsets.zero,
      onSelected: onSelected,
      itemBuilder: itemBuilder,
      child: SizedBox(
        width: width,
        height: height,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: theme.colorScheme.primary,
            borderRadius: BorderRadius.circular(_actionButtonBorderRadius),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: _actionButtonHorizontalPadding,
              vertical: _actionButtonVerticalPadding,
            ),
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  color: theme.colorScheme.onPrimary,
                  fontSize: _actionButtonFontSize,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static ButtonStyle capsuleActionButtonStyle({
    required Color backgroundColor,
    required Color foregroundColor,
  }) {
    return FilledButton.styleFrom(
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
      minimumSize: const Size(_actionButtonWidth, _actionButtonHeight),
      maximumSize: const Size(_actionButtonWidth, _actionButtonHeight),
      padding: const EdgeInsets.symmetric(
        horizontal: _actionButtonHorizontalPadding,
        vertical: _actionButtonVerticalPadding,
      ),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_actionButtonBorderRadius),
      ),
      textStyle: const TextStyle(fontSize: _actionButtonFontSize),
    );
  }

  static Widget capsuleActionButton({
    Key? key,
    required String label,
    required Color backgroundColor,
    required Color foregroundColor,
    required VoidCallback? onPressed,
  }) {
    return Opacity(
      opacity: onPressed == null ? 0.5 : 1,
      child: Material(
        key: key,
        color: backgroundColor,
        borderRadius: BorderRadius.circular(_actionButtonBorderRadius),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(_actionButtonBorderRadius),
          child: SizedBox(
            width: _actionButtonWidth,
            height: _actionButtonHeight,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: _actionButtonHorizontalPadding,
                vertical: _actionButtonVerticalPadding,
              ),
              child: Center(
                child: Text(
                  label,
                  style: TextStyle(
                    color: foregroundColor,
                    fontSize: _actionButtonFontSize,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static Alignment _alignmentForTextAlign(TextAlign textAlign) {
    switch (textAlign) {
      case TextAlign.center:
        return Alignment.center;
      case TextAlign.right:
      case TextAlign.end:
        return Alignment.centerRight;
      case TextAlign.left:
      case TextAlign.start:
      case TextAlign.justify:
        return Alignment.centerLeft;
    }
  }

  static Widget _normalizeHeaderChild(Widget child) {
    if (child is Text) {
      return Tooltip(
        message: _plainTextOfText(child),
        child: Text(
          _plainTextOfText(child),
          textAlign: child.textAlign,
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
          softWrap: false,
          style: child.style,
          strutStyle: child.strutStyle,
          textDirection: child.textDirection,
          locale: child.locale,
          textScaler: child.textScaler,
          semanticsLabel: child.semanticsLabel,
          textWidthBasis: child.textWidthBasis,
          textHeightBehavior: child.textHeightBehavior,
          selectionColor: child.selectionColor,
        ),
      );
    }
    return child;
  }

  static Widget _normalizeCellChild(Widget child) {
    if (child is Text) {
      final plainText = _plainTextOfText(child);
      return Tooltip(
        message: plainText,
        child: Text(
          plainText,
          textAlign: child.textAlign,
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
          softWrap: false,
          style: child.style,
          strutStyle: child.strutStyle,
          textDirection: child.textDirection,
          locale: child.locale,
          textScaler: child.textScaler,
          semanticsLabel: child.semanticsLabel,
          textWidthBasis: child.textWidthBasis,
          textHeightBehavior: child.textHeightBehavior,
          selectionColor: child.selectionColor,
        ),
      );
    }
    return child;
  }

  static String _plainTextOfText(Text text) {
    return text.data ?? text.textSpan?.toPlainText() ?? '';
  }
}
