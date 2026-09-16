import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/network/api_client.dart';

import '../../../core/providers/repository_providers.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/storage/local_storage.dart';
import '../../../core/utils/geohash.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/dark_colors.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/app_segmented_control.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/app_tappable.dart';
import '../../../core/widgets/date_picker_sheet.dart';
import '../../../core/widgets/pressable_scale.dart';
import '../../discovery/presentation/widgets/discovery_card.dart';
import '../../sports/domain/sport_config.dart';
import '../domain/activity_model.dart';
import 'create/components/image_picker_modal.dart';
import 'create/providers/form_data_provider.dart';
import 'create/services/form_validator.dart' show validateField;
import '../domain/place_suggestion.dart';
import 'widgets/venue_field.dart';
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
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  PlaceSuggestion? _venue;
  static final _picker = ImagePicker();

  int _step = _stepSetup;
  bool _submitting = false;

  /// True after a blocked Continue attempt — reveals inline field
  /// errors on the setup step. Reset once the step validates.
  bool _setupAttempted = false;

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

  /// Modern, consistent metadata for every "tipe" picker so Sport, Skill,
  /// Entry, and Join Policy all speak the same visual language
  /// (icon + title + subtitle).
  static const _sportIcons = <String, IconData>{
    'Basketball': Icons.sports_basketball_outlined,
    'Tennis': Icons.sports_tennis_outlined,
    'Running': Icons.directions_run_outlined,
    'Volleyball': Icons.sports_volleyball_outlined,
    'Football': Icons.sports_football_outlined,
    'Soccer': Icons.sports_soccer_outlined,
    'Cycling': Icons.directions_bike_outlined,
    'Hiking': Icons.hiking_outlined,
    'Golf': Icons.sports_golf_outlined,
    'Swimming': Icons.pool_outlined,
  };

  static final _skillMeta = <String, ({IconData icon, String subtitle})>{
    'All Level': (icon: Icons.groups_outlined, subtitle: 'Everyone welcome'),
    'Beginner': (icon: Icons.eco_outlined, subtitle: 'Just starting out'),
    'Intermediate': (
      icon: Icons.trending_up_outlined,
      subtitle: 'Knows the basics'
    ),
    'Advanced': (icon: Icons.bolt_outlined, subtitle: 'Competitive play'),
  };

  static final _joinPolicyMeta = <String, ({IconData icon, String title, String subtitle})>{
    'open': (
      icon: Icons.lock_open_outlined,
      title: 'Open',
      subtitle: 'Anyone can join instantly'
    ),
    'approval': (
      icon: Icons.verified_outlined,
      title: 'Approval',
      subtitle: 'You approve each request'
    ),
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _restoreOrReset());
  }

  /// Draft persistence (spec Phase 5, MVP scope): the form is JSON-
  /// serialisable via [ActivityFormData.toJson], so a draft survives app
  /// restarts and is restored on reopen. Cleared on successful submit.
  /// Cover image bytes are NOT persisted (too large for prefs); the
  /// picked venue (label, address, lat/lng) IS persisted and rebuilt
  /// into `_venue` on restore.
  /// Crop tool intentionally skipped: `image_picker` maxWidth/maxHeight/
  /// imageQuality already constrains uploads (see audit A-plan §3).
  static const _draftKey = 'create_activity_draft_v1';

  Future<void> _restoreOrReset() async {
    try {
      final store = await LocalStorage.create();
      final raw = store.getString(_draftKey);
      if (raw != null && raw.isNotEmpty && mounted) {
        final data = ActivityFormData.fromJson(
          Map<String, dynamic>.from(jsonDecode(raw) as Map),
        );
        if (data.title.trim().isNotEmpty ||
            data.location.trim().isNotEmpty ||
            data.description.trim().isNotEmpty) {
          ref.read(imageUploadProvider.notifier).reset();
          final form = ref.read(formDataProvider.notifier)
            ..reset()
            ..setTitle(data.title)
            ..setSportType(data.sportType)
            ..setLocation(data.location)
            ..setDescription(data.description)
            ..setMaxParticipants(data.maxParticipants)
            ..setSkillLevel(data.skillLevel)
            ..setFeeType(data.feeType)
            ..setPrice(data.price)
            ..setPriceMode(data.priceMode)
            ..setMinPlayers(data.minPlayers)
            ..setDurationMinutes(data.durationMinutes)
            ..setJoinPolicy(data.joinPolicy);
          if (data.selectedDate != null &&
              data.selectedDate!.isAfter(DateTime.now())) {
            form.setSelectedDate(data.selectedDate);
          } else {
            form.setSelectedDate(DateTime.now().add(const Duration(hours: 2)));
          }
          _titleController.text = data.title;
          _descriptionController.text = data.description;
          _priceController.text = data.price ?? '';
          // Rebuild the picked venue so the address + accurate pin
          // survive the restore (previously only the label text came
          // back and submit fell back to default coords).
          setState(() {
            final lat = data.venueLatitude;
            final lng = data.venueLongitude;
            _venue = (lat != null && lng != null &&
                    data.location.trim().isNotEmpty)
                ? PlaceSuggestion(
                    placeId: '',
                    label: data.location,
                    secondary: data.venueAddress,
                    latitude: lat,
                    longitude: lng,
                  )
                : null;
          });
          return;
        }
      }
    } catch (_) {
      // No usable draft (fresh install, test harness without prefs plugin,
      // or corrupt JSON) — fall through to a clean form.
    }
    if (!mounted) return;
    ref.read(imageUploadProvider.notifier).reset();
    ref.read(formDataProvider.notifier)
      ..reset()
      ..setSelectedDate(DateTime.now().add(const Duration(hours: 2)));
    setState(() => _venue = null);
    _titleController.clear();
    _descriptionController.clear();
    _priceController.clear();
  }

  Future<void> _saveDraft() async {
    try {
      final store = await LocalStorage.create();
      final data = ref.read(formDataProvider);
      await store.setString(_draftKey, jsonEncode(data.toJson()));
    } catch (_) {
      // Draft is best-effort; a failed save must never block the wizard.
    }
  }

  Future<void> _clearDraft() async {
    try {
      final store = await LocalStorage.create();
      await store.remove(_draftKey);
    } catch (_) {
      // Best-effort only.
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
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
    String? subtitle,
    required List<String> options,
    required String current,
    required ValueChanged<String> onSelect,
    IconData Function(String option)? iconFor,
    String Function(String option)? subtitleFor,
  }) {
    HapticFeedback.selectionClick();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: context.colors.surface,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(AppRadius.xl),
              ),
              boxShadow: AppShadows.sheet,
            ),
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.x5,
              AppSpacing.x3,
              AppSpacing.x5,
              AppSpacing.x6,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: AppSpacing.x4),
                    decoration: BoxDecoration(
                      color: context.colors.border,
                      borderRadius: AppRadius.pillR,
                    ),
                  ),
                ),
                Text(
                  title,
                  style: AppTypography.titleLarge(
                    context,
                  ).copyWith(fontWeight: FontWeight.w800),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppTypography.bodyMedium(context).copyWith(
                      color: context.colors.textSecondary,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.x4),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: options.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppSpacing.x2),
                    itemBuilder: (context, index) {
                      final opt = options[index];
                      final selected = opt == current;
                      final icon = iconFor?.call(opt);
                      final sub = subtitleFor?.call(opt);
                      final c = context.colors;
                      return PressableScale(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          onSelect(opt);
                          Navigator.of(context).pop();
                        },
                        child: AnimatedContainer(
                          duration: AppDurations.fast,
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.x4,
                            vertical: AppSpacing.x3,
                          ),
                          decoration: BoxDecoration(
                            color: selected ? c.primarySoft : c.surface,
                            borderRadius: BorderRadius.circular(
                              AppRadius.card,
                            ),
                            border: Border.all(
                              color: selected ? c.primaryOnSurface : c.border,
                              width: selected ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              if (icon != null) ...[
                                Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: selected
                                        ? c.surface
                                        : c.surfaceSubtle,
                                    borderRadius: BorderRadius.circular(
                                      AppRadius.input,
                                    ),
                                  ),
                                  alignment: Alignment.center,
                                  child: Icon(
                                    icon,
                                    size: 19,
                                    color: selected
                                        ? c.primaryOnSurface
                                        : c.textSecondary,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.x3),
                              ],
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _joinPolicyMeta[opt]?.title ?? opt,
                                      style: AppTypography.bodyMedium(context)
                                          .copyWith(
                                            fontSize: 15,
                                            color: selected
                                                ? c.primaryOnSurface
                                                : c.textPrimary,
                                            fontWeight: selected
                                                ? FontWeight.w700
                                                : FontWeight.w600,
                                          ),
                                    ),
                                    if (sub != null) ...[
                                      const SizedBox(height: 1),
                                      Text(
                                        sub,
                                        style: AppTypography.metaSub(context),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(width: AppSpacing.x2),
                              AnimatedContainer(
                                duration: AppDurations.fast,
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: selected
                                      ? c.primaryOnSurface
                                      : Colors.transparent,
                                  border: Border.all(
                                    color: selected
                                        ? c.primaryOnSurface
                                        : c.borderInput,
                                    width: 1.5,
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: selected
                                    ? const Icon(
                                        Icons.check_rounded,
                                        size: 15,
                                        color: Colors.white,
                                      )
                                    : null,
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
      // Reveal inline field errors in addition to the snackbar, so a
      // missing venue can't be mistaken for "lanjut".
      setState(() => _setupAttempted = true);
      AppSnackbar.show(
        context,
        message: err,
        variant: AppSnackbarVariant.error,
      );
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _setupAttempted = false;
      _step = _stepRules;
    });
    unawaited(_saveDraft());
  }

  void _goToPreview() {
    final data = ref.read(formDataProvider);
    if (data.feeType == 1) {
      final price = double.tryParse(_priceController.text.trim());
      if (price == null || price <= 0) {
        AppSnackbar.show(
          context,
          message: data.priceMode == 1
              ? 'Please enter a valid total cost.'
              : 'Please enter a valid price.',
          variant: AppSnackbarVariant.error,
        );
        return;
      }
    }
    FocusScope.of(context).unfocus();
    setState(() => _step = _stepPreview);
    unawaited(_saveDraft());
  }

  /// First blocking issue on the setup step, or null when it's good to go.
  String? _setupError(ActivityFormData data) {
    if (data.title.trim().isEmpty) return 'Please enter an activity title.';
    // A venue pick carries coordinates — a bare location string without
    // them (stale draft) must re-pick instead of silently submitting
    // with fallback coordinates.
    if (data.location.trim().isEmpty ||
        (data.venueLatitude == null && _venue == null)) {
      return 'Please pick a venue on the map.';
    }
    final date = data.selectedDate;
    if (date == null || date.isBefore(DateTime.now())) {
      return 'Please pick a future date and time.';
    }
    if (data.maxParticipants < 2) return 'Minimum 2 participants required.';
    return null;
  }

  /// Uploads the selected cover image and returns its download URL, or
  /// `null` when there is no image / the upload fails. Photo is optional
  /// so failures never block activity creation.
  ///
  /// The draft stores the picked bytes as base64 via `setCoverImage`
  /// (see [_pickImage]); [StorageService.uploadImage] needs a local file
  /// path, so base64 payloads are decoded into a temp file first. A
  /// value that already points at an existing file is uploaded directly.
  Future<String?> _uploadCoverImage(String? stored) async {
    if (stored == null || stored.isEmpty) return null;
    try {
      if (await File(stored).exists()) {
        return await StorageService.instance.uploadImage(
          localPath: stored,
          folder: 'activity-covers',
        );
      }
      final bytes = base64.decode(stored);
      final dir = await Directory.systemTemp.createTemp('cover_');
      final file = File(
        '${dir.path}/cover_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      await file.writeAsBytes(bytes, flush: true);
      return await StorageService.instance.uploadImage(
        localPath: file.path,
        folder: 'activity-covers',
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final data = ref.read(formDataProvider);
    // Never silently substitute a fallback date: re-validate the setup
    // step and abort with the reason when it's not good to go.
    final setupErr = _setupError(data);
    if (setupErr != null) {
      if (!mounted) return;
      AppSnackbar.show(
        context,
        message: setupErr,
        variant: AppSnackbarVariant.error,
      );
      return;
    }
    // Shared rules (same messages as the wizard validators): capacity
    // cap and price format.
    final capErr = validateField(
      'maxParticipants',
      '${data.maxParticipants}',
      data,
    );
    if (capErr != null) {
      if (!mounted) return;
      AppSnackbar.show(
        context,
        message: capErr,
        variant: AppSnackbarVariant.error,
      );
      return;
    }
    final paid = data.feeType == 1;
    if (paid) {
      final priceErr = validateField(
        'price',
        _priceController.text.trim(),
        data,
      );
      if (priceErr != null) {
        if (!mounted) return;
        AppSnackbar.show(
          context,
          message: priceErr,
          variant: AppSnackbarVariant.error,
        );
        return;
      }
    }
    final split = paid && data.priceMode == 1;
    final amount = double.tryParse(_priceController.text.trim());
    if (paid && (amount == null || amount <= 0)) {
      AppSnackbar.show(
        context,
        message: split
            ? 'Please enter a valid total cost.'
            : 'Please enter a valid price.',
        variant: AppSnackbarVariant.error,
      );
      return;
    }
    // Split: clamp min into 2..capacity (null = full house). The stored
    // `fee` is the worst-case per-person price so old clients still
    // render a number.
    final minPlayers = split
        ? (data.minPlayers ?? data.maxParticipants)
            .clamp(2, data.maxParticipants)
        : null;
    final perPerson = split && minPlayers != null
        ? (amount! / minPlayers * 100).round() / 100
        : amount;

    setState(() => _submitting = true);
    final pickedVenue = _venue;
    // Venue coords: the form's persisted pick wins (survives draft
    // restore); the in-memory `_venue` covers picks made this session.
    // Falls back to central Auckland (the seed-data centre).
    final double pickedLat =
        data.venueLatitude ?? pickedVenue?.latitude ?? -36.8485;
    final double pickedLng =
        data.venueLongitude ?? pickedVenue?.longitude ?? 174.7633;
    final String pickedGeohash = geohashEncode(pickedLat, pickedLng);
    final String? pickedAddress = data.venueAddress.trim().isNotEmpty
        ? data.venueAddress.trim()
        : pickedVenue?.secondary.trim().isNotEmpty == true
            ? pickedVenue!.secondary.trim()
            : null;
    // Cover photo is optional: upload the selected image (stored as
    // base64 in the draft via setCoverImage) and pass the URL through.
    // Any upload failure falls back to creating without a photo.
    final String? coverImageUrl = await _uploadCoverImage(data.coverImagePath);
    try {
      await ref
          .read(activityRepositoryProvider)
          .create(
            title: data.title.trim(),
            description: data.description.trim(),
            sportType: data.sportType,
            location: data.location.trim(),
            address: pickedAddress,
            // Validated at the top of [_submit] — never a silent
            // now()+2h substitution.
            dateTime: data.selectedDate!,
            maxParticipants: data.maxParticipants,
            skillLevel: data.skillLevel,
            latitude: pickedLat,
            longitude: pickedLng,
            geohash: pickedGeohash,
            coverImageUrl: coverImageUrl,
            durationMinutes: data.durationMinutes,
            joinPolicy: data.joinPolicy,
            isPaid: paid,
            fee: paid ? perPerson : null,
            feeMode: split ? 'split' : 'fixed',
            totalCost: split ? amount : null,
            minPlayers: split && minPlayers != null && minPlayers < data.maxParticipants
                ? minPlayers
                : null,
          );
      _form.reset();
      ref.read(imageUploadProvider.notifier).reset();
      await _clearDraft();
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      AppSnackbar.show(
        context,
        message: 'Activity created! 🎉',
        variant: AppSnackbarVariant.success,
      );
      context.go('/activities');
    } catch (e) {
      if (!mounted) return;
      debugPrint('[CreateActivity] submit failed: $e');
      // Prefer the backend's own message (validation, conflicts, …)
      // over the generic fallback so failures explain themselves.
      final message = e is DioException && e.error is ApiException
          ? (e.error as ApiException).userMessage
          : 'Could not create activity. Please try again.';
      // Retry path (spec Phase 4): the form is NOT reset on failure, so
      // tapping Retry reuses every field exactly as the user left it.
      AppSnackbar.show(
        context,
        message: message,
        variant: AppSnackbarVariant.error,
        duration: const Duration(seconds: 5),
        actionLabel: 'Retry',
        onAction: _submit,
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
    // Inline errors appear only after a blocked Continue attempt —
    // pristine fields stay clean.
    final titleErr =
        _setupAttempted && data.title.trim().isEmpty ? 'Please enter an activity title.' : null;
    final venueErr = _setupAttempted &&
            (data.location.trim().isEmpty ||
                (data.venueLatitude == null && _venue == null))
        ? 'Please pick a venue on the map.'
        : null;
    final dateErr = _setupAttempted &&
            (data.selectedDate == null ||
                data.selectedDate!.isBefore(DateTime.now()))
        ? 'Please pick a future date and time.'
        : null;
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
          error: titleErr,
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
            subtitle: 'What will you be playing?',
            // Admin-curated list (canHost); bundled fallback offline.
            options: pickSportNames(
              ref.watch(sportsConfigProvider).valueOrNull ?? const [],
              (s) => s.canHost,
              _sportOptions,
            ),
            current: data.sportType,
            onSelect: _form.setSportType,
            iconFor: (o) =>
                _sportIcons[o] ?? Icons.sports_basketball_outlined,
          ),
          value: Text(data.sportType, style: _valueStyle(context)),
          trailing: _chevron(context),
        ),

        // Date & time.
        _SettingCard(
          icon: Icons.calendar_month_outlined,
          label: 'Date & Time',
          error: dateErr,
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

        // Location — venue picker with OSM map. Picking a venue
        // populates both the local `_venue` state (so we get
        // accurate lat/lng on submit) AND the form's location
        // string (so the `_setupError` validator treats the
        // setup step as complete).
        VenueField(
          value: _venue,
          errorText: venueErr,
          onSuggestionSelected: (s) {
            setState(() => _venue = s);
            _form.setVenue(
              label: s.label,
              address: s.secondary,
              latitude: s.latitude,
              longitude: s.longitude,
            );
          },
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

        // Skill level — consistent 2-col choice grid, same language as
        // Entry / Join Policy below (no more bare dropdown).
        _FieldLabel('Skill Level'),
        const SizedBox(height: 2),
        Text(
          'Who is this game for?',
          style: AppTypography.metaSub(context),
        ),
        const SizedBox(height: _kLabelGap + 2),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: AppSpacing.x3,
            crossAxisSpacing: AppSpacing.x3,
            mainAxisExtent: 76,
          ),
          itemCount: _skillOptions.length,
          itemBuilder: (context, i) {
            final opt = _skillOptions[i];
            final meta = _skillMeta[opt];
            return _ChoiceCard(
              icon: meta?.icon ?? Icons.signal_cellular_alt_outlined,
              title: opt,
              subtitle: meta?.subtitle ?? '',
              selected: data.skillLevel == opt,
              onTap: () => _form.setSkillLevel(opt),
            );
          },
        ),
        const SizedBox(height: AppSpacing.x5),

        // Entry — two selectable choice cards.
        _FieldLabel('Entry Fee'),
        const SizedBox(height: 2),
        Text(
          'Is there a cost to join?',
          style: AppTypography.metaSub(context),
        ),
        const SizedBox(height: _kLabelGap + 2),
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
        // Paid block: segmented mode + price card. Wrapped in
        // AnimatedSize so Free↔Paid toggles and Fixed↔Split switches
        // grow/collapse smoothly instead of pushing "Who Can Join"
        // down in one jump.
        ClipRect(
          child: AnimatedSize(
            duration: AppDurations.base,
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: data.feeType == 1
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: AppSpacing.x3),
                      // Pricing mode: Fixed = flat per person,
                      // Split = shared total.
                      AppSegmentedControl(
                        labels: const [
                          'Fixed · per person',
                          'Split · total',
                        ],
                        selectedIndex: data.priceMode,
                        onChanged: (i) => _form.setPriceMode(i),
                      ),
                      const SizedBox(height: AppSpacing.x3),
                      // Amount, min stepper and live estimate in one card.
                      _PriceCard(
                        priceController: _priceController,
                        onPriceChanged: _form.setPrice,
                        isSplit: data.priceMode == 1,
                        min: data.minPlayers ?? data.maxParticipants,
                        max: data.maxParticipants,
                        onMinChanged: (v) => _form.setMinPlayers(
                          v >= data.maxParticipants ? null : v,
                        ),
                        total: double.tryParse(
                          _priceController.text.trim(),
                        ),
                      ),
                    ],
                  )
                : const SizedBox(width: double.infinity),
          ),
        ),
        const SizedBox(height: AppSpacing.x4),

        // Join Policy — same choice-card language as Entry above.
        _FieldLabel('Who Can Join'),
        const SizedBox(height: 2),
        Text(
          'Control how people join your game',
          style: AppTypography.metaSub(context),
        ),
        const SizedBox(height: _kLabelGap + 2),
        Row(
          children: [
            Expanded(
              child: _ChoiceCard(
                icon: _joinPolicyMeta['open']!.icon,
                title: _joinPolicyMeta['open']!.title,
                subtitle: _joinPolicyMeta['open']!.subtitle,
                selected: data.joinPolicy == 'open',
                onTap: () => _form.setJoinPolicy('open'),
              ),
            ),
            const SizedBox(width: AppSpacing.x3),
            Expanded(
              child: _ChoiceCard(
                icon: _joinPolicyMeta['approval']!.icon,
                title: _joinPolicyMeta['approval']!.title,
                subtitle: _joinPolicyMeta['approval']!.subtitle,
                selected: data.joinPolicy == 'approval',
                onTap: () => _form.setJoinPolicy('approval'),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.x5),

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
    final paid = data.feeType == 1;
    final split = paid && data.priceMode == 1;
    final amount = double.tryParse(_priceController.text.trim());
    final min = split
        ? (data.minPlayers ?? data.maxParticipants)
            .clamp(2, data.maxParticipants)
        : null;
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
      isPaid: paid,
      fee: paid
          ? (split && min != null && amount != null && amount > 0
              ? (amount / min * 100).round() / 100
              : amount)
          : null,
      feeMode: split ? 'split' : 'fixed',
      totalCost: split ? amount : null,
      minPlayers: split && min != null && min < data.maxParticipants
          ? min
          : null,
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
        // Card height follows the screen (62%) within sane bounds so
        // the preview fills small phones without overflowing tablets.
        SizedBox(
          height: (MediaQuery.of(context).size.height * 0.62)
              .clamp(420.0, 640.0)
              .toDouble(),
          child: DiscoveryCard(activity: preview),
        ),
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
      0 => 1 / 3,
      1 => 2 / 3,
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
    this.error,
  });

  final IconData icon;
  final String label;
  final Widget? value;
  final Widget? trailing;
  final VoidCallback? onTap;

  /// Inline validation message. Renders a red border + message row so a
  /// blocked Continue is visible on the field itself, not just a
  /// transient snackbar.
  final String? error;

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
        border: Border.all(
          color: error != null ? context.colors.errorText : context.colors.border,
          width: error != null ? 1.5 : 1,
        ),
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
          if (error != null) ...[
            const SizedBox(height: AppSpacing.x2),
            Text(
              error!,
              style: AppTypography.metaSub(context).copyWith(
                color: context.colors.errorText,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
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

/// Whole price block in one clean card: amount field on top, min
/// stepper below the divider (split mode only), and a tinted live
/// estimate footer. Replaces the old three-stacked-boxes layout.
/// Price block: big payment-style amount + min stepper + live estimate.
///
/// The amount reads like a payment app (32 px ExtraBold, primary `$`)
/// instead of a plain small text row; the mode suffix is an uppercase
/// pill chip in the same language as the join-policy pills, and the
/// card border lights up primary while the field is focused — same
/// interaction as the date-of-birth field on get-to-know-3.
class _PriceCard extends StatefulWidget {
  const _PriceCard({
    required this.priceController,
    required this.onPriceChanged,
    required this.isSplit,
    required this.min,
    required this.max,
    required this.onMinChanged,
    required this.total,
  });

  final TextEditingController priceController;
  final ValueChanged<String> onPriceChanged;
  final bool isSplit;
  final int min;
  final int max;
  final ValueChanged<int> onMinChanged;
  final double? total;

  @override
  State<_PriceCard> createState() => _PriceCardState();
}

class _PriceCardState extends State<_PriceCard> {
  final _focus = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (mounted) setState(() => _focused = _focus.hasFocus);
    });
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final amountStyle = AppTypography.headlineLarge(context);
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppRadius.input),
        border: Border.all(
          color: _focused ? AppColors.primary : c.border,
          width: _focused ? 1.5 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Amount row.
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.x4,
              AppSpacing.x4,
              AppSpacing.x4,
              AppSpacing.x4,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  '\$',
                  style: amountStyle.copyWith(color: c.primaryOnSurface),
                ),
                const SizedBox(width: AppSpacing.x1),
                Expanded(
                  child: TextField(
                    controller: widget.priceController,
                    focusNode: _focus,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    textInputAction: TextInputAction.done,
                    cursorColor: AppColors.primary,
                    style: amountStyle,
                    decoration: InputDecoration(
                      hintText: '0.00',
                      hintStyle: amountStyle.copyWith(
                        color: c.textTertiary,
                      ),
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    onChanged: widget.onPriceChanged,
                  ),
                ),
                const SizedBox(width: AppSpacing.x2),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: c.primarySoft,
                    borderRadius: AppRadius.pillR,
                  ),
                  child: AnimatedSwitcher(
                    duration: AppDurations.fast,
                    child: Text(
                      widget.isSplit ? 'TOTAL' : 'PER PERSON',
                      // Keyed so mode switches cross-fade the pill text
                      // instead of swapping it in one frame.
                      key: ValueKey(widget.isSplit),
                      style: AppTypography.badgeSport(context).copyWith(
                        color: c.primaryOnSurface,
                        fontSize: 10,
                        letterSpacing: 0.8,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (widget.isSplit) ...[
            Divider(height: 1, color: c.border),
            // Min stepper row — value inline between the buttons.
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.x4,
                vertical: AppSpacing.x3,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Minimum to run',
                          style: _inputStyle(context).copyWith(fontSize: 14),
                        ),
                        Text(
                          widget.min >= widget.max
                              ? 'Full house · ${widget.max} players'
                              : '${widget.min} of ${widget.max} players',
                          style: AppTypography.metaSub(context),
                        ),
                      ],
                    ),
                  ),
                  _CounterBtn(
                    icon: Icons.remove_rounded,
                    enabled: widget.min > 2,
                    emphasised: false,
                    semanticLabel: 'Decrease minimum players',
                    onTap: () => widget.onMinChanged(widget.min - 1),
                  ),
                  SizedBox(
                    width: 36,
                    child: Text(
                      '${widget.min}',
                      textAlign: TextAlign.center,
                      style: _inputStyle(
                        context,
                      ).copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  _CounterBtn(
                    icon: Icons.add_rounded,
                    enabled: widget.min < widget.max,
                    emphasised: true,
                    semanticLabel: 'Increase minimum players',
                    onTap: () => widget.onMinChanged(widget.min + 1),
                  ),
                ],
              ),
            ),
            // Live worst-case estimate footer.
            _SplitEstimateFooter(
              total: widget.total,
              min: widget.min,
              capacity: widget.max,
            ),
          ],
        ],
      ),
    );
  }
}

