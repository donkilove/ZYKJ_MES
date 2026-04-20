import 'package:flutter/material.dart';
import 'package:mes_client/core/ui/patterns/mes_inline_banner.dart';

class UserModuleFeedbackBanner extends StatelessWidget {
  const UserModuleFeedbackBanner._({
    super.key,
    required this.message,
    required this.builder,
  });

  const UserModuleFeedbackBanner.info({Key? key, required String message})
    : this._(key: key, message: message, builder: MesInlineBanner.info);

  const UserModuleFeedbackBanner.warning({Key? key, required String message})
    : this._(key: key, message: message, builder: MesInlineBanner.warning);

  const UserModuleFeedbackBanner.error({Key? key, required String message})
    : this._(key: key, message: message, builder: MesInlineBanner.error);

  const UserModuleFeedbackBanner.success({Key? key, required String message})
    : this._(key: key, message: message, builder: MesInlineBanner.success);

  final String message;
  final Widget Function({Key? key, required String message}) builder;

  @override
  Widget build(BuildContext context) {
    return builder(
      key: const ValueKey('user-module-feedback-banner'),
      message: message,
    );
  }
}
