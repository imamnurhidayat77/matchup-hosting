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
import '../../../core/theme/dark_colors.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/app_tappable.dart';
import '../../../core/widgets/date_picker_sheet.dart';
import '../../../core/widgets/pressable_scale.dart';
import '../../discovery/presentation/widgets/discovery_card.dart';
import '../domain/activity_model.dart';
import 'create/components/image_picker_modal.dart';
import 'create/providers/form_data_provider.dart';
import 'create/providers/image_upload_provider.dart';

/// Two-step create-activity wizard with a live preview.
///
/// Step 1 (Setup)   — the basic game details (title, sport, date, duration,
///                    location, capacity), shown as tappable setting cards.
/// Step 2 (Rules)   — who can join (skill, entry fee, visibility, description,
///                    photos).
/// Preview          — renders the real [DiscoveryCard] from the form data so
///                    the host sees exactly what others will see before they
///                    commit.
///
/// Every field is driven straight through [formDataProvider] (single source
/// of truth); the widget only holds ephemeral UI state (which step is shown
/// and whether a submit is in flight).
class CreateActivityScreen extends ConsumerStatefulWidget {
  const CreateActivityScreen({super.key});

  @override
  ConsumerState<CreateActivityScreen> createState() =>
      _CreateActivityScreenState();
}

class _CreateActivityScreenState extends ConsumerState<CreateActivityScreen> {
  static const _stepSetup = 0;
  static const _stepRules = 1;
  static const _stepPreview = 2;

  final _titleController = TextEditingController();
  final _locationController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController(text: '0.00');
  static final _picker = ImagePicker();

  int _step = _stepSetup;
  bool _submitting = false;

  // Custom duration: stepped in 15-minute increments, 30m … 8h.
  static const _durationStep = 15;
  static const _durationMin = 30;
  static const _durationMax = 480;
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(imageUploadProvider.notifier).reset();
      ref.read(formDataProvider.notifier)
        ..reset()
        ..setSelectedDate(DateTime.now().add(const Duration(hours: 2)));
      _titleController.clear();
      _locationController.clear();
      _descriptionController.clear();
      _priceController.text = '0.00';
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  FormDataNotifier get _form => ref.read(formDataProvider.notifier);

  // ── Formatting ─────────────────────────────────────────────────────────────

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

