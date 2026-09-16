import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/profile_providers.dart';
import '../../../core/providers/repository_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_dialog.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/dark_colors.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/app_tappable.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/asset_image.dart';
import '../../../core/widgets/pressable_scale.dart';
import '../../../core/widgets/skeleton.dart';
import '../domain/user_model.dart';
import '../data/user_repository.dart';

// ─── Screen ──────────────────────────────────────────────────────────────────

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _nameController = TextEditingController();
  final _bioController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _locationController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  final _goalController = TextEditingController();
  final _dobController = TextEditingController();

  DateTime? _dob;
  bool _loading = false;
  bool _uploadingPhoto = false;
  bool _initialised = false;
  bool _dirty = false;

  /// Id of the user the fields were last initialised from. The screen
  /// stays mounted across `myProfileProvider` invalidations, so a plain
  /// `_initialised` flag would never refresh — re-init when a DIFFERENT
  /// user arrives (e.g. account switch), keep edits otherwise.
  String? _loadedUserId;

  final List<_SportEntry> _sports = [];

  @override
  void initState() {
    super.initState();
    for (final c in [
      _nameController,
      _bioController,
      _emailController,
      _phoneController,
      _locationController,
      _heightController,
      _weightController,
      _goalController,
    ]) {
      c.addListener(_markDirty);
    }
  }

  void _markDirty() {
    if (!_dirty) setState(() => _dirty = true);
  }

  void _syncDobText() {
    _dobController.text = _dob != null
        ? DateFormat('d MMMM y').format(_dob!)
        : '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _locationController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _goalController.dispose();
    _dobController.dispose();
    super.dispose();
  }

  void _initFields(UserModel user) {
    if (_initialised && _loadedUserId == user.id) return;
    _loadedUserId = user.id;
    _nameController.text = user.displayName;
    _bioController.text = user.bio ?? '';
    _emailController.text = user.email ?? '';
    _phoneController.text = user.phone ?? '';
    _locationController.text = user.location ?? '';
    _dob = user.dateOfBirth;
    _syncDobText();
    _heightController.text = user.heightCm?.toString() ?? '';
    _weightController.text = user.weightKg?.toString() ?? '';
    _goalController.text = user.goal ?? '';
    _sports.clear();
    _sports.addAll(
      user.sports.map(
        (s) => _SportEntry(name: s.sport, level: _levelIndex(s.level)),
      ),
    );
    _initialised = true;
    _dirty = false;
  }

  static int _levelIndex(String level) => switch (level) {
    'Beginner' => 0,
    'Advanced' => 2,
    _ => 1,
  };

  Future<void> _pickDob() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(1996, 1, 1),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppColors.primary,
            onPrimary: AppColors.textOnPrimary,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _dob = picked;
        _syncDobText();
        _dirty = true;
      });
    }
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      AppSnackbar.show(
        context,
        message: 'Name cannot be empty.',
        variant: AppSnackbarVariant.error,
      );
      return;
    }
    setState(() => _loading = true);
    try {
      await ref.read(userRepositoryProvider).updateProfile(
        displayName: name,
        bio: _bioController.text.trim(),
        location: _locationController.text.trim(),
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim(),
        dateOfBirth: _dob,
        heightCm: int.tryParse(_heightController.text.trim()),
        weightKg: int.tryParse(_weightController.text.trim()),
        goal: _goalController.text.trim(),
        sports: _sports
            .map((s) => (
                  sport: s.name,
                  level: const [
                    'Beginner',
                    'Intermediate',
                    'Advanced',
                  ][s.level],
                ))
            .toList(),
      );
      ref.invalidate(myProfileProvider);
      if (!mounted) return;
      _dirty = false;
      AppSnackbar.show(
        context,
        message: 'Profile saved',
        variant: AppSnackbarVariant.success,
      );
      context.pop();
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.show(
        context,
        message: e is ProfileUpdateException
            ? e.message
            : "Couldn't save your changes. Please try again.",
        variant: AppSnackbarVariant.error,
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Picks a gallery photo, uploads it, and persists the URL as the
  /// profile photo. Independent from the text-field save flow — the
  /// photo applies immediately so the preview below is always real.
  Future<void> _changePhoto() async {
    if (_uploadingPhoto) return;
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      imageQuality: 85,
    );
    if (picked == null || !mounted) return;
    setState(() => _uploadingPhoto = true);
    try {
      await ref
          .read(userRepositoryProvider)
          .uploadAvatar(localPath: picked.path);
      ref.invalidate(myProfileProvider);
      if (!mounted) return;
      AppSnackbar.show(
        context,
        message: 'Profile photo updated.',
        variant: AppSnackbarVariant.success,
      );
    } catch (_) {
      if (!mounted) return;
      AppSnackbar.show(
        context,
        message: 'Could not update photo. Please try again.',
        variant: AppSnackbarVariant.error,
      );
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  Future<bool> _confirmDiscard() async {
    if (!_dirty) return true;
    final discard = await AppDialog.confirm(
      context,
      title: 'Discard changes?',
      body: 'Your edits have not been saved.',
      confirmLabel: 'Discard',
      cancelLabel: 'Keep editing',
      destructive: true,
    );
    return discard ?? false;
  }

  Future<void> _onBack() async {
    final discard = await _confirmDiscard();
    if (!discard || !mounted) return;
    if (!context.mounted) return;
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(myProfileProvider);

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final discard = await _confirmDiscard();
        if (!discard || !mounted || !context.mounted) return;
        context.pop();
      },
      child: AppScaffold(
        safeAreaTop: true,
        showHomeIndicator: false,
        backgroundColor: context.colors.background,
        body: Column(
          children: [
            // ── Header ────────────────────────────────────────────────
            Container(
              color: context.colors.surface,
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.x4,
                AppSpacing.x3,
                AppSpacing.x5,
                AppSpacing.x3,
              ),
              child: Row(
                children: [
                  Semantics(
                    button: true,
                    label: 'Back',
                    child: PressableScale(
                      onTap: _onBack,
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: context.colors.surface,
                          borderRadius:
                              BorderRadius.circular(AppRadius.sm),
                          border: Border.all(color: context.colors.border),
                          boxShadow: AppShadows.card,
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.arrow_back_ios_new_rounded,
                          size: 16,
                          color: context.colors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.x3),
                  Expanded(
                    child: Text(
                      'Edit Profile',
                      style: AppTypography.titleSheet(context),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  // Mirror spacer
                  const SizedBox(width: 38),
                ],
              ),
            ),

            // ── Body ──────────────────────────────────────────────────
            Expanded(
              child: profileAsync.when(
                loading: () => const SkeletonList(count: 6),
                error: (_, _) => const Center(
                  child: Text('Could not load profile.'),
                ),
                data: (user) {
                  _initFields(user);
                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.x5,
                      AppSpacing.x5,
                      AppSpacing.x5,
                      AppSpacing.x8,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Avatar
                        Center(
                          child: _AvatarBlock(
                            user: user,
                            isUploading: _uploadingPhoto,
                            onTap: _changePhoto,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.x5),

                        // Personal info card
                        _SectionCard(
                          title: 'Personal Info',
                          child: Column(
                            children: [
                              AppTextField.form(
                                label: 'FULL NAME',
                                controller: _nameController,
                              ),
                              const SizedBox(height: AppSpacing.x4),
                              AppTextField.form(
                                label: 'BIO',
                                controller: _bioController,
                                maxLines: 3,
                              ),
                              const SizedBox(height: AppSpacing.x4),
                              AppTextField.form(
                                label: 'LOCATION',
                                controller: _locationController,
                              ),
                              const SizedBox(height: AppSpacing.x4),
                              PressableScale(
                                onTap: _pickDob,
                                child: AbsorbPointer(
                                  child: AppTextField.form(
                                    label: 'DATE OF BIRTH',
                                    controller: _dobController,
                                    hint: 'Select date',
                                    trailing: Icon(
                                      Icons.calendar_month_outlined,
                                      size: 18,
                                      color: context.colors.textTertiary,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.x4),

                        // Contact card — PATCH /me persists none of these
                        // yet (see RemoteUserRepository.updateProfile), so
                        // the inputs are disabled with an honest caption
                        // instead of faking a save.
                        _SectionCard(
                          title: 'Contact',
                          child: Column(
                            children: [
                              AppTextField.form(
                                label: 'EMAIL',
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                enabled: false,
                              ),
                              const SizedBox(height: AppSpacing.x4),
                              AppTextField.form(
                                label: 'PHONE',
                                controller: _phoneController,
                                keyboardType: TextInputType.phone,
                                enabled: false,
                              ),
                              const SizedBox(height: AppSpacing.x3),
                              const _NotSyncedCaption(),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.x4),

                        // Physical card — height/weight/goal are not part of
                        // PATCH /me either; same disabled-with-caption
                        // treatment as Contact.
                        _SectionCard(
                          title: 'Physical',
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: AppTextField.form(
                                      label: 'HEIGHT (CM)',
                                      controller: _heightController,
                                      keyboardType: TextInputType.number,
                                      enabled: false,
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.x3),
                                  Expanded(
                                    child: AppTextField.form(
                                      label: 'WEIGHT (KG)',
                                      controller: _weightController,
                                      keyboardType: TextInputType.number,
                                      enabled: false,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppSpacing.x4),
                              AppTextField.form(
                                label: 'PRIMARY GOAL',
                                controller: _goalController,
                                enabled: false,
                              ),
                              const SizedBox(height: AppSpacing.x3),
                              const _NotSyncedCaption(),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.x4),

                        // My sports card
                        _SectionCard(
                          title: 'My Sports',
                          trailing: AppTappable(
                            semanticLabel: 'Add sport',
                            feedback: AppTapFeedback.scale,
                            onTap: () => _showAddSportSheet(context),
                            minSize: 0,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.x3,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: context.colors.primarySoft,
                                borderRadius:
                                    BorderRadius.circular(AppRadius.pill),
                                border: Border.all(
                                  color: context.colors.primaryOnSurface
                                      .withValues(alpha: 0.4),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.add_rounded,
                                    size: 14,
                                    color: context.colors.primaryOnSurface,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Add sport',
                                    style:
                                        AppTypography.chipLabel(context)
                                            .copyWith(
                                      color: context.colors.primaryOnSurface,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          child: _sports.isEmpty
                              ? Text(
                                  'No sports added yet. Tap Add sport to get started.',
                                  style: AppTypography.metaSub(context),
                                )
                              : Column(
                                  children: List.generate(
                                    _sports.length,
                                    (i) => Padding(
                                      padding: EdgeInsets.only(
                                        bottom: i < _sports.length - 1
                                            ? AppSpacing.x3
                                            : 0,
                                      ),
                                      child: _SportCard(
                                        entry: _sports[i],
                                        onLevelChanged: (level) =>
                                            setState(() {
                                              _sports[i] = _SportEntry(
                                                name: _sports[i].name,
                                                level: level,
                                              );
                                              _dirty = true;
                                            }),
                                        onRemove: () => setState(() {
                                          _sports.removeAt(i);
                                          _dirty = true;
                                        }),
                                      ),
                                    ),
                                  ),
                                ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // ── Pinned save bar ────────────────────────────────────────
            _SaveBar(loading: _loading, onSave: _save),
          ],
        ),
      ),
    );
  }

  static const _addableSports = [
    'Basketball',
    'Tennis',
    'Soccer',
    'Running',
    'Volleyball',
    'Cycling',
    'Swimming',
    'Golf',
  ];

  Future<void> _showAddSportSheet(BuildContext context) async {
    final existing = _sports.map((s) => s.name).toSet();
    final options =
        _addableSports.where((s) => !existing.contains(s)).toList();
    if (options.isEmpty) return;

    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => SafeArea(
        top: false,
        child: Container(
          decoration: BoxDecoration(
            color: context.colors.surface,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppRadius.xl),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.x5,
            AppSpacing.x3,
            AppSpacing.x5,
            AppSpacing.x5,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: AppSpacing.x4),
                  decoration: BoxDecoration(
                    color: context.colors.border,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                ),
              ),
              Text('Add a sport', style: AppTypography.titleSheet(context)),
              const SizedBox(height: AppSpacing.x4),
              ...options.map(
                (s) => PressableScale(
                  onTap: () => Navigator.of(context).pop(s),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.x3,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            s,
                            style: AppTypography.bodyReading(context),
                          ),
                        ),
                        Icon(
                          Icons.add_rounded,
                          size: 18,
                          color: context.colors.textTertiary,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (picked != null) {
      setState(() {
        _sports.add(_SportEntry(name: picked, level: 1));
        _dirty = true;
      });
    }
  }
}

// ─── Section card ─────────────────────────────────────────────────────────────

/// Caption under fields the backend can't persist yet.
class _NotSyncedCaption extends StatelessWidget {
  const _NotSyncedCaption();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        'Not synced to your profile yet',
        style: AppTypography.metaSub(context),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.child,
    this.trailing,
  });
  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.x4),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: context.colors.border),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: AppTypography.titleMedium(context),
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: AppSpacing.x4),
          child,
        ],
      ),
    );
  }
}

// ─── Avatar block ─────────────────────────────────────────────────────────────

class _AvatarBlock extends StatelessWidget {
  const _AvatarBlock({
    required this.user,
    required this.isUploading,
    required this.onTap,
  });
  final UserModel user;
  final bool isUploading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final photo = user.avatarUrl ?? user.avatarAsset;

    return PressableScale(
      onTap: isUploading ? null : onTap,
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              // Avatar with blue ring (matches profile screen).
              // Backend photo URL first, bundled asset for legacy
              // payloads, person placeholder when neither exists.
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: context.colors.primaryOnSurface,
                    width: 3,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: ClipOval(
                    child: photo != null
                        ? AssetImageWithFallback(
                            imagePath: photo,
                            fit: BoxFit.cover,
                            isAvatar: true,
                          )
                        : Container(
                            color: context.colors.primarySoft,
                            child: Icon(
                              Icons.person,
                              size: 48,
                              color: context.colors.primaryOnSurface,
                            ),
                          ),
                  ),
                ),
              ),
              // Upload progress covers the avatar while uploading.
              if (isUploading)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: context.colors.surface.withValues(alpha: 0.6),
                    ),
                    alignment: Alignment.center,
                    child: const SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(strokeWidth: 3),
                    ),
                  ),
                ),
              // Camera badge
              Positioned(
                right: 2,
                bottom: 2,
                child: Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.textOnPrimary,
                      width: 2,
                    ),
                  ),
                  child: const Icon(
                    Icons.camera_alt_rounded,
                    size: 14,
                    color: AppColors.textOnPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.x2),
          Text(
            isUploading ? 'Uploading…' : 'Change Photo',
            style: AppTypography.chipLabel(context).copyWith(
              color: context.colors.primaryOnSurface,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Sport entry + card ───────────────────────────────────────────────────────

class _SportEntry {
  const _SportEntry({required this.name, required this.level});
  final String name;

  /// 0 = Beginner, 1 = Intermediate, 2 = Advanced
  final int level;
}

class _SportCard extends StatelessWidget {
  const _SportCard({
    required this.entry,
    required this.onLevelChanged,
    required this.onRemove,
  });
  final _SportEntry entry;
  final ValueChanged<int> onLevelChanged;
  final VoidCallback onRemove;

  static const _levels = ['Beginner', 'Intermediate', 'Advanced'];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.x3),
      decoration: BoxDecoration(
        color: context.colors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  entry.name,
                  style: AppTypography.labelField(context),
                ),
              ),
              AppTappable(
                semanticLabel: 'Remove ${entry.name}',
                feedback: AppTapFeedback.scale,
                minSize: 32,
                onTap: onRemove,
                child: Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: context.colors.textTertiary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.x2),
          // Level segmented toggle
          Container(
            height: 34,
            decoration: BoxDecoration(
              color: context.colors.surface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: context.colors.border),
            ),
            child: Row(
              children: List.generate(_levels.length, (i) {
                final selected = i == entry.level;
                return Expanded(
                  child: PressableScale(
                    onTap: () => onLevelChanged(i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      margin: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: selected
                            ? AppColors.primary
                            : Colors.transparent,
                        borderRadius:
                            BorderRadius.circular(AppRadius.sm),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        _levels[i],
                        style: AppTypography.metaSub(context).copyWith(
                          fontSize: 11,
                          color: selected
                              ? AppColors.textOnPrimary
                              : context.colors.textSecondary,
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w400,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Save bar ─────────────────────────────────────────────────────────────────

class _SaveBar extends StatelessWidget {
  const _SaveBar({required this.loading, required this.onSave});
  final bool loading;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.x5,
        AppSpacing.x3,
        AppSpacing.x5,
        AppSpacing.x5 + MediaQuery.of(context).viewPadding.bottom,
      ),
      decoration: BoxDecoration(
        color: context.colors.surface,
        boxShadow: AppShadows.bottomBar,
      ),
      child: PressableScale(
        onTap: loading ? null : onSave,
        child: Container(
          width: double.infinity,
          height: 54,
          decoration: BoxDecoration(
            color: loading
                ? AppColors.primary.withValues(alpha: 0.6)
                : AppColors.primary,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            boxShadow: loading ? null : AppShadows.glowPrimary,
          ),
          alignment: Alignment.center,
          child: loading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation(AppColors.textOnPrimary),
                  ),
                )
              : Text(
                  'Save Changes',
                  style: AppTypography.buttonPrimary,
                ),
        ),
      ),
    );
  }
}
