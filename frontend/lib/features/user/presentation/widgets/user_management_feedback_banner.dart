import 'package:flutter/material.dart';
import 'package:mes_client/features/user/presentation/widgets/shared/user_module_feedback_banner.dart';

class UserManagementFeedbackBanner extends StatelessWidget {
  const UserManagementFeedbackBanner({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    if (message.isEmpty) {
      return const SizedBox.shrink();
    }
    return KeyedSubtree(
      key: const ValueKey('user-management-feedback-banner'),
      child: UserModuleFeedbackBanner.error(message: message),
    );
  }
}
