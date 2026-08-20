import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/profile_providers.dart';
import '../../../core/providers/repository_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/skeleton.dart';

// ─── Screen ──────────────────────────────────────────────────────────────────

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _bioController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _locationController = TextEditingController();
  final _dobController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  final _goalController = TextEditingController();

  bool _loading = false;
  bool _initialised = false;

  final List<_SportEntry> _sports = [];

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _bioController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _locationController.dispose();
    _dobController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _goalController.dispose();
    super.dispose();
  }

  void _initFields(String name, String? bio) {
    if (_initialised) return;
    _nameController.text = name;
    _usernameController.text = name.toLowerCase().replaceAll(' ', '');
    _bioController.text = bio ?? 'Sports enthusiast. Always up for a game!';
    _emailController.text = 'alex@email.com';
    _phoneController.text = '+1 234 567 890';
    _locationController.text = 'New York, NY';
    _dobController.text = '29 March 1996';
    _heightController.text = '183 cm';
    _weightController.text = '73 kg';
    _goalController.text = 'Stay active with new sports';
    _sports.addAll([
      _SportEntry(name: 'Basketball', level: 1),
      _SportEntry(name: 'Tennis', level: 0),
      _SportEntry(name: 'Running', level: 2),
    ]);
    _initialised = true;
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
          );
      ref.invalidate(myProfileProvider);
      if (!mounted) return;
      AppSnackbar.show(
        context,
        message: 'Profile saved!',
        variant: AppSnackbarVariant.success,
      );
      context.pop();
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.show(
        context,
        message: 'Could not save. Please try again.',
        variant: AppSnackbarVariant.error,
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(myProfileProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        bottom: false,
        child: profileAsync.when(
          loading: () => const SkeletonList(count: 6),
          error: (_, _) =>
              const Center(child: Text('Could not load profile.')),
          data: (user) {
            _initFields(user.displayName, user.bio);
            return Column(
              children: [
                // Header
                _Header(loading: _loading, onSave: _save),

                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.x6,
                      AppSpacing.x4,
                      AppSpacing.x6,
                      AppSpacing.x8,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(child: _AvatarBlock(user: user)),
                        const SizedBox(height: AppSpacing.x6),

                        // Personal info
                        _BoxedField(
                          label: 'FULL NAME',
                          controller: _nameController,
                        ),
                        _BoxedField(
                          label: 'USERNAME',
                          controller: _usernameController,
                          leadingIcon: Icons.alternate_email,
                        ),
                        _BoxedField(
                          label: 'BIO',
                          controller: _bioController,
                          maxLines: 3,
                        ),
                        _BoxedField(
                          label: 'EMAIL',
                          controller: _emailController,
                          leadingIcon: Icons.mail_outline_rounded,
                          keyboardType: TextInputType.emailAddress,
                        ),
                        _BoxedField(
                          label: 'PHONE',
                          controller: _phoneController,
                          leadingIcon: Icons.phone_outlined,
                          keyboardType: TextInputType.phone,
                        ),
                        _BoxedField(
                          label: 'LOCATION',
                          controller: _locationController,
                          leadingIcon: Icons.location_on_outlined,
                        ),
                        _BoxedField(
                          label: 'DATE OF BIRTH',
                          controller: _dobController,
                          leadingIcon: Icons.calendar_today_outlined,
                        ),
                        _BoxedField(
                          label: 'HEIGHT',
                          controller: _heightController,
                          leadingIcon: Icons.straighten_outlined,
                        ),
                        _BoxedField(
                          label: 'WEIGHT',
                          controller: _weightController,
                        ),
                        _BoxedField(
                          label: 'PRIMARY GOAL',
                          controller: _goalController,
                          trailingIcon: Icons.mail_outline_rounded,
                        ),
                        const SizedBox(height: AppSpacing.x4),

                        // Sports
                        Text(
                          'MY SPORTS',
                          style: _sectionLabel,
                        ),
                        const SizedBox(height: AppSpacing.x3),
                        ...List.generate(_sports.length, (i) {
                          final sport = _sports[i];
                          return Padding(
                            padding:
                                const EdgeInsets.only(bottom: AppSpacing.x3),
                            child: _SportCard(
                              entry: sport,
                              onLevelChanged: (level) => setState(
                                () => _sports[i] = _SportEntry(
                                  name: sport.name,
                                  level: level,
                                ),
                              ),
                              onRemove: () => setState(
                                () => _sports.removeAt(i),
                              ),
                            ),
                          );
                        }),
                        const SizedBox(height: AppSpacing.x2),
                        Center(
                          child: GestureDetector(
                            onTap: () {},
                            behavior: HitTestBehavior.opaque,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.x4,
                                vertical: AppSpacing.x3,
                              ),
                              decoration: BoxDecoration(
                                borderRadius:
                                    BorderRadius.circular(AppRadius.pill),
                                border: Border.all(color: AppColors.primary),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.add_rounded,
                                    size: 16,
                                    color: AppColors.primary,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Add Sport',
                                    style: AppTypography.chipLabel.copyWith(
                                      color: AppColors.primary,
                                    ),
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
              ],
            );
          },
        ),
      ),
    );
  }

  TextStyle get _sectionLabel => AppTypography.metaSub.copyWith(
        fontWeight: FontWeight.w700,
        color: AppColors.textSecondary,
        letterSpacing: 0.5,
      );
}

