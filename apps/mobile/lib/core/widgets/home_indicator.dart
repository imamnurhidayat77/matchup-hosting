import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// iOS home indicator pill (139×5px, 100px radius) shown at the bottom of
/// every screen to match Figma designs.
class HomeIndicator extends StatelessWidget {
  const HomeIndicator({
    super.key,
    this.color = AppColors.iconPrimary,
    this.padding = const EdgeInsets.only(top: 16, bottom: 8),
  });

  final Color color;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Center(
        child: Container(
          width: 139,
          height: 5,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(100),
          ),
        ),
      ),
    );
  }
}