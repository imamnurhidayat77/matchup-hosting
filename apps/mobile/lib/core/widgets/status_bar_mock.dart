import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Mock iOS status bar matching Figma designs (44px tall, "9:41" time + signal/wifi/battery icons).
/// Replace at platform level when integrating real status bar.
class StatusBarMock extends StatelessWidget {
  const StatusBarMock({
    super.key,
    this.time = '9:41',
    this.foreground = AppColors.textOnPrimary,
  });

  final String time;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      width: double.infinity,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Semantics(
              label: 'Time',
              child: Text(
                time,
                style: TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: foreground,
                ),
              ),
            ),
            Row(
              children: [
                _icon('assets/images/splash/ios_signal.svg', 17, 11, 'Cellular signal'),
                const SizedBox(width: 6),
                _icon('assets/images/splash/ios_wifi.svg', 15, 11, 'Wi-Fi connected'),
                const SizedBox(width: 6),
                _icon('assets/images/splash/ios_battery.svg', 25, 12, 'Battery full'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _icon(String path, double w, double h, String label) {
    return SizedBox(
      width: w,
      height: h,
      child: Image.asset(
        path,
        fit: BoxFit.contain,
        color: foreground == AppColors.textOnPrimary ? Colors.white : null,
        semanticLabel: label,
      ),
    );
  }
}