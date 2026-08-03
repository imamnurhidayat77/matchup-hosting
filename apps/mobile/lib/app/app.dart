import 'package:flutter/material.dart';

import '../core/constants/app_constants.dart';
import 'router.dart';

class MatchUpApp extends StatelessWidget {
  MatchUpApp({super.key});

  final _router = buildRouter();

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: AppConstants.appName,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2563EB)),
        useMaterial3: true,
      ),
      routerConfig: _router,
    );
  }
}