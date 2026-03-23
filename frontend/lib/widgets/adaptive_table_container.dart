import 'package:flutter/material.dart';

class AdaptiveTableContainer extends StatefulWidget {
  const AdaptiveTableContainer({
    super.key,
    required this.child,
    this.padding,
    this.minTableWidth,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double? minTableWidth;

  static EdgeInsetsGeometry resolveDefaultPadding(double maxWidth) {
    if (maxWidth >= 1600) {
      return const EdgeInsets.symmetric(horizontal: 24, vertical: 12);
    }
    if (maxWidth >= 1280) {
      return const EdgeInsets.symmetric(horizontal: 20, vertical: 12);
    }
    if (maxWidth >= 960) {
      return const EdgeInsets.symmetric(horizontal: 16, vertical: 10);
    }
    return const EdgeInsets.all(8);
  }

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
    return LayoutBuilder(
      builder: (context, constraints) {
        final resolvedPadding =
            widget.padding ??
            AdaptiveTableContainer.resolveDefaultPadding(constraints.maxWidth);
        final double resolvedMinWidth = widget.minTableWidth != null
            ? widget.minTableWidth!.clamp(0, double.infinity).toDouble()
            : constraints.maxWidth.toDouble();

        return Scrollbar(
          controller: _verticalController,
          thumbVisibility: true,
          child: SingleChildScrollView(
            controller: _verticalController,
            padding: resolvedPadding,
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Scrollbar(
                controller: _horizontalController,
                thumbVisibility: true,
                notificationPredicate: (notification) =>
                    notification.depth == 1,
                child: SingleChildScrollView(
                  controller: _horizontalController,
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minWidth: resolvedMinWidth > constraints.maxWidth
                          ? resolvedMinWidth
                          : constraints.maxWidth,
                    ),
                    child: widget.child,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
