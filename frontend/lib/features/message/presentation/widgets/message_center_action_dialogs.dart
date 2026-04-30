import 'package:flutter/material.dart';

import 'package:mes_client/features/message/presentation/widgets/announcement_publish_dialog.dart';
import 'package:mes_client/features/message/services/message_service.dart';
import 'package:mes_client/features/user/services/user_service.dart';

Future<bool> showMessageCenterPublishDialog({
  required BuildContext context,
  required UserService userService,
  required MessageService service,
}) async {
  final published = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => AnnouncementPublishDialog(
      userService: userService,
      service: service,
    ),
  );
  return published == true;
}
