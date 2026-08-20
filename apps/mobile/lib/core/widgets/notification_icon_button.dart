import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Standardized notification icon button used in top headers across the app.
/// 44×44 tap target (Material a11y minimum), 24×24 icon centered, optional red
/// unread badge in the top-right corner. Caller must supply [onTap] because
/// GoRouter does not support `Navigator.pushNamed` for static routes.
class NotificationIconButton extends StatelessWidget {
  const NotificationIconButton({
    super.key,
    required this.onTap,
    this.hasUnread = false,
    this.color,
  });

  final VoidCallback onTap;
  final bool hasUnread;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Notifications',
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(
                Icons.notifications_none,
                size: 24,
                color: color ?? AppColors.textPrimary,
              ),
              if (hasUnread)
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppColors.error,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