  String _durationText(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h == 0) return '$m min';
    if (m == 0) return h == 1 ? '1 hour' : '$h hours';
    return '${h}h ${m}m';
  }

  // ── Pickers ──────────────────────────────────────────────────────────────

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
      _form.setCoverImage(b64);
    } catch (_) {
      ref
          .read(imageUploadProvider.notifier)
          .setFailed('Could not load image. Please try again.');
    }
  }

  Future<void> _pickDate() async {
    final current = ref.read(formDataProvider).selectedDate;
    final picked = await showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DatePickerSheet(
        initialDate: current ?? DateTime.now().add(const Duration(hours: 2)),
        minDate: DateTime.now(),
      ),
    );
    if (picked != null) _form.setSelectedDate(picked);
  }

  void _showOptionPicker({
    required String title,
    required List<String> options,
    required String current,
    required ValueChanged<String> onSelect,
  }) {
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
            decoration: BoxDecoration(
              color: context.colors.surface,
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
                    color: context.colors.border,
                    borderRadius: AppRadius.pillR,
                  ),
                ),
                Text(
                  title,
                  style: AppTypography.titleLarge(
                    context,
                  ).copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: AppSpacing.x3),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: options.length,
                    itemBuilder: (context, index) {
                      final opt = options[index];
                      final selected = opt == current;
                      return PressableScale(
                        onTap: () {
                          onSelect(opt);
                          Navigator.of(context).pop();
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: AppSpacing.x3,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  opt,
                                  style: AppTypography.bodyMedium(context)
                                      .copyWith(
                                        fontSize: 15,
                                        color: context.colors.textPrimary,
                                        fontWeight: selected
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                      ),
                                ),
                              ),
                              if (selected)
                                Icon(
                                  Icons.check_rounded,
                                  color: context.colors.primaryOnSurface,
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

  // ── Navigation ─────────────────────────────────────────────────────────────

  void _onBack() {
    if (_step > _stepSetup) {
      setState(() => _step--);
    } else {
      context.pop();
    }
  }

  void _continueToRules() {
    final data = ref.read(formDataProvider);
    final err = _setupError(data);
    if (err != null) {
      AppSnackbar.show(
        context,
        message: err,
        variant: AppSnackbarVariant.error,
      );
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _step = _stepRules);
  }

  void _goToPreview() {
    if (ref.read(formDataProvider).feeType == 1) {
      final price = double.tryParse(_priceController.text.trim());
      if (price == null || price <= 0) {
        AppSnackbar.show(
          context,
          message: 'Please enter a valid price.',
          variant: AppSnackbarVariant.error,
        );
        return;
      }
    }
    FocusScope.of(context).unfocus();
    setState(() => _step = _stepPreview);
  }

  /// First blocking issue on the setup step, or null when it's good to go.
  String? _setupError(ActivityFormData data) {
    if (data.title.trim().isEmpty) return 'Please enter an activity title.';
    if (data.location.trim().isEmpty) return 'Please enter a location.';
    final date = data.selectedDate;
    if (date == null || date.isBefore(DateTime.now())) {
      return 'Please pick a future date and time.';
    }
    if (data.maxParticipants < 2) return 'Minimum 2 participants required.';
    return null;
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final data = ref.read(formDataProvider);

    setState(() => _submitting = true);
    try {
      await ref
          .read(activityRepositoryProvider)
          .create(
            title: data.title.trim(),
            sportType: data.sportType,
            location: data.location.trim(),
            dateTime:
                data.selectedDate ??
                DateTime.now().add(const Duration(hours: 2)),
            maxParticipants: data.maxParticipants,
            skillLevel: data.skillLevel,
            fee: data.feeType == 1
                ? double.tryParse(_priceController.text.trim()) ?? 0
                : 0.0,
            durationMinutes: data.durationMinutes,
          );
      _form.reset();
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
    final data = ref.watch(formDataProvider);
    final uploadInfo = ref.watch(imageUploadProvider);

    return AppScaffold.sheet(
      title: _step == _stepPreview ? 'Preview Activity' : 'Create Activity',
      onBack: _onBack,
      showHomeIndicator: false,
      body: Column(
        children: [
          _StepProgressBar(step: _step),
          Expanded(
            child: switch (_step) {
              _stepRules => _buildRulesStep(data, uploadInfo),
              _stepPreview => _buildPreviewStep(data),
              _ => _buildSetupStep(data),
            },
          ),
        ],
      ),
      bottomBar: _buildBottomBar(),
    );
  }

  Widget _buildBottomBar() {
    final Widget content = switch (_step) {
      _stepRules => _PrimaryCta(
        label: 'Preview activity',
        subtitle: 'See how it will look to others',
        onPressed: _goToPreview,
      ),
      _stepPreview => Row(
        children: [
          Expanded(
            child: AppButton.secondary(
              label: 'Edit Details',
              size: AppButtonSize.sm,
              onPressed: () => setState(() => _step = _stepRules),
            ),
          ),
          const SizedBox(width: AppSpacing.x3),
          Expanded(
            flex: 2,
            child: AppButton(
              label: 'Create Activity',
              size: AppButtonSize.sm,
              onPressed: _submitting ? null : _submit,
              loading: _submitting,
            ),
          ),
        ],
      ),
      _ => _PrimaryCta(
        label: 'Continue',
        subtitle: 'Step 2: Who can join?',
        onPressed: _continueToRules,
      ),
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.x5,
        AppSpacing.x3,
        AppSpacing.x5,
        AppSpacing.x4,
      ),
      child: content,
    );
  }

  // ── Step 1 · Setup ──────────────────────────────────────────────────────────

  Widget _buildSetupStep(ActivityFormData data) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.x5,
        AppSpacing.x2,
        AppSpacing.x5,
        AppSpacing.x8,
      ),
      children: [
        const _StepHeading(
          title: "Let's set up your game",
          subtitle: 'Add the basic details of your activity',
        ),
        const SizedBox(height: AppSpacing.x4),

        // Title.
        _SettingCard(
          icon: Icons.edit_outlined,
          label: 'Activity Title',
          trailing: Text(
            '${data.title.length}/40',
            style: AppTypography.metaSub(context),
          ),
          value: TextField(
            controller: _titleController,
            style: _inputStyle(context),
            cursorColor: AppColors.primary,
            inputFormatters: [LengthLimitingTextInputFormatter(40)],
            decoration: _dec(context, 'Weekend Basketball Runs'),
            onChanged: _form.setTitle,
          ),
        ),

        // Sport.
        _SettingCard(
          icon: Icons.sports_basketball_outlined,
          label: 'Sport',
          onTap: () => _showOptionPicker(
            title: 'Select Sport',
            options: _sportOptions,
            current: data.sportType,
            onSelect: _form.setSportType,
          ),
          value: Text(data.sportType, style: _valueStyle(context)),
          trailing: _chevron(context),
        ),

        // Date & time.
        _SettingCard(
          icon: Icons.calendar_month_outlined,
          label: 'Date & Time',
          onTap: _pickDate,
          value: Text(
            data.selectedDate == null
                ? 'Pick a date'
                : _formatDate(data.selectedDate!),
            style: _valueStyle(context),
          ),
          trailing: _chevron(context),
        ),

        // Duration — custom, stepped in 15-minute increments.
        _SettingCard(
          icon: Icons.schedule_outlined,
          label: 'Duration',
          value: Text(
            _durationText(data.durationMinutes),
            style: _valueStyle(context),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _CounterBtn(
                icon: Icons.remove,
                enabled: data.durationMinutes > _durationMin,
                emphasised: false,
                semanticLabel: 'Shorten duration',
                onTap: () => _form.setDurationMinutes(
                  data.durationMinutes - _durationStep,
                ),
              ),
              _CounterBtn(
                icon: Icons.add,
                enabled: data.durationMinutes < _durationMax,
                emphasised: true,
                semanticLabel: 'Extend duration',
                onTap: () => _form.setDurationMinutes(
                  data.durationMinutes + _durationStep,
                ),
              ),
            ],
          ),
        ),

        // Location.
        _SettingCard(
          icon: Icons.place_outlined,
          label: 'Location',
          value: TextField(
            controller: _locationController,
            style: _inputStyle(context),
            cursorColor: AppColors.primary,
            decoration: _dec(context, 'Riverside Court, Jakarta'),
            onChanged: _form.setLocation,
          ),
          trailing: data.location.isEmpty
              ? null
              : AppTappable(
                  onTap: () {
                    _locationController.clear();
                    _form.setLocation('');
                  },
                  semanticLabel: 'Clear location',
                  child: Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: context.colors.textTertiary,
                  ),
                ),
        ),

        // Max participants.
        _SettingCard(
          icon: Icons.group_outlined,
          label: 'Max Participants',
          value: Text(
            '${data.maxParticipants} players',
            style: _valueStyle(context),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _CounterBtn(
                icon: Icons.remove,
                enabled: data.maxParticipants > 2,
                emphasised: false,
                semanticLabel: 'Remove one participant',
                onTap: () => _form.setMaxParticipants(data.maxParticipants - 1),
              ),
              _CounterBtn(
                icon: Icons.add,
                enabled: data.maxParticipants < 50,
                emphasised: true,
                semanticLabel: 'Add one participant',
                onTap: () => _form.setMaxParticipants(data.maxParticipants + 1),
              ),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.x2),
        const _TipNote('You can always edit these details later.'),
      ],
    );
  }

  // ── Step 2 · Rules ────────────────────────────────────────────────────────

  Widget _buildRulesStep(ActivityFormData data, ImageUploadInfo uploadInfo) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.x5,
        AppSpacing.x2,
        AppSpacing.x5,
        AppSpacing.x8,
      ),
      children: [
        const _StepHeading(
          title: 'Tell us more about your game',
          subtitle: 'Set the rules and preferences',
        ),
        const SizedBox(height: AppSpacing.x4),

        // Skill level — a select field (opens the same picker as Sport).
        _FieldLabel('Skill Level'),
        const SizedBox(height: _kLabelGap),
        _SelectField(
          value: data.skillLevel,
          onTap: () => _showOptionPicker(
            title: 'Select Skill Level',
            options: _skillOptions,
            current: data.skillLevel,
            onSelect: _form.setSkillLevel,
          ),
        ),
        const SizedBox(height: AppSpacing.x4),

        // Entry — two selectable choice cards.
        _FieldLabel('Entry'),
        const SizedBox(height: _kLabelGap),
        Row(
          children: [
            Expanded(
              child: _ChoiceCard(
                icon: Icons.volunteer_activism_outlined,
                title: 'Free',
                subtitle: 'Anyone can join',
                selected: data.feeType == 0,
                onTap: () => _form.setFeeType(0),
              ),
            ),
            const SizedBox(width: AppSpacing.x3),
            Expanded(
              child: _ChoiceCard(
                icon: Icons.payments_outlined,
                title: 'Paid',
                subtitle: 'Set a price',
                selected: data.feeType == 1,
                onTap: () => _form.setFeeType(1),
              ),
            ),
          ],
        ),
        if (data.feeType == 1) ...[
          const SizedBox(height: AppSpacing.x3),
          Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x4),
            alignment: Alignment.centerLeft,
            decoration: BoxDecoration(
              color: context.colors.surface,
              borderRadius: BorderRadius.circular(AppRadius.input),
              border: Border.all(color: context.colors.border),
            ),
            child: Row(
              children: [
                Text(
                  '\$',
                  style: _inputStyle(
                    context,
                  ).copyWith(color: context.colors.textSecondary),
                ),
                const SizedBox(width: AppSpacing.x1),
                Expanded(
                  child: TextField(
                    controller: _priceController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    textInputAction: TextInputAction.done,
                    cursorColor: AppColors.primary,
                    style: _inputStyle(context),
                    decoration: _dec(context, '0.00'),
                    onChanged: _form.setPrice,
                  ),
                ),
                Text('per person', style: AppTypography.metaSub(context)),
              ],
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.x4),

        // Description.
        Row(
          children: [
            _FieldLabel('Description'),
            const SizedBox(width: 6),
            Text('(Optional)', style: AppTypography.metaSub(context)),
            const Spacer(),
            Text(
              '${data.description.length}/300',
              style: AppTypography.metaSub(context),
            ),
          ],
        ),
        const SizedBox(height: _kLabelGap),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.x4,
            vertical: AppSpacing.x3,
          ),
          decoration: BoxDecoration(
            color: context.colors.surface,
            borderRadius: BorderRadius.circular(AppRadius.input),
            border: Border.all(color: context.colors.border),
          ),
          child: TextField(
            controller: _descriptionController,
            style: _inputStyle(context),
            cursorColor: AppColors.primary,
            minLines: 3,
            maxLines: 5,
            inputFormatters: [LengthLimitingTextInputFormatter(300)],
            decoration: _dec(
              context,
              "Friendly 5v5 runs for intermediate players. Let's have fun "
              'and improve together!',
            ),
            onChanged: _form.setDescription,
          ),
        ),
        const SizedBox(height: AppSpacing.x4),

        // Photos.
        Row(
          children: [
            _FieldLabel('Add Photos'),
            const SizedBox(width: 6),
            Text('(Optional)', style: AppTypography.metaSub(context)),
          ],
        ),
        const SizedBox(height: _kLabelGap),
        _CoverPhoto(
          uploadInfo: uploadInfo,
          onTap: _pickImage,
          onRemove: () {
            ref.read(imageUploadProvider.notifier).reset();
            _form.setCoverImage(null);
          },
          onReplace: _pickImage,
        ),
      ],
    );
  }

  // ── Preview ─────────────────────────────────────────────────────────────

  Widget _buildPreviewStep(ActivityFormData data) {
    final preview = ActivityModel(
      id: 'preview',
      title: data.title.trim().isEmpty ? 'Your activity' : data.title.trim(),
      sportType: data.sportType,
      description: data.description.trim(),
      location: data.location.trim().isEmpty
          ? 'Location TBD'
          : data.location.trim(),
      distanceKm: 0,
      dateTime:
          data.selectedDate ?? DateTime.now().add(const Duration(hours: 2)),
      skillLevel: data.skillLevel,
      capacity: data.maxParticipants,
      participantCount: 1,
      hostName: 'You',
      durationMinutes: data.durationMinutes,
      isPaid: data.feeType == 1,
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.x5,
        AppSpacing.x2,
        AppSpacing.x5,
        AppSpacing.x8,
      ),
      children: [
        const _StepHeading(
          title: 'Almost there!',
          subtitle: 'This is how others will see your activity',
        ),
        const SizedBox(height: AppSpacing.x4),
        SizedBox(height: 540, child: DiscoveryCard(activity: preview)),
        const SizedBox(height: AppSpacing.x5),
        const _CheckRow('Your activity looks great.'),
        const SizedBox(height: AppSpacing.x2),
        const _CheckRow('You can edit details before creating.'),
      ],
    );
  }

  // ── Small inline helpers ─────────────────────────────────────────────────

  Widget _chevron(BuildContext context) => Icon(
    Icons.chevron_right_rounded,
    size: 20,
    color: context.colors.textTertiary,
  );

  TextStyle _valueStyle(BuildContext context) =>
      AppTypography.bodyMedium(context).copyWith(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: context.colors.textPrimary,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Step chrome
// ─────────────────────────────────────────────────────────────────────────────

/// Thin progress bar under the header showing wizard advancement.
class _StepProgressBar extends StatelessWidget {
  const _StepProgressBar({required this.step});
  final int step;

  @override
  Widget build(BuildContext context) {
    final fraction = switch (step) {
      0 => 0.5,
      _ => 1.0,
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.x5,
        0,
        AppSpacing.x5,
        AppSpacing.x3,
      ),
      child: ClipRRect(
        borderRadius: AppRadius.pillR,
        child: SizedBox(
          height: 5,
          child: Stack(
            children: [
              Positioned.fill(
                child: ColoredBox(color: context.colors.surfaceMuted),
              ),
              FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: fraction,
                child: const ColoredBox(color: AppColors.primary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepHeading extends StatelessWidget {
  const _StepHeading({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppTypography.headlineSmall(context)),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: AppTypography.bodyMedium(
            context,
          ).copyWith(color: context.colors.textSecondary),
        ),
      ],
    );
  }
}

/// Primary CTA with a small helper caption beneath it (steps 1 & 2).
class _PrimaryCta extends StatelessWidget {
  const _PrimaryCta({
    required this.label,
    required this.subtitle,
    required this.onPressed,
  });

  final String label;
  final String subtitle;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppButton(label: label, onPressed: onPressed),
        const SizedBox(height: 6),
        Text(subtitle, style: AppTypography.metaSub(context)),
      ],
    );
  }
}

class _TipNote extends StatelessWidget {
  const _TipNote(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.x3),
      decoration: BoxDecoration(
        color: context.colors.surfaceSubtle,
        borderRadius: BorderRadius.circular(AppRadius.input),
      ),
      child: Row(
        children: [
          Icon(
            Icons.lightbulb_outline_rounded,
            size: 18,
            color: AppColors.accent,
          ),
          const SizedBox(width: AppSpacing.x2),
          Expanded(child: Text(text, style: AppTypography.metaSub(context))),
        ],
      ),
    );
  }
}

