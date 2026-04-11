import 'package:flutter/material.dart';

Future<T?> showLockedFormDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool useSafeArea = true,
  bool useRootNavigator = true,
  RouteSettings? routeSettings,
  Offset? anchorPoint,
  TraversalEdgeBehavior? traversalEdgeBehavior,
  bool? requestFocus,
}) {
  return showDialog<T>(
    context: context,
    barrierDismissible: false,
    useSafeArea: useSafeArea,
    useRootNavigator: useRootNavigator,
    routeSettings: routeSettings,
    anchorPoint: anchorPoint,
    traversalEdgeBehavior: traversalEdgeBehavior,
    requestFocus: requestFocus,
    builder: (dialogContext) {
      return PopScope(canPop: false, child: builder(dialogContext));
    },
  );
}
