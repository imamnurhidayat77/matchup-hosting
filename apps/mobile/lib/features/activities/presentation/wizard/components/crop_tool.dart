import 'dart:convert';
import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_typography.dart';

/// Crop tool component for image editing
class CropTool extends StatefulWidget {
  final String base64Image;
  final double scale;
  final ValueChanged<double> onScaleChanged;
  final VoidCallback? onConfirm;
  final VoidCallback? onCancel;

  const CropTool({
    super.key,
    required this.base64Image,
    this.scale = 1.0,
    required this.onScaleChanged,
    this.onConfirm,
    this.onCancel,
  });

  @override
  State<CropTool> createState() => _CropToolState();
}

class _CropToolState extends State<CropTool> {
  late double _scale;

  @override
  void initState() {
    super.initState();
    _scale = widget.scale;
  }

  @override
  void didUpdateWidget(CropTool oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scale != widget.scale) {
      _scale = widget.scale;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
            child: Row(
              children: [
                // Cancel button
                GestureDetector(
                  onTap: widget.onCancel,
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(100),
                      border: Border.all(color: AppColors.border),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.cancel_outlined,
                      size: 20,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  'Crop Image',
                  style: AppTypography.titleLarge.copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
                const Spacer(),
                // Confirm button
                GestureDetector(
                  onTap: widget.onConfirm,
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(100),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.check,
                      size: 20,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Image preview with crop overlay
          Expanded(
            child: Container(
              color: AppColors.border,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Image with crop overlay
                  _CropOverlay(
                    base64Image: widget.base64Image,
                    scale: _scale,
                    onScaleChanged: (value) {
                      _scale = value;
                      widget.onScaleChanged(value);
                    },
                  ),
                ],
              ),
            ),
          ),

          // Scale slider
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.zoom_out_map,
                      size: 18,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Scale: ${( _scale * 100).toInt()}%',
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                      ),
                    ),
                    const Spacer(),
                    const Icon(
                      Icons.zoom_in_map,
                      size: 18,
                      color: AppColors.textSecondary,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Slider(
                  value: _scale,
                  min: 0.5,
                  max: 2.0,
                  divisions: 15,
                  label: '${( _scale * 100).toInt()}%',
                  activeColor: AppColors.primary,
                  onChanged: (value) {
                    _scale = value;
                    widget.onScaleChanged(value);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Crop overlay with rectangle and corner handles
class _CropOverlay extends StatelessWidget {
  final String base64Image;
  final double scale;
  final ValueChanged<double> onScaleChanged;

  const _CropOverlay({
    required this.base64Image,
    required this.scale,
    required this.onScaleChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Scaled image
        Transform.scale(
          scale: scale,
          child: Image.memory(
            base64.decode(base64Image),
            fit: BoxFit.cover,
          ),
        ),
        // Crop rectangle
        Container(
          width: 300,
          height: 169, // 16:9 aspect ratio
          decoration: BoxDecoration(
            border: Border.all(
              color: Colors.white,
              width: 2,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Corner handles
              _CornerHandle(topLeft: true),
              _CornerHandle(topRight: true),
              _CornerHandle(bottomLeft: true),
              _CornerHandle(bottomRight: true),
            ],
          ),
        ),
        // Dimmed background
        Positioned.fill(
          child: Container(
            color: Colors.black.withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }
}

/// Corner handle for crop rectangle
class _CornerHandle extends StatelessWidget {
  final bool topLeft;
  final bool topRight;
  final bool bottomLeft;
  final bool bottomRight;

  const _CornerHandle({
    this.topLeft = false,
    this.topRight = false,
    this.bottomLeft = false,
    this.bottomRight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: topLeft || topRight ? -4 : null,
      bottom: bottomLeft || bottomRight ? -4 : null,
      left: topLeft || bottomLeft ? -4 : null,
      right: topRight || bottomRight ? -4 : null,
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          border: Border.all(
            color: Colors.black.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
      ),
    );
  }
}
