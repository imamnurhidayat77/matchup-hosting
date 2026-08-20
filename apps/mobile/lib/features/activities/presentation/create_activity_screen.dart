import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/providers/repository_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/date_picker_sheet.dart';
import 'create/components/image_picker_modal.dart';
import 'create/providers/image_upload_provider.dart';
import 'create/services/form_validator.dart';
import 'create/providers/form_data_provider.dart';

/// Single-scroll create activity screen.
class CreateActivityScreen extends ConsumerStatefulWidget {
  const CreateActivityScreen({super.key});

  @override
  ConsumerState<CreateActivityScreen> createState() =>
      _CreateActivityScreenState();
}

class _CreateActivityScreenState extends ConsumerState<CreateActivityScreen> {
  final _titleController = TextEditingController();
  final _priceController = TextEditingController(text: '0.00');
  static final _picker = ImagePicker();

  DateTime _selectedDate = DateTime.now().add(const Duration(hours: 2));
  int _maxParticipants = 10;
  String _skillLevel = 'Intermediate';
  int _feeType = 0; // 0 = Free, 1 = Paid
  bool _submitting = false;

  static const _skillOptions = [
    'All Level',
    'Beginner',
    'Intermediate',
    'Advanced',
  ];
  static const _sportOptions = [
    'Basketball',
    'Tennis',
    'Running',
    'Volleyball',
    'Football',
    'Soccer',
    'Cycling',
    'Hiking',
    'Golf',
    'Swimming',
  ];

  @override
  void initState() {
    super.initState();
    // Reset upload state on open
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(imageUploadProvider.notifier).reset();
      ref.read(formDataProvider.notifier).reset();
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  String _formatDate(DateTime dt) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final hour12 = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
    final ampm = dt.hour < 12 ? 'AM' : 'PM';
    final min = dt.minute.toString().padLeft(2, '0');
    return '${days[dt.weekday - 1]}, ${months[dt.month - 1]} ${dt.day}, $hour12:$min $ampm';
  }

  // ── Image upload ───────────────────────────────────────────────────────────

  Future<void> _pickImage() async {
    final choice = await showModalBottomSheet<ImageSourceChoice>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const ImagePickerModal(),
    );
    if (choice == null || !mounted) return;

    final source = choice == ImageSourceChoice.gallery
        ? ImageSource.gallery
        : ImageSource.camera;

