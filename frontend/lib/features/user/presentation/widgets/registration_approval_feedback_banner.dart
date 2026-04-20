import 'package:flutter/material.dart';
import 'package:mes_client/features/user/presentation/widgets/shared/user_module_feedback_banner.dart';

class RegistrationApprovalFeedbackBanner extends StatelessWidget {
  const RegistrationApprovalFeedbackBanner({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    if (message.isEmpty) {
      return const SizedBox.shrink();
    }
    return KeyedSubtree(
      key: const ValueKey('registration-approval-feedback-banner'),
      child: UserModuleFeedbackBanner.info(message: message),
    );
  }
}
