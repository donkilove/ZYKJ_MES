import 'package:flutter/material.dart';

class UnifiedListTableHeaderStyle {
  const UnifiedListTableHeaderStyle._();

  static const double _headerRadius = 10;
  static const double _headerHorizontalPadding = 16;
  static const double _headerVerticalPadding = 10;
  static const double _headingRowHeight = 48;
  static const double _actionButtonWidth = 72;
  static const double _actionButtonHeight = 32;
  static const double _actionButtonHorizontalPadding = 10;
  static const double _actionButtonVerticalPadding = 4;
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
        letterSpacing: 0.1,
      ),
      horizontalMargin: _headerHorizontalPadding,
      columnSpacing: 20,
      headingRowHeight: _headingRowHeight,
    );
  }

  static ButtonStyle toolbarActionButtonStyle(ThemeData theme) {
    return OutlinedButton.styleFrom(
      minimumSize: const Size(88, 36),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      textStyle: theme.textTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w600,
      ),
      side: BorderSide(color: theme.colorScheme.outlineVariant),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
          letterSpacing: 0.1,
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
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.shadow.withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
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
