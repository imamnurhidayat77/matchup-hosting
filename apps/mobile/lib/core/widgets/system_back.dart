import 'package:flutter/material.dart';

/// System-back fallback for screens that can be the last page on the
/// stack (opened via `context.go`, deep links, or restored routes).
/// The framework back button on such a screen would otherwise close
/// the app; instead we pop when possible and run [onEmptyStack]
/// (typically `context.go(...)` to a safe parent) when there is
/// nothing to pop.
///
/// Usage: wrap the screen's scaffold.
///
/// ```dart
/// SystemBackFallback(
///   onEmptyStack: (context) => context.go('/discovery'),
///   child: AppScaffold(...),
/// )
/// ```
class SystemBackFallback extends StatelessWidget {
  const SystemBackFallback({
    super.key,
    required this.onEmptyStack,
    required this.child,
  });

  /// Called with a [BuildContext] when the system back button finds
  /// no route to pop.
  final void Function(BuildContext context) onEmptyStack;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        onEmptyStack(context);
      },
      child: child,
    );
  }
}