class _CheckRow extends StatelessWidget {
  const _CheckRow(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          Icons.check_circle_rounded,
          size: 20,
          color: context.colors.successText,
        ),
        const SizedBox(width: AppSpacing.x2),
        Expanded(
          child: Text(
            text,
            style: AppTypography.bodyMedium(
              context,
            ).copyWith(color: context.colors.textPrimary),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Setting card (step 1 rows)
// ─────────────────────────────────────────────────────────────────────────────

class _SettingCard extends StatelessWidget {
  const _SettingCard({
    required this.icon,
    required this.label,
    this.value,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final Widget? value;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.x3),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.x4,
        vertical: AppSpacing.x3,
      ),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _IconBox(icon),
              const SizedBox(width: AppSpacing.x3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: AppTypography.metaSub(context)),
                    if (value != null) ...[const SizedBox(height: 2), value!],
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: AppSpacing.x2),
                trailing!,
              ],
            ],
          ),
        ],
      ),
    );

    if (onTap == null) return card;
    return PressableScale(onTap: onTap, child: card);
  }
}

class _IconBox extends StatelessWidget {
  const _IconBox(this.icon);
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: context.colors.primarySoft,
        borderRadius: BorderRadius.circular(AppRadius.input),
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: 19, color: context.colors.primaryOnSurface),
    );
  }
}

