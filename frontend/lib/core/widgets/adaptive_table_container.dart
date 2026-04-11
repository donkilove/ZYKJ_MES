import 'package:flutter/material.dart';

class AdaptiveTableContainer extends StatefulWidget {
  const AdaptiveTableContainer({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

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