/// Tinted live-estimate footer inside [_PriceCard]: total ÷ min.
/// Hidden until a valid total is typed. Division is guarded —
/// a zero min would render Infinity instead of a price.
class _SplitEstimateFooter extends StatelessWidget {
  const _SplitEstimateFooter({
    required this.total,
    required this.min,
    required this.capacity,
  });

  final double? total;
  final int min;
  final int capacity;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (total == null || total! <= 0 || min < 1 || capacity < 1) {
      return const SizedBox.shrink();
    }
    final worst = total! / min;
    final full = total! / capacity;
    // Full house splits exact — no "≈". Otherwise the worst case is
    // approximate (only gets cheaper as more join).
    final text = min >= capacity
        ? '\$${full.toStringAsFixed(2)} each — split evenly'
        : '≈\$${worst.toStringAsFixed(2)} each worst case · \$${full.toStringAsFixed(2)} when full';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.x4,
        vertical: AppSpacing.x2 + 2,
      ),
      decoration: BoxDecoration(
        color: c.statusSuccessBg,
        // Inset bottom radius: the footer sits flush against the card's
        // bottom edge, so square corners would paint over the card's
        // own bottom border (the "cut line" bug).
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(AppRadius.input - 1),
          bottomRight: Radius.circular(AppRadius.input - 1),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.check_circle_outline_rounded,
            size: 14,
            color: c.successText,
          ),
          const SizedBox(width: AppSpacing.x2),
          Expanded(
            child: Text(
              text,
              style: AppTypography.metaSub(context).copyWith(
                color: c.successText,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
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
