import 'package:flutter/material.dart';

/// 锁定型表单弹窗。强制 `barrierDismissible: false` 与 `PopScope(canPop: false)`，
/// 用于防止用户在表单填写过程中误关闭丢失数据。
Future<T?> showMesLockedFormDialog<T>({
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