// ─── Header ──────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({required this.loading, required this.onSave});
  final bool loading;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.x4,
        AppSpacing.x2,
        AppSpacing.x4,
        0,
      ),
      child: Row(
        children: [
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
                    size: 22,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: Text(
                'Edit Profile',
                style: AppTypography.labelField.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          GestureDetector(
            onTap: loading ? null : onSave,
            behavior: HitTestBehavior.opaque,
            child: SizedBox(
              width: 44,
              height: 44,
              child: Center(
                child: loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation(AppColors.primary),
                        ),
                      )
                    : Text(
                        'Save',
                        style: AppTypography.labelField
                            .copyWith(color: AppColors.primary),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Avatar block ─────────────────────────────────────────────────────────────

class _AvatarBlock extends StatelessWidget {
  const _AvatarBlock({required this.user});
  final dynamic user;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primaryLight,
              ),
              clipBehavior: Clip.antiAlias,
              child: user.avatarAsset != null
                  ? Image.asset(user.avatarAsset!, fit: BoxFit.cover)
                  : const Icon(
                      Icons.person,
                      size: 48,
                      color: AppColors.primary,
                    ),
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.surface, width: 2),
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
          'Change Photo',
          style: AppTypography.chipLabel.copyWith(color: AppColors.primary),
        ),
      ],
    );
  }
}

// ─── Boxed field ──────────────────────────────────────────────────────────────

class _BoxedField extends StatelessWidget {
  const _BoxedField({
    required this.label,
    required this.controller,
    this.leadingIcon,
    this.trailingIcon,
    this.maxLines = 1,
    this.keyboardType,
  });

  final String label;
  final TextEditingController controller;
  final IconData? leadingIcon;
  final IconData? trailingIcon;
  final int maxLines;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.x4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTypography.metaSub.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: AppSpacing.x2),
          TextField(
            controller: controller,
            maxLines: maxLines,
            keyboardType: keyboardType,
            cursorColor: AppColors.textPrimary,
            cursorWidth: 1.5,
            style: AppTypography.bodyReading
                .copyWith(color: AppColors.textPrimary),
            decoration: InputDecoration(
              prefixIcon: leadingIcon != null
                  ? Padding(
                      padding: const EdgeInsets.only(left: 14, right: 8),
                      child: Icon(
                        leadingIcon,
                        size: 18,
                        color: AppColors.textSecondary,
                      ),
                    )
                  : null,
              prefixIconConstraints: const BoxConstraints(
                minWidth: 0,
                minHeight: 0,
              ),
              suffixIcon: trailingIcon != null
                  ? Padding(
                      padding: const EdgeInsets.only(right: 14, left: 8),
                      child: Icon(
                        trailingIcon,
                        size: 18,
                        color: AppColors.textSecondary,
                      ),
                    )
                  : null,
              suffixIconConstraints: const BoxConstraints(
                minWidth: 0,
                minHeight: 0,
              ),
              isDense: true,
              filled: true,
              fillColor: AppColors.surface,
              contentPadding: EdgeInsets.symmetric(
                horizontal: leadingIcon != null ? 4 : 14,
                vertical: 14,
              ),
              // Rectangular rounded box (not pill) — override the global
              // pill input theme so this screen looks like a form, not a
              // chat search bar.
              border: _border(AppColors.border),
              enabledBorder: _border(AppColors.border),
              focusedBorder: _border(AppColors.primary, width: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  OutlineInputBorder _border(Color color, {double width = 1}) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.input),
        borderSide: BorderSide(color: color, width: width),
      );
}

// ─── Sport card ───────────────────────────────────────────────────────────────

class _SportEntry {
  const _SportEntry({required this.name, required this.level});
  final String name;
  /// 0=Beginner, 1=Intermediate, 2=Advanced
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

  IconData get _leadingIcon => switch (entry.name.toLowerCase()) {
        // Running gets an activity icon instead of the remove-X to hint it's
        // a cardio activity — matches the design comp.
        'running' => Icons.monitor_heart_outlined,
        _ => Icons.cancel_outlined,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.x4),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: entry.name.toLowerCase() == 'running' ? null : onRemove,
                behavior: HitTestBehavior.opaque,
                child: Icon(
                  _leadingIcon,
                  size: 20,
                  color: AppColors.primaryDarker,
                ),
              ),
              const SizedBox(width: AppSpacing.x2),
              Text(
                entry.name,
                style: AppTypography.labelField
                    .copyWith(color: AppColors.primaryDarker),
              ),
              const Spacer(),
              Container(
                width: 20,
                height: 20,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.x3),
          Row(
            children: List.generate(_levels.length, (i) {
              final selected = i == entry.level;
              return Expanded(
                child: GestureDetector(
                  onTap: () => onLevelChanged(i),
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.textPrimary
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      _levels[i],
                      style: AppTypography.chipLabel.copyWith(
                        color: selected
                            ? AppColors.textOnPrimary
                            : AppColors.textSecondary,
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}
