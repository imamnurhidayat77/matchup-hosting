import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(AppConstants.placeholderMessage),
        ),
      ),
    );
  }
}