    ref.read(imageUploadProvider.notifier).setUploading(0.1);
    try {
      final file = await _picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      if (file == null) {
        ref.read(imageUploadProvider.notifier).reset();
        return;
      }
      final bytes = await file.readAsBytes();
      if (bytes.lengthInBytes > 5 * 1024 * 1024) {
        ref
            .read(imageUploadProvider.notifier)
            .setFailed('Image must be under 5 MB.');
        return;
      }
      final b64 = base64.encode(bytes);
      ref.read(imageUploadProvider.notifier).setCompleted(b64);
      ref.read(formDataProvider.notifier).setCoverImage(b64);
    } catch (_) {
      ref
          .read(imageUploadProvider.notifier)
          .setFailed('Could not load image. Please try again.');
    }
  }

  // ── Date picker ────────────────────────────────────────────────────────────

  Future<void> _pickDate() async {
    final picked = await showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          DatePickerSheet(initialDate: _selectedDate, minDate: DateTime.now()),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  // ── Sport picker ───────────────────────────────────────────────────────────

  void _showSportPicker() {
    final current = ref.read(formDataProvider).sportType;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.55,
          ),
          child: Container(
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(AppRadius.xl),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.x6,
              AppSpacing.x3,
              AppSpacing.x6,
              AppSpacing.x6,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: AppSpacing.x4),
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Text(
                  'Select Sport',
                  style: AppTypography.titleLarge.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: AppSpacing.x3),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _sportOptions.length,
                    itemBuilder: (context, index) {
                      final opt = _sportOptions[index];
                      final selected = opt == current;
                      return GestureDetector(
                        onTap: () {
                          ref.read(formDataProvider.notifier).setSportType(opt);
                          setState(() {});
                          Navigator.of(context).pop();
                        },
                        behavior: HitTestBehavior.opaque,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: AppSpacing.x3,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  opt,
                                  style: AppTypography.bodyMedium.copyWith(
                                    fontSize: 15,
                                    color: AppColors.textPrimary,
                                    fontWeight: selected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                  ),
                                ),
                              ),
                              if (selected)
                                const Icon(
                                  Icons.check_rounded,
                                  color: AppColors.primary,
                                  size: 18,
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Submit ─────────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    if (_submitting) return;

    final formData = ref.read(formDataProvider);
    // Sync local state into provider before validation
    ref.read(formDataProvider.notifier)
      ..setTitle(_titleController.text.trim())
      ..setSelectedDate(_selectedDate)
      ..setMaxParticipants(_maxParticipants)
      ..setSkillLevel(_skillLevel)
      ..setFeeType(_feeType)
      ..setPrice(_feeType == 1 ? _priceController.text.trim() : null);

    final errors = formValidator(ref.read(formDataProvider));
    if (errors.isNotEmpty) {
      if (!mounted) return;
      AppSnackbar.show(
        context,
        message:
            'Please fix ${errors.length} issue${errors.length == 1 ? '' : 's'} before creating.',
        variant: AppSnackbarVariant.error,
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      await ref
          .read(activityRepositoryProvider)
          .create(
            title: formData.title.trim(),
            sportType: formData.sportType,
            location: '',
            dateTime: _selectedDate,
            maxParticipants: _maxParticipants,
            skillLevel: _skillLevel,
            fee: _feeType == 1
                ? double.tryParse(_priceController.text.trim()) ?? 0
                : 0.0,
          );
      ref.read(formDataProvider.notifier).reset();
      ref.read(imageUploadProvider.notifier).reset();
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      AppSnackbar.show(
        context,
        message: 'Activity created! 🎉',
        variant: AppSnackbarVariant.success,
      );
      context.go('/activities');
    } catch (_) {
      if (!mounted) return;
      AppSnackbar.show(
        context,
        message: 'Could not create activity. Please try again.',
        variant: AppSnackbarVariant.error,
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final uploadInfo = ref.watch(imageUploadProvider);
    final formData = ref.watch(formDataProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ───────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.x4,
                AppSpacing.x3,
                AppSpacing.x4,
                AppSpacing.x2,
              ),
              child: Row(
                children: [
                  // Figma 43:291 — a bare 14pt arrow, no container or fill.
                  // Kept visually bare but padded to a 44pt touch target.
                  Semantics(
                    button: true,
                    label: 'Back',
                    child: GestureDetector(
                      onTap: () => context.pop(),
                      behavior: HitTestBehavior.opaque,
                      child: const SizedBox(
                        width: 44,
                        height: 44,
                        child: Center(
                          child: Icon(
                            Icons.arrow_back_rounded,
                            size: 18,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'Create Activity',
                      textAlign: TextAlign.center,
                      style: AppTypography.titleSheet,
                    ),
                  ),
                  // Mirrors the back button so the title stays optically centred.
                  const SizedBox(width: 44),
                ],
              ),
            ),

            // ── Scrollable body ───────────────────────────────────────────
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.x5,
                  AppSpacing.x2,
                  AppSpacing.x5,
                  AppSpacing.x10,
                ),
                children: [
                  // ── Cover Photo ────────────────────────────────────────
                  _CoverPhoto(
                    uploadInfo: uploadInfo,
                    onTap: _pickImage,
                    onRemove: () {
                      ref.read(imageUploadProvider.notifier).reset();
                      ref.read(formDataProvider.notifier).setCoverImage(null);
                    },
                    onReplace: _pickImage,
                  ),
                  const SizedBox(height: AppSpacing.x5),

                  // ── Activity Title ─────────────────────────────────────
                  _FieldLabel('Activity Title'),
                  const SizedBox(height: _kLabelGap),
                  _InputBox(
                    child: TextField(
                      controller: _titleController,
                      style: _inputStyle,
                      cursorColor: AppColors.primary,
                      decoration: _dec('Weekend Basketball Runs'),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.x4),

                  // ── Sport Type ─────────────────────────────────────────
                  _FieldLabel('Sport Type'),
                  const SizedBox(height: _kLabelGap),
                  GestureDetector(
                    onTap: _showSportPicker,
                    behavior: HitTestBehavior.opaque,
                    child: _InputBox(
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(formData.sportType, style: _inputStyle),
                          ),
                          // Figma 43:463 — 16pt chevron.
                          const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 16,
                            color: AppColors.textSecondary,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.x4),

                  // ── Date & Time ────────────────────────────────────────
                  _FieldLabel('Date & Time'),
                  const SizedBox(height: _kLabelGap),
                  GestureDetector(
                    onTap: _pickDate,
                    behavior: HitTestBehavior.opaque,
                    child: _InputBox(
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _formatDate(_selectedDate),
                              style: _inputStyle,
                            ),
                          ),
                          // Figma 43:466 — 16pt calendar.
                          const Icon(
                            Icons.calendar_month_outlined,
                            size: 16,
                            color: AppColors.textSecondary,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.x4),

                  // ── Max Participants ───────────────────────────────────
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _FieldLabel('Max Participants'),
                            Text(
                              'Including yourself',
                              style: AppTypography.metaSub,
                            ),
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          _CounterBtn(
                            icon: Icons.remove,
                            enabled: _maxParticipants > 2,
                            emphasised: false,
                            semanticLabel: 'Remove one participant',
                            onTap: () => setState(() => _maxParticipants--),
                          ),
                          Text(
                            '$_maxParticipants',
                            style: AppTypography.titleMedium.copyWith(
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          _CounterBtn(
                            icon: Icons.add,
                            enabled: _maxParticipants < 50,
                            emphasised: true,
                            semanticLabel: 'Add one participant',
                            onTap: () => setState(() => _maxParticipants++),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.x4),

                  // ── Skill Level ────────────────────────────────────────
                  _FieldLabel('Skill Level Required'),
                  const SizedBox(height: _kLabelGap),
                  // Figma 43:322 — a segmented control, not scrolling chips.
                  // Every option stays visible, so the host can compare without
                  // tapping or swiping.
                  _Segmented(
                    labels: _skillOptions,
                    selectedIndex: _skillOptions.indexOf(_skillLevel),
                    onSelect: (i) =>
                        setState(() => _skillLevel = _skillOptions[i]),
                  ),
                  const SizedBox(height: AppSpacing.x4),

                  // ── Event Fee ──────────────────────────────────────────
                  _FieldLabel('Event Fee'),
                  const SizedBox(height: _kLabelGap),
                  // Figma 65:5 — same control, two segments.
                  _Segmented(
                    labels: const ['Free', 'Paid'],
                    selectedIndex: _feeType,
                    onSelect: (i) => setState(() => _feeType = i),
                  ),
                  if (_feeType == 1) ...[
                    const SizedBox(height: AppSpacing.x4),
                    _FieldLabel('Price per person'),
                    const SizedBox(height: _kLabelGap),
                    _InputBox(
                      child: Row(
                        children: [
                          Text('\$', style: _inputStyle),
                          const SizedBox(width: AppSpacing.x1),
                          Expanded(
                            child: TextField(
                              controller: _priceController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              textInputAction: TextInputAction.done,
                              cursorColor: AppColors.primary,
                              style: _inputStyle,
                              decoration: _dec('0.00'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // ── Create Activity button ─────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.x5,
                AppSpacing.x2,
                AppSpacing.x5,
                AppSpacing.x5,
              ),
              child: GestureDetector(
                onTap: _submitting ? null : _submit,
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: AppDurations.fast,
                  // Figma 43:331 — 52 tall.
                  height: 52,
                  decoration: BoxDecoration(
                    color: _submitting ? AppColors.border : AppColors.primary,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    boxShadow: _submitting ? null : AppShadows.glowPrimary,
                  ),
                  alignment: Alignment.center,
                  child: _submitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation(
                              AppColors.textOnPrimary,
                            ),
                            strokeWidth: 2.5,
                          ),
                        )
                      : Text(
                          'Create Activity',
                          style: AppTypography.buttonPrimary,
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _CoverPhoto
// ─────────────────────────────────────────────────────────────────────────────

class _CoverPhoto extends StatelessWidget {
  const _CoverPhoto({
    required this.uploadInfo,
    required this.onTap,
    required this.onRemove,
    required this.onReplace,
  });

  final ImageUploadInfo uploadInfo;
  final VoidCallback onTap;
  final VoidCallback onRemove;
  final VoidCallback onReplace;

  @override
  Widget build(BuildContext context) {
    final done =
        uploadInfo.state == ImageUploadState.completed &&
        uploadInfo.imageUrl != null;
    final loading = uploadInfo.state == ImageUploadState.uploading;

    return GestureDetector(
      onTap: done || loading ? null : onTap,
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            color: AppColors.surfaceInverse,
            image: done
                ? DecorationImage(
                    image: MemoryImage(base64.decode(uploadInfo.imageUrl!)),
                    fit: BoxFit.cover,
                  )
                : null,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Empty state
                if (!done && !loading)
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppColors.textOnPrimary.withValues(
                            alpha: 0.12,
                          ),
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.add_photo_alternate_outlined,
                          size: 26,
                          color: AppColors.textOnPrimary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.x3),
                      Text(
                        'Add Cover Photo',
                        style: AppTypography.labelField.copyWith(
                          color: AppColors.textOnPrimary,
                        ),
                      ),
                    ],
                  ),

                // Loading
                if (loading)
                  const ColoredBox(
                    color: AppColors.scrim,
                    child: Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.textOnPrimary,
                        ),
                        strokeWidth: 2.5,
                      ),
                    ),
                  ),

                // Error
                if (uploadInfo.state == ImageUploadState.failed)
                  ColoredBox(
                    color: AppColors.scrim,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.x4),
                        child: Text(
                          uploadInfo.errorMessage ?? 'Failed',
                          style: AppTypography.labelField.copyWith(
                            color: AppColors.textOnPrimary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),

                // Actions when done
                if (done)
                  Positioned(
                    bottom: AppSpacing.x2,
                    right: AppSpacing.x2,
                    child: Row(
                      children: [
                        _PhotoBtn(icon: Icons.edit_rounded, onTap: onReplace),
                        const SizedBox(width: AppSpacing.x2),
                        _PhotoBtn(
                          icon: Icons.delete_outline_rounded,
                          onTap: onRemove,
                          danger: true,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PhotoBtn extends StatelessWidget {
  const _PhotoBtn({
    required this.icon,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? AppColors.danger : AppColors.primary;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: AppColors.textOnPrimary,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: color.withValues(alpha: 0.3)),
          boxShadow: AppShadows.card,
        ),
        alignment: Alignment.center,
        child: Icon(icon, size: 16, color: color),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared small widgets
// ─────────────────────────────────────────────────────────────────────────────

/// Form field label — Figma 43:297: 14px Bold.
class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) =>
      Text(text, style: AppTypography.labelField);
}

/// Gap between a field label and its control — Figma measures 6.
const double _kLabelGap = 6;

/// Shared bordered input container — Figma 43:298: 342×43, radius 12,
/// 16pt horizontal padding.
class _InputBox extends StatelessWidget {
  const _InputBox({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 43,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x4),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.input),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }
}

/// Figma 43:299 — 15px Regular in `textPrimary`.
TextStyle get _inputStyle =>
    AppTypography.bodyFormSecondary.copyWith(color: AppColors.textPrimary);

InputDecoration _dec(String hint) => InputDecoration(
  hintText: hint,
  hintStyle: AppTypography.bodyFormSecondary.copyWith(
    color: AppColors.textTertiary,
  ),
  border: InputBorder.none,
  enabledBorder: InputBorder.none,
  focusedBorder: InputBorder.none,
  isDense: true,
  contentPadding: EdgeInsets.zero,
);

/// Stepper button. Figma gives the two sides different treatments (43:315 /
/// 43:318): decrement is a neutral outlined circle, increment is a filled
/// `primarySoft` circle with no border — a quiet nudge toward adding people.
///
/// Visual size stays 32 as designed; the touch target is padded to 44.
class _CounterBtn extends StatelessWidget {
  const _CounterBtn({
    required this.icon,
    required this.enabled,
    required this.onTap,
    required this.emphasised,
    required this.semanticLabel,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  /// True for the increment side — filled `primarySoft`, no border.
  final bool emphasised;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final Color fill;
    final Color iconColor;
    final BoxBorder? border;

    if (!enabled) {
      fill = AppColors.surfaceSubtle;
      iconColor = AppColors.textTertiary;
      border = Border.all(color: AppColors.border);
    } else if (emphasised) {
      fill = AppColors.primarySoft;
      iconColor = AppColors.primaryDarker;
      border = null;
    } else {
      fill = AppColors.surfaceSubtle;
      iconColor = AppColors.textPrimary;
      border = Border.all(color: AppColors.border);
    }

    return Semantics(
      button: true,
      enabled: enabled,
      label: semanticLabel,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Center(
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: fill,
                border: border,
              ),
              alignment: Alignment.center,
              child: Icon(icon, size: 16, color: iconColor),
            ),
          ),
        ),
      ),
    );
  }
}

/// Segmented control matching Figma 43:322 (skill level) and 65:5 (event fee).
///
/// Track: 39 tall, radius 12, `surfaceSubtle` fill with a border and 4pt inset.
/// Active segment: `primary` fill, radius 8. Segments share the width equally,
/// so the same widget serves both the 4-option and 2-option cases.
class _Segmented extends StatelessWidget {
  const _Segmented({
    required this.labels,
    required this.selectedIndex,
    required this.onSelect,
  });

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 39,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceSubtle,
        borderRadius: BorderRadius.circular(AppRadius.input),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: Semantics(
                button: true,
                selected: i == selectedIndex,
                label: labels[i],
                child: GestureDetector(
                  onTap: () => onSelect(i),
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedContainer(
                    duration: AppDurations.base,
                    curve: Curves.easeOut,
                    decoration: BoxDecoration(
                      color: i == selectedIndex
                          ? AppColors.primary
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(AppRadius.xs),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      labels[i],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: i == selectedIndex
                          ? AppTypography.chipLabel.copyWith(
                              color: AppColors.textOnPrimary,
                            )
                          : AppTypography.chipLabel.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
