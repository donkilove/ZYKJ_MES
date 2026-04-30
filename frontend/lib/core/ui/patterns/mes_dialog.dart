import 'package:flutter/material.dart';
import 'package:mes_client/core/ui/foundation/mes_tokens.dart';

class MesDialog extends StatelessWidget {
  const MesDialog({
    super.key,
    this.title,
    required this.content,
    this.actions = const <Widget>[],
    this.width,
    this.scrollable = false,
    this.contentPadding,
    this.actionsPadding,
    this.titlePadding,
  });

  final Widget? title;
  final Widget content;
  final List<Widget> actions;
  final double? width;
  final bool scrollable;
  final EdgeInsetsGeometry? contentPadding;
  final EdgeInsetsGeometry? actionsPadding;
  final EdgeInsetsGeometry? titlePadding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.extension<MesTokens>();
    final dialogWidth = width ?? 480.0;
    final horizontalPadding = tokens?.spacing.lg ?? 24.0;
    final verticalPadding = tokens?.spacing.md ?? 16.0;

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: tokens?.radius.lg ?? BorderRadius.circular(20),
        side: BorderSide(
          color: tokens?.colors.border ?? theme.colorScheme.outlineVariant,
        ),
      ),
      backgroundColor:
          tokens?.colors.surfaceRaised ?? theme.colorScheme.surfaceContainerHigh,
      titlePadding:
          title == null
              ? EdgeInsets.zero
              : titlePadding ??
                  EdgeInsets.fromLTRB(
                    horizontalPadding,
                    horizontalPadding,
                    horizontalPadding,
                    0,
                  ),
      contentPadding:
          contentPadding ??
          EdgeInsets.fromLTRB(
            horizontalPadding,
            verticalPadding,
            horizontalPadding,
            0,
          ),
      actionsPadding:
          actions.isEmpty
              ? EdgeInsets.zero
              : actionsPadding ??
                  EdgeInsets.fromLTRB(
                    horizontalPadding,
                    verticalPadding,
                    horizontalPadding,
                    horizontalPadding,
                  ),
      actionsAlignment: MainAxisAlignment.end,
      actionsOverflowAlignment: OverflowBarAlignment.end,
      actionsOverflowButtonSpacing: tokens?.spacing.sm ?? 12.0,
      title:
          title == null
              ? null
              : DefaultTextStyle(
                  style:
                      tokens?.typography.sectionTitle ??
                      theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ) ??
                      const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                  child: title!,
                ),
      content: SizedBox(
        width: dialogWidth,
        child: scrollable ? SingleChildScrollView(child: content) : content,
      ),
      actions: actions,
    );
  }
}
