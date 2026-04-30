import 'dart:ui' as ui;
import 'package:flutter/material.dart';

class MessageCenterActionBar extends StatelessWidget {
  const MessageCenterActionBar({
    super.key,
    required this.loading,
    required this.canPublishAnnouncement,
    required this.onRefresh,
    required this.onMaintenance,
    required this.onPublishAnnouncement,
    required this.onMarkAllRead,
    required this.onMarkBatchRead,
    required this.batchReadCount,
  });

  final bool loading;
  final bool canPublishAnnouncement;
  final VoidCallback onRefresh;
  final VoidCallback onMaintenance;
  final VoidCallback onPublishAnnouncement;
  final VoidCallback onMarkAllRead;
  final VoidCallback onMarkBatchRead;
  final int batchReadCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      key: const ValueKey('message-center-primary-actions'),
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          _buildGlassButton(
            theme: theme,
            onPressed: loading ? null : onRefresh,
            icon: Icons.refresh_rounded,
            label: '刷新',
            isPrimary: false,
          ),
          if (canPublishAnnouncement) ...[
            _buildGlassButton(
              theme: theme,
              onPressed: loading ? null : onMaintenance,
              icon: Icons.build_circle_outlined,
              label: '执行维护',
              isPrimary: false,
            ),
            _buildGlassButton(
              theme: theme,
              onPressed: loading ? null : onPublishAnnouncement,
              icon: Icons.campaign_rounded,
              label: '发布公告',
              isPrimary: true,
            ),
          ],
          _buildGlassButton(
            theme: theme,
            onPressed: loading ? null : onMarkAllRead,
            icon: Icons.done_all_rounded,
            label: '全部已读',
            isPrimary: true,
          ),
          _buildGlassButton(
            theme: theme,
            onPressed: loading || batchReadCount == 0 ? null : onMarkBatchRead,
            icon: Icons.checklist_rtl_rounded,
            label: batchReadCount == 0 ? '批量已读' : '批量已读($batchReadCount)',
            isPrimary: false,
          ),
        ],
      ),
    );
  }

  Widget _buildGlassButton({
    required ThemeData theme,
    required VoidCallback? onPressed,
    required IconData icon,
    required String label,
    required bool isPrimary,
  }) {
    final enabled = onPressed != null;
    final primaryColor = theme.colorScheme.primary;
    final onSurface = theme.colorScheme.onSurface;
    final bgColor = isPrimary 
        ? primaryColor.withAlpha(enabled ? 200 : 50)
        : theme.colorScheme.surface.withAlpha(enabled ? 100 : 50);
    final borderColor = isPrimary
        ? primaryColor.withAlpha(enabled ? 100 : 20)
        : theme.colorScheme.outline.withAlpha(enabled ? 50 : 20);
    final fgColor = enabled 
        ? (isPrimary ? theme.colorScheme.onPrimary : onSurface)
        : onSurface.withAlpha(100);

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor, width: 1.5),
            boxShadow: isPrimary && enabled
                ? [
                    BoxShadow(
                      color: primaryColor.withAlpha(80),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    )
                  ]
                : null,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onPressed,
              borderRadius: BorderRadius.circular(12),
              splashColor: fgColor.withAlpha(30),
              highlightColor: fgColor.withAlpha(15),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 18, color: fgColor),
                    const SizedBox(width: 8),
                    Text(
                      label,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: fgColor,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