/// Tappable select field (value + chevron) — opens an option picker sheet.
/// Used for Skill Level, matching the Sport select on step 1.
class _SelectField extends StatelessWidget {
  const _SelectField({required this.value, required this.onTap});

  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      label: value,
      child: PressableScale(
        onTap: onTap,
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x4),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(AppRadius.input),
            border: Border.all(color: c.border),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  value,
                  style: AppTypography.bodyMedium(context).copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: c.textPrimary,
                  ),
                ),
              ),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 20,
                color: c.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Cover photo uploader
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

    return Semantics(
      button: true,
      label: done
          ? 'Cover photo'
          : loading
          ? 'Uploading cover photo'
          : 'Add cover photo',
      child: PressableScale(
        onTap: done || loading ? null : onTap,
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              color: context.colors.surfaceInverse,
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
                  if (!done && !loading)
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: context.colors.textOnPrimary.withValues(
                              alpha: 0.12,
                            ),
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                          alignment: Alignment.center,
                          child: Icon(
                            Icons.add_photo_alternate_outlined,
                            size: 26,
                            color: context.colors.textOnPrimary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.x3),
                        Text(
                          'Add a photo of the court or your game',
                          style: AppTypography.labelField(
                            context,
                          ).copyWith(color: context.colors.textOnPrimary),
                        ),
                      ],
                    ),
                  if (loading)
                    ColoredBox(
                      color: context.colors.scrim,
                      child: Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            context.colors.textOnPrimary,
                          ),
                          strokeWidth: 2.5,
                        ),
                      ),
                    ),
                  if (uploadInfo.state == ImageUploadState.failed)
                    ColoredBox(
                      color: context.colors.scrim,
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.x4),
                          child: Text(
                            uploadInfo.errorMessage ?? 'Failed',
                            style: AppTypography.labelField(
                              context,
                            ).copyWith(color: context.colors.textOnPrimary),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
                  if (done)
                    Positioned(
                      bottom: AppSpacing.x2,
                      right: AppSpacing.x2,
                      child: Row(
                        children: [
                          _PhotoBtn(
                            icon: Icons.edit_rounded,
                            onTap: onReplace,
                            semanticLabel: 'Replace cover photo',
                          ),
                          const SizedBox(width: AppSpacing.x2),
                          _PhotoBtn(
                            icon: Icons.delete_outline_rounded,
                            onTap: onRemove,
                            danger: true,
                            semanticLabel: 'Remove cover photo',
                          ),
                        ],
                      ),
                    ),
                ],
              ),
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
    required this.semanticLabel,
    this.danger = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String semanticLabel;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color =
        danger ? context.colors.errorText : context.colors.primaryOnSurface;
    return AppTappable(
      onTap: onTap,
      semanticLabel: semanticLabel,
      feedback: AppTapFeedback.scale,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: context.colors.surface,
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
// Shared form primitives
// ─────────────────────────────────────────────────────────────────────────────

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) =>
      Text(text, style: AppTypography.labelField(context));
}

