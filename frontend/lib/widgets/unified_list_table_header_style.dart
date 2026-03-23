import 'package:flutter/material.dart';

class UnifiedListTableHeaderStyle {
  const UnifiedListTableHeaderStyle._();

  static const double _headerRadius = 8;
  static const double _headerHorizontalPadding = 12;
  static const double _headerVerticalPadding = 8;
  static const double _headingRowHeight = 44;
  static const double _actionButtonWidth = 64;
  static const double _actionButtonHeight = 28;
  static const double _actionButtonHorizontalPadding = 8;
  static const double _actionButtonVerticalPadding = 2;
  static const double _actionButtonFontSize = 12;
  static const double _actionButtonBorderRadius = 20;

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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: _headerVerticalPadding),
      child: Text(
        text,
        textAlign: textAlign,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  static DataColumn column(
    BuildContext context,
    String text, {
    TextAlign textAlign = TextAlign.start,
  }) {
    return DataColumn(label: headerLabel(context, text, textAlign: textAlign));
  }

  static Widget actionMenuButton<T>({
    required ThemeData theme,
    required List<PopupMenuEntry<T>> Function(BuildContext context) itemBuilder,
    required ValueChanged<T> onSelected,
    String label = '操作',
    double width = _actionButtonWidth,
    double height = _actionButtonHeight,
  }) {
    return SizedBox(
      width: width,
      height: height,
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(
          horizontal: _actionButtonHorizontalPadding,
          vertical: _actionButtonVerticalPadding,
        ),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary,
          borderRadius: BorderRadius.circular(_actionButtonBorderRadius),
        ),
        child: PopupMenuButton<T>(
          color: theme.colorScheme.primaryContainer,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 0, minHeight: 0),
          onSelected: onSelected,
          itemBuilder: itemBuilder,
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
    );
  }
}
