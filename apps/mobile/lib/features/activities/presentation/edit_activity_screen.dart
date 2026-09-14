import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/repository_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/dark_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/geohash.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/error_retry.dart';
import '../../../core/widgets/pressable_scale.dart';
import '../../../core/widgets/skeleton.dart';
import '../../discovery/domain/activity_model.dart';
import '../domain/place_suggestion.dart';
import 'widgets/venue_field.dart';

/// Host-only edit screen for an existing activity.
///
/// Prefills every field from the loaded activity and PATCHes only what
/// the host changed (venue coordinates travel along when the venue is
/// re-picked). Returns `true` via pop on success so the caller
/// (manage screen) can refresh its detail provider.
class EditActivityScreen extends ConsumerStatefulWidget {
  const EditActivityScreen({super.key, required this.activityId});
  final String activityId;

  @override
  ConsumerState<EditActivityScreen> createState() => _EditActivityScreenState();
}

final _editActivityProvider = FutureProvider.autoDispose
    .family<ActivityModel?, String>((ref, id) {
  return ref.watch(activityRepositoryProvider).byId(id);
});

class _EditActivityScreenState extends ConsumerState<EditActivityScreen> {
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
  static const _skillOptions = [
    'All Level',
    'Beginner',
    'Intermediate',
    'Advanced',
  ];

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  bool _initialised = false;
  bool _saving = false;

  String _sport = 'Basketball';
  DateTime? _date;
  int _durationMinutes = 120;
  PlaceSuggestion? _venue;
  int _capacity = 10;
  int _minCapacity = 2;
  String _skill = 'All Level';
  String _joinPolicy = 'open';

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _initFrom(ActivityModel a) {
    _titleController.text = a.title;
    _descriptionController.text = a.description;
    _sport = _sportOptions.contains(a.sportType) ? a.sportType : 'Basketball';
    _date = a.dateTime;
    _durationMinutes = a.durationMinutes;
    _capacity = a.capacity;
    _minCapacity = a.participantCount.clamp(2, a.capacity);
    if (_capacity < _minCapacity) _capacity = _minCapacity;
    _skill = _skillOptions.contains(a.skillLevel) ? a.skillLevel : 'All Level';
    _joinPolicy = a.joinPolicy;
    if (a.latitude != null && a.longitude != null) {
      _venue = PlaceSuggestion(
        placeId: 'existing',
        label: a.location,
        secondary: '',
        latitude: a.latitude!,
        longitude: a.longitude!,
      );
    }
    _initialised = true;
  }

  String? _error() {
    if (_titleController.text.trim().isEmpty) {
      return 'Please enter a title.';
    }
    if (_venue == null) return 'Please pick a venue on the map.';
    if (_date == null) return 'Please pick a date and time.';
    return null;
  }