const double _kLabelGap = 6;

TextStyle _inputStyle(BuildContext context) => AppTypography.bodyFormSecondary(
  context,
).copyWith(color: context.colors.textPrimary);

InputDecoration _dec(BuildContext context, String hint) => InputDecoration(
  hintText: hint,
  hintStyle: AppTypography.bodyFormSecondary(
    context,
  ).copyWith(color: context.colors.textTertiary),
  // No fill — the field blends into its white setting card. The themed
  // grey fill made the input read as a separate boxed control (not modern).
  filled: false,
  border: InputBorder.none,
  enabledBorder: InputBorder.none,
  focusedBorder: InputBorder.none,
  isDense: true,
  contentPadding: EdgeInsets.zero,
);

/// Stepper button — decrement is a neutral outlined circle, increment is a
/// filled `primarySoft` circle. Visual size 32; touch target padded to 44.
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
  final bool emphasised;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final Color fill;
    final Color iconColor;
    final BoxBorder? border;

    if (!enabled) {
      fill = context.colors.surfaceSubtle;
      iconColor = context.colors.textTertiary;
      border = Border.all(color: context.colors.border);
    } else if (emphasised) {
      fill = context.colors.primarySoft;
      iconColor = context.colors.primaryOnSurface;
      border = null;
    } else {
      fill = context.colors.surfaceSubtle;
      iconColor = context.colors.textPrimary;
      border = Border.all(color: context.colors.border);
    }

    return Semantics(
      button: true,
      enabled: enabled,
      label: semanticLabel,
      child: PressableScale(
        onTap: enabled ? onTap : null,
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

/// Selectable choice card — icon + title + subtitle, with a highlighted
/// selected state. Used for the Free / Paid entry choice.
class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final accent = selected ? c.primaryOnSurface : c.textSecondary;
    return Semantics(
      button: true,
      selected: selected,
      label: title,
      child: PressableScale(
        onTap: onTap,
        child: AnimatedContainer(
          duration: AppDurations.fast,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.x4,
            vertical: AppSpacing.x3,
          ),
          decoration: BoxDecoration(
            color: selected ? c.primarySoft : c.surface,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(
              color: selected ? c.primaryOnSurface : c.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(icon, size: 22, color: accent),
              const SizedBox(width: AppSpacing.x3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTypography.bodyMedium(context).copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: selected ? c.primaryOnSurface : c.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.metaSub(context),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
