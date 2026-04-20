import 'package:flutter/material.dart';

class UserManagementActionBar extends StatelessWidget {
  const UserManagementActionBar({super.key, required this.actions});

  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      alignment: WrapAlignment.end,
      children: actions,
    );
  }
}
