import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';

class DiscoveryScreen extends StatelessWidget {
  const DiscoveryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Discover')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(AppConstants.placeholderMessage),
        ),
      ),
    );
  }
}