  Future<void> _save(ActivityModel original) async {
    final err = _error();
    if (err != null) {
      AppSnackbar.show(context,
          message: err, variant: AppSnackbarVariant.error);
      return;
    }
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final venue = _venue!;
      final start = _date!;
      await ref.read(activityRepositoryProvider).updateActivity(
            activityId: widget.activityId,
            title: _titleController.text.trim(),
            sportType: _sport,
            description: _descriptionController.text.trim(),
            locationName: venue.label,
            latitude: venue.latitude,
            longitude: venue.longitude,
            geohash: geohashEncode(venue.latitude, venue.longitude),
            startTime: start,
            endTime: start.add(Duration(minutes: _durationMinutes)),
            skillLevel: _skill,
            capacity: _capacity,
            joinPolicy: _joinPolicy,
          );
      if (!mounted) return;
      // Pop silent — the manage screen shows the confirmation snackbar
      // (a snackbar shown here would die with this route).
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      AppSnackbar.show(
        context,
        message: 'Could not save changes. Please try again.',
        variant: AppSnackbarVariant.error,
      );
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _date ?? now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_date ?? now),
    );
    if (time == null) return;
    setState(() {
      _date = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _pickOption({
    required String title,
    required List<String> options,
    required String current,
    required ValueChanged<String> onSelect,
  }) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.fromLTRB(
          AppSpacing.x4,
          AppSpacing.x3,
          AppSpacing.x4,
          AppSpacing.x5 + MediaQuery.of(sheetContext).viewPadding.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: context.colors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.x3),
            Text(title, style: AppTypography.titleMedium(context)),
            const SizedBox(height: AppSpacing.x2),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (_, i) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(options[i]),
                  trailing: options[i] == current
                      ? Icon(Icons.check_rounded,
                          color: context.colors.primaryOnSurface)
                      : null,
                  onTap: () => Navigator.of(sheetContext).pop(options[i]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    if (selected != null) onSelect(selected);
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(_editActivityProvider(widget.activityId));
    return AppScaffold(
      showHomeIndicator: false,
      backgroundColor: context.colors.background,
      body: async.when(
        loading: () => const SkeletonList(count: 4),
        error: (_, _) => ErrorRetry(
          message: 'Could not load this activity.',
          onRetry: () =>
              ref.invalidate(_editActivityProvider(widget.activityId)),
        ),
        data: (activity) {
          if (activity == null) {
            return const Center(child: Text('Activity not found.'));
          }
          if (!_initialised) {
            // Prefill once — guarded so typing never gets clobbered
            // by a provider rebuild.
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && !_initialised) {
                setState(() => _initFrom(activity));
              }
            });
            return const SkeletonList(count: 4);
          }
          return Column(
            children: [
              _Header(
                saving: _saving,
                onBack: () => Navigator.of(context).maybePop(),
                onSave: () => _save(activity),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.x5,
                    AppSpacing.x3,
                    AppSpacing.x5,
                    AppSpacing.x8,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _Label('Title'),
                      _TextBox(
                        controller: _titleController,
                        hint: 'Weekend Basketball Runs',
                      ),
                      const SizedBox(height: AppSpacing.x4),
                      _Label('Sport'),
                      _OptionRow(
                        value: _sport,
                        onTap: () => _pickOption(
                          title: 'Sport',
                          options: _sportOptions,
                          current: _sport,
                          onSelect: (v) => setState(() => _sport = v),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.x4),
                      _Label('Date & time'),
                      _OptionRow(
                        value: _date == null
                            ? 'Pick a date'
                            : DateFormat('EEE, MMM d · h:mm a').format(_date!),
                        onTap: _pickDate,
                      ),
                      const SizedBox(height: AppSpacing.x4),
                      _Label('Duration'),
                      _StepperRow(
                        value: _formatDuration(_durationMinutes),
                        onMinus: _durationMinutes > 30
                            ? () => setState(
                                () => _durationMinutes -= 15)
                            : null,
                        onPlus: _durationMinutes < 480
                            ? () => setState(
                                () => _durationMinutes += 15)
                            : null,
                        minusLabel: 'Shorten duration',
                        plusLabel: 'Extend duration',
                      ),
                      const SizedBox(height: AppSpacing.x4),
                      VenueField(
                        value: _venue,
                        onSuggestionSelected: (s) =>
                            setState(() => _venue = s),
                      ),
                      const SizedBox(height: AppSpacing.x4),
                      _Label('Max participants'),
                      _StepperRow(
                        value: '$_capacity players',
                        onMinus: _capacity > _minCapacity
                            ? () => setState(() => _capacity -= 1)
                            : null,
                        onPlus: _capacity < 50
                            ? () => setState(() => _capacity += 1)
                            : null,
                        minusLabel: 'Remove one participant',
                        plusLabel: 'Add one participant',
                      ),
                      const SizedBox(height: AppSpacing.x4),
                      _Label('Skill level'),
                      _OptionRow(
                        value: _skill,
                        onTap: () => _pickOption(
                          title: 'Skill level',
                          options: _skillOptions,
                          current: _skill,
                          onSelect: (v) => setState(() => _skill = v),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.x4),
                      _Label('Who can join'),
                      Row(
                        children: [
                          Expanded(
                            child: _PolicyCard(
                              title: 'Open',
                              subtitle: 'Instant join',
                              selected: _joinPolicy == 'open',
                              onTap: () =>
                                  setState(() => _joinPolicy = 'open'),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.x3),
                          Expanded(
                            child: _PolicyCard(
                              title: 'Approval',
                              subtitle: 'Host approves',
                              selected: _joinPolicy == 'approval',
                              onTap: () =>
                                  setState(() => _joinPolicy = 'approval'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.x4),
                      _Label('Description'),
                      _TextBox(
                        controller: _descriptionController,
                        hint: 'What should players know?',
                        maxLines: 4,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  static String _formatDuration(int minutes) {
    if (minutes < 60) return '$minutes min';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (m == 0) return h == 1 ? '1 hour' : '$h hours';
    return '$h h $m min';
  }
}

// ─── Small building blocks (screen-local) ────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({
    required this.saving,
    required this.onBack,
    required this.onSave,
  });
  final bool saving;
  final VoidCallback onBack;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: context.colors.surface,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.x2,
        AppSpacing.x2,
        AppSpacing.x4,
        AppSpacing.x3,
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            Semantics(
              button: true,
              label: 'Back',
              child: GestureDetector(
                onTap: saving ? null : onBack,
                child: const Padding(
                  padding: EdgeInsets.all(10),
                  child: Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                ),
              ),
            ),
            Expanded(
              child: Text(
                'Edit Activity',
                style: AppTypography.titleMedium(context),
              ),
            ),
            PressableScale(
              onTap: saving ? null : onSave,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.x5,
                  vertical: AppSpacing.x2,
                ),
                decoration: BoxDecoration(
                  color: saving
                      ? context.colors.surfaceMuted
                      : AppColors.primary,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                alignment: Alignment.center,
                child: saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.textOnPrimary,
                        ),
                      )
                    : Text(
                        'Save',
                        style: AppTypography.buttonPrimary.copyWith(
                          color: AppColors.textOnPrimary,
                          fontSize: 14,
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

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.x2),
      child: Text(text, style: AppTypography.labelField(context)),
    );
  }
}

class _TextBox extends StatelessWidget {
  const _TextBox({
    required this.controller,
    required this.hint,
    this.maxLines = 1,
  });
  final TextEditingController controller;
  final String hint;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x4),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.input),
        border: Border.all(color: context.colors.border),
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        style: AppTypography.bodyMedium(context),
        cursorColor: AppColors.primary,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: AppTypography.bodyMedium(context).copyWith(
            color: context.colors.textTertiary,
          ),
          border: InputBorder.none,
        ),
      ),
    );
  }
}

class _OptionRow extends StatelessWidget {
  const _OptionRow({required this.value, required this.onTap});
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.x4,
          vertical: AppSpacing.x3,
        ),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(AppRadius.input),
          border: Border.all(color: context.colors.border),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                value,
                style: AppTypography.bodyMedium(context),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: context.colors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}

class _StepperRow extends StatelessWidget {
  const _StepperRow({
    required this.value,
    required this.onMinus,
    required this.onPlus,
    required this.minusLabel,
    required this.plusLabel,
  });
  final String value;
  final VoidCallback? onMinus;
  final VoidCallback? onPlus;
  final String minusLabel;
  final String plusLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.x4,
        vertical: AppSpacing.x2,
      ),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.input),
        border: Border.all(color: context.colors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(value, style: AppTypography.bodyMedium(context)),
          ),
          Semantics(
            button: true,
            label: minusLabel,
            child: GestureDetector(
              onTap: onMinus,
              child: Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: context.colors.border),
                ),
                child: Icon(Icons.remove_rounded,
                    size: 18, color: context.colors.textPrimary),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.x2),
          Semantics(
            button: true,
            label: plusLabel,
            child: GestureDetector(
              onTap: onPlus,
              child: Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.add_rounded,
                    size: 18, color: AppColors.textOnPrimary),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PolicyCard extends StatelessWidget {
  const _PolicyCard({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.x3),
        decoration: BoxDecoration(
          color: selected
              ? context.colors.primarySoft
              : context.colors.surface,
          borderRadius: BorderRadius.circular(AppRadius.input),
          border: Border.all(
            color: selected
                ? context.colors.primaryOnSurface
                : context.colors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: AppTypography.labelField(context).copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(subtitle, style: AppTypography.metaSub(context)),
          ],
        ),
      ),
    );
  }
}
