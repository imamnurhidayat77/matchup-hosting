import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/providers/repository_providers.dart';
import '../../../../core/services/location_service.dart';
import '../../data/places_ranker.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/dark_colors.dart';
import '../../domain/place_suggestion.dart';

class VenuePickerSheet extends ConsumerStatefulWidget {
  const VenuePickerSheet({super.key, required this.countryCodes});

  final String? countryCodes;

  static Future<PlaceSuggestion?> show(
    BuildContext context, {
    String? countryCodes,
  }) {
    return showModalBottomSheet<PlaceSuggestion>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SheetWrapper(countryCodes: countryCodes),
    );
  }

  @override
  ConsumerState<VenuePickerSheet> createState() => _VenuePickerSheetState();
}

class _SheetWrapper extends StatelessWidget {
  const _SheetWrapper({required this.countryCodes});
  final String? countryCodes;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: FractionallySizedBox(
        heightFactor: 0.92,
        child: VenuePickerSheet(countryCodes: countryCodes),
      ),
    );
  }
}

class _VenuePickerSheetState extends ConsumerState<VenuePickerSheet>
    with SingleTickerProviderStateMixin {
  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();
  Timer? _debounce;

  List<PlaceSuggestion> _results = const [];
  // ignore: prefer_final_fields
  List<RankedPlace> _ranked = const [];
  bool _searching = false;
  String? _error;
  PlaceSuggestion? _selected;

  // Cached recent searches (persisted to SharedPreferences).
  List<PlaceSuggestion> _recent = const [];

  // Currently picked map location (from a tap on the map, not from
  // the suggestions list). Shows the floating "Use this location"
  // card.
  LatLng? _pickedLatLng;

  // Resolved device GPS, used as the origin for distance ranking
  // and as the initial map center.
  LatLng? _userLocation;

  static const _kRecentKey = 'venue_picker.recent_searches';
  static const _kRecentMax = 5;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      _searchFocus.requestFocus();
      await _loadRecent();
      // Resolve GPS in the background so the first search uses the
      // user's actual location as the distance origin instead of
      // the bundled Auckland fallback. Failures are silent — we
      // just keep using the fallback.
      try {
        final pos = await LocationService.instance.getCurrentLocation();
        if (!mounted || pos == null) return;
        setState(() {
          _userLocation = LatLng(pos.latitude, pos.longitude);
        });
      } catch (_) {/* ignored */}
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _loadRecent() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_kRecentKey) ?? const [];
      if (!mounted) return;
      setState(() {
        _recent = raw
            .map((s) {
              try {
                return PlaceSuggestion.fromJson(
                  jsonDecode(s) as Map<String, dynamic>,
                );
              } catch (_) {
                return null;
              }
            })
            .whereType<PlaceSuggestion>()
            .toList();
      });
    } catch (_) {
      // Best-effort only — silently ignore read failures.
    }
  }

  Future<void> _saveRecent(PlaceSuggestion s) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Move-to-front dedupe.
      final deduped = [s, ..._recent.where((r) => r.placeId != s.placeId)];
      _recent = deduped.take(_kRecentMax).toList();
      await prefs.setStringList(
        _kRecentKey,
        _recent
            .map((r) => jsonEncode({
                  'placeId': r.placeId,
                  'label': r.label,
                  'secondary': r.secondary,
                  'latitude': r.latitude,
                  'longitude': r.longitude,
                }))
            .toList(),
      );
    } catch (_) {
      // Best-effort.
    }
  }

  Future<void> _clearRecent() async {
    setState(() => _recent = const []);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kRecentKey);
    } catch (_) {}
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    final trimmed = value.trim();
    setState(() => _pickedLatLng = null);
    if (trimmed.length < 3) {
      setState(() {
        _results = const [];
        _searching = false;
        _error = null;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), _search);
  }

  Future<void> _search() async {
    final query = _searchCtrl.text.trim();
    if (query.length < 3) return;
    if (!mounted) return;
    setState(() {
      _searching = true;
      _error = null;
    });
    try {
      final origin = _pickedLatLng ??
          _selectedLatLng ??
          _userLocation ??
          const LatLng(-36.8485, 174.7633);
      final results = await ref.read(placesRepositoryProvider).autocomplete(
            query,
            countryCodes: widget.countryCodes,
            // Bias the geocoder to the user's area (~±35km) so nearby
            // Auckland venues rank above same-named world matches.
            viewbox: _viewboxAround(origin),
          );
      if (!mounted) return;
      // Discard stale responses (user kept typing past us).
      if (_searchCtrl.text.trim() != query) return;
      // Rank results by combined relevance + distance score. See
      // [PlacesRanker] for the tier-by-tier algorithm.
      // Re-rank once and split: the ranked list feeds the row
      // widget (for matched-range highlighting + precomputed
      // distance); the bare suggestions feed `_results` (so the
      // empty-state + count branches can use it).
      final rankedAll = const PlacesRanker().rank(
        results, query, origin: origin,
      );
      setState(() {
        _ranked = rankedAll;
        _results = rankedAll.map((r) => r.suggestion).toList(growable: false);
        _searching = false;
        _selected = _results.isNotEmpty ? _results.first : null;
      });
    } catch (e) {
      if (!mounted) return;
      if (_searchCtrl.text.trim() != query) return;
      setState(() {
        _searching = false;
        _error = 'Search failed. Check your connection and try again.';
      });
    }
  }

  /// Nominatim viewbox (`"left,top,right,bottom"`) around [origin],
  /// roughly ±35 km, clamped to valid world degrees. Sent as a *bias*
  /// (bounded=0 server-side): nearby venues rank first, world matches
  /// still appear below.
  String _viewboxAround(LatLng origin) {
    final left = (origin.longitude - 0.35).clamp(-180.0, 180.0);
    final right = (origin.longitude + 0.35).clamp(-180.0, 180.0);
    final top = (origin.latitude + 0.25).clamp(-90.0, 90.0);
    final bottom = (origin.latitude - 0.25).clamp(-90.0, 90.0);
    return '$left,$top,$right,$bottom';
  }

  Future<void> _pick(PlaceSuggestion suggestion) async {    await _saveRecent(suggestion);
    if (!mounted) return;
    Navigator.of(context).pop(suggestion);
  }

  LatLng? get _selectedLatLng {
    final s = _selected;
    if (s != null) return LatLng(s.latitude, s.longitude);
    return _pickedLatLng;
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchCtrl.text.trim();
    final showInitialState =
        query.isEmpty && _results.isEmpty && _pickedLatLng == null;
    // Reference point for the distance sort + per-row distance
    // label. Defaults to central Auckland so seeded suggestions
    // rank logically before the user pans the map.
    final origin = _pickedLatLng ??
        _selectedLatLng ??
        _userLocation ??
        const LatLng(-36.8485, 174.7633);

    return Material(
      color: context.colors.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _GrabHandle(),
          _Header(
            title: 'Pick a venue',
            onClose: () => Navigator.of(context).pop(),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.x4,
              0,
              AppSpacing.x4,
              AppSpacing.x3,
            ),
            child: _SearchBar(
              controller: _searchCtrl,
              focusNode: _searchFocus,
              onChanged: _onQueryChanged,
              onSubmitted: (_) {
                _debounce?.cancel();
                _search();
              },
              searching: _searching,
              hasText: _searchCtrl.text.isNotEmpty,
              onClear: () {
                _searchCtrl.clear();
                _onQueryChanged('');
              },
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: _Map(
                    selected: _selectedLatLng,
                    onPickedLocation: (latLng) {
                      setState(() {
                        _pickedLatLng = latLng;
                        _searchCtrl.clear();
                        _results = const [];
                        _searching = false;
                        _error = null;
                      });
                      _searchFocus.unfocus();
                    },
                  ),
                ),
                // Floating "Use this location" card for tap-on-map.
                if (_pickedLatLng != null)
                  Positioned(
                    left: AppSpacing.x4,
                    right: AppSpacing.x4,
                    bottom: AppSpacing.x5,
                    child: _PickedLocationCard(
                      latLng: _pickedLatLng!,
                      onConfirm: (name) {
                        final ll = _pickedLatLng!;
                        final trimmed = name.trim();
                        Navigator.of(context).pop(
                          PlaceSuggestion(
                            placeId:
                                'pin:${ll.latitude.toStringAsFixed(5)},${ll.longitude.toStringAsFixed(5)}',
                            label: trimmed.isNotEmpty
                                ? trimmed
                                : '${ll.latitude.toStringAsFixed(5)}, ${ll.longitude.toStringAsFixed(5)}',
                            secondary: 'Dropped pin',
                            latitude: ll.latitude,
                            longitude: ll.longitude,
                          ),
                        );
                      },
                    ),
                  )
                // Results / recent / empty / error states.
                else if (query.isEmpty && _recent.isNotEmpty)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: _BottomSheet(
                      title: 'Recent',
                      trailing: TextButton(
                        onPressed: _clearRecent,
                        child: const Text('Clear'),
                      ),
                      child: _ResultsColumn(
                        items: const PlacesRanker().rank(
                          _recent, '',
                          origin: origin,
                        ),
                        selected: _selected,
                        onHover: (s) => setState(() => _selected = s),
                        onPick: _pick,
                      ),
                    ),
                  )
                else if (_searching)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: _BottomSheet(
                      title: 'Searching…',
                      child: const _ShimmerResults(count: 4),
                    ),
                  )
                else if (_error != null)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: _BottomSheet(
                      title: 'Search error',
                      child: _ErrorState(
                        message: _error!,
                        onRetry: _search,
                      ),
                    ),
                  )
                else if (_results.isNotEmpty)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: _BottomSheet(
                      title: '${_results.length} '
                          'result${_results.length == 1 ? '' : 's'}',
                      child: _ResultsColumn(
                        items: _ranked,
                        selected: _selected,
                        onHover: (s) => setState(() => _selected = s),
                        onPick: _pick,
                      ),
                    ),
                  )
                else if (query.length >= 3 && !_searching)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: _BottomSheet(
                      title: 'No matches',
                      child: _EmptyState(
                        headline: 'No matches for "$query"',
                        subline: 'Try a different venue, neighbourhood, '
                            'or tap the map to drop a pin.',
                      ),
                    ),
                  )
                else if (showInitialState)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: _BottomSheet(
                      title: 'Tip',
                      child: _EmptyState(
                        headline: 'Search a venue or drop a pin',
                        subline:
                            'Start typing — e.g. "Auckland Domain" — or tap '
                            'anywhere on the map.',
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── chrome ─────────────────────────────────────────────────────────────────

class _GrabHandle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 6),
      child: Center(
        child: Container(
          width: 36,
          height: 4,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.outlineVariant,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.title, required this.onClose});
  final String title;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.x4,
        0,
        AppSpacing.x2,
        AppSpacing.x2,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Close',
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
    );
  }
}

// ─── search bar ─────────────────────────────────────────────────────────────

class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onSubmitted,
    required this.searching,
    required this.hasText,
    required this.onClear,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final bool searching;
  final bool hasText;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      height: 52,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(width: 16),
          // Plain leading search glyph — no focus-driven colour
          // or background change, so the field stays visually
          // stable when the user taps into it.
          Icon(
            Icons.search_rounded,
            size: 20,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              textInputAction: TextInputAction.search,
              onChanged: onChanged,
              onSubmitted: onSubmitted,
              // Neutral cursor (not theme primary) so there is no
              // blue accent left on the field when it gains focus.
              cursorColor: theme.colorScheme.onSurfaceVariant,
              cursorWidth: 1.4,
              // Explicitly disable every border variant so neither
              // Android nor iOS draws the platform focus rectangle.
              enableInteractiveSelection: true,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.onSurface,
                height: 1.2,
              ),
              decoration: InputDecoration(
                isCollapsed: true,
                hintText: 'Search places',
                hintStyle: theme.textTheme.bodyLarge?.copyWith(
                  fontSize: 16,
                  color: theme.colorScheme.onSurfaceVariant
                      .withValues(alpha: 0.7),
                  fontWeight: FontWeight.w400,
                ),
                border: InputBorder.none,
                focusedBorder: InputBorder.none,
                enabledBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 18,
                ),
              ),
            ),
          ),
          // Suffix: spinner OR clear-X — never both, never squashed.
          SizedBox(
            width: 44,
            height: 52,
            child: searching
                ? Center(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          theme.colorScheme.primary,
                        ),
                      ),
                    ),
                  )
                : hasText
                    ? IconButton(
                        splashRadius: 18,
                        padding: EdgeInsets.zero,
                        tooltip: 'Clear',
                        onPressed: () {
                          HapticFeedback.selectionClick();
                          onClear();
                        },
                        icon: Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      )
                    : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

// ─── map ────────────────────────────────────────────────────────────────────

class _Map extends StatefulWidget {
  const _Map({required this.selected, required this.onPickedLocation});

  final LatLng? selected;
  final ValueChanged<LatLng> onPickedLocation;

  @override
  State<_Map> createState() => _MapState();
}

class _MapState extends State<_Map> {
  late final MapController _ctrl = MapController();
  double _zoom = 13;
  LatLng? _userLocation;
  bool _locating = false;
  // Fallback if we never get a GPS fix (matches the seed-data
  // centre so distance ranking is still meaningful for the demo).
  static const LatLng _defaultCenter = LatLng(-36.8485, 174.7633);

  static const _maxZoom = 19.0;
  static const _minZoom = 4.0;

  @override
  void initState() {
    super.initState();
    _zoom = widget.selected != null ? 15.0 : 13.0;
    // Don't auto-resolve GPS here. The default map view is
    // Auckland, the default search origin is Auckland, and the
    // user has to explicitly opt in to "zoom to me" by tapping
    // the recenter button. Auto-resolving on mount would silently
    // change the search ranking origin to wherever the device
    // happens to be (often surprising users who never asked).
  }

  Future<void> _resolveUserLocation() async {
    if (_locating) return;
    setState(() => _locating = true);
    try {
      final pos = await LocationService.instance.getCurrentLocation();
      if (!mounted) return;
      if (pos != null) {
        setState(() {
          _userLocation = LatLng(pos.latitude, pos.longitude);
        });
      }
    } on LocationTimeoutException {
      // Slow fix — keep the bundled fallback origin.
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _zoomBy(double delta) {
    final next = (_zoom + delta).clamp(_minZoom, _maxZoom);
    if (next == _zoom) return;
    setState(() => _zoom = next);
    _ctrl.move(_ctrl.camera.center, next);
    HapticFeedback.selectionClick();
  }

  /// Recenters the map. Priority:
  ///   1. Currently selected venue (if any)
  ///   2. Cached GPS fix
  ///   3. Resolved GPS fix (one-shot async)
  ///   4. Default centre (central Auckland)
  Future<void> _recenter() async {
    HapticFeedback.selectionClick();
    final selected = widget.selected;
    if (selected != null) {
      setState(() => _zoom = 15);
      _ctrl.move(selected, 15);
      return;
    }
    final cached = _userLocation;
    if (cached != null) {
      setState(() => _zoom = 14);
      _ctrl.move(cached, 14);
      return;
    }
    await _resolveUserLocation();
    if (!mounted) return;
    final here = _userLocation;
    if (here != null) {
      setState(() => _zoom = 14);
      _ctrl.move(here, 14);
    } else {
      setState(() => _zoom = 13);
      _ctrl.move(_defaultCenter, 13);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Default view is always the bundled Auckland centre — the
    // user has to explicitly opt in to "zoom to me" via the
    // recenter button.
    final initialCenter = widget.selected ?? _defaultCenter;
    return FlutterMap(
      mapController: _ctrl,
      options: MapOptions(
        initialCenter: initialCenter,
        initialZoom: _zoom,
        minZoom: _minZoom,
        maxZoom: _maxZoom,
        onTap: (tapPosition, point) {
          HapticFeedback.selectionClick();
          widget.onPickedLocation(point);
        },
        onPositionChanged: (camera, hasGesture) {
          if (!hasGesture) return;
          if (camera.zoom != _zoom) {
            setState(() => _zoom = camera.zoom);
          }
        },
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
        ),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'matchup-demo/1.0',
        ),
        if (_userLocation != null)
          MarkerLayer(
            markers: [
              Marker(
                point: _userLocation!,
                width: 22,
                height: 22,
                child: const _UserLocationDot(),
              ),
            ],
          ),
        if (widget.selected != null)
          MarkerLayer(
            markers: [
              Marker(
                point: widget.selected!,
                width: 44,
                height: 44,
                child: const _Pin(),
              ),
            ],
          ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: _OsmAttribution(),
        ),
        Positioned(
          right: 12,
          top: 12,
          child: _MapControls(
            zoom: _zoom,
            locating: _locating,
            minZoom: _minZoom,
            maxZoom: _maxZoom,
            onZoomIn: () => _zoomBy(1),
            onZoomOut: () => _zoomBy(-1),
            onRecenter: _recenter,
          ),
        ),
      ],
    );
  }
}

class _MapControls extends StatelessWidget {
  const _MapControls({
    required this.zoom,
    required this.locating,
    required this.minZoom,
    required this.maxZoom,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onRecenter,
  });

  final double zoom;
  final bool locating;
  final double minZoom;
  final double maxZoom;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final Future<void> Function() onRecenter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      elevation: 3,
      shadowColor: Colors.black.withValues(alpha: 0.18),
      borderRadius: BorderRadius.circular(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _MapCtrlBtn(
            icon: Icons.add_rounded,
            enabled: zoom < maxZoom,
            onTap: onZoomIn,
            semanticLabel: 'Zoom in',
            radius: const BorderRadius.vertical(top: Radius.circular(12)),
          ),
          Container(
            height: 0.5,
            width: 28,
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
          ),
          _MapCtrlBtn(
            icon: Icons.remove_rounded,
            enabled: zoom > minZoom,
            onTap: onZoomOut,
            semanticLabel: 'Zoom out',
          ),
          Container(
            height: 0.5,
            width: 28,
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
          ),
          // Recenter (GPS) — has a spinner overlay while we wait
          // for the platform location stream.
          _RecenterButton(
            locating: locating,
            onTap: () => onRecenter(),
          ),
        ],
      ),
    );
  }
}

/// Filled icon button used for the GPS recenter action. Shows a
/// small spinner overlay while [locating] is true so the user
/// has feedback that the request is in flight.
class _RecenterButton extends StatelessWidget {
  const _RecenterButton({
    required this.locating,
    required this.onTap,
  });

  final bool locating;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      label: 'Recenter map on my location',
      child: InkWell(
        onTap: locating ? null : onTap,
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(12),
        ),
        child: SizedBox(
          width: 40,
          height: 40,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (locating)
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      theme.colorScheme.primary,
                    ),
                  ),
                )
              else
                Icon(
                  Icons.my_location_rounded,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pulsing dot drawn at the device's resolved GPS location.
/// Distinct from the venue pin (which is the larger drop-style
/// marker) so the user can tell the two apart at a glance.
class _UserLocationDot extends StatelessWidget {
  const _UserLocationDot();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.18),
            shape: BoxShape.circle,
          ),
        ),
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MapCtrlBtn extends StatelessWidget {
  const _MapCtrlBtn({
    required this.icon,
    required this.enabled,
    required this.onTap,
    required this.semanticLabel,
    this.radius,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;
  final String semanticLabel;
  final BorderRadius? radius;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shape = radius ?? BorderRadius.zero;
    return Semantics(
      button: true,
      label: semanticLabel,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: shape,
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          child: Icon(
            icon,
            size: 20,
            color: enabled
                ? theme.colorScheme.onSurface
                : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
          ),
        ),
      ),
    );
  }
}

class _OsmAttribution extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.85),
        borderRadius: const BorderRadius.only(topLeft: Radius.circular(6)),
      ),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '\u00a9 ',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 10,
              ),
            ),
            TextSpan(
              text: 'OpenStreetMap',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.primary,
                fontSize: 10,
                fontWeight: FontWeight.w500,
                decoration: TextDecoration.underline,
              ),
              recognizer: null,
            ),
          ],
        ),
      ),
    );
  }
}

class _Pin extends StatelessWidget {
  const _Pin();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.18),
            shape: BoxShape.circle,
          ),
        ),
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Center(
            child: Icon(Icons.place_rounded, color: Colors.white, size: 16),
          ),
        ),
      ],
    );
  }
}

// ─── bottom sheet (over the map) ────────────────────────────────────────────

class _BottomSheet extends StatelessWidget {
  const _BottomSheet({
    required this.title,
    required this.child,
    this.trailing,
  });

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.55,
        ),
        child: Material(
          color: context.colors.surface,
          elevation: 0,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag handle.
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Center(
                  child: Container(
                    width: 32,
                    height: 3,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.x4,
                  AppSpacing.x3,
                  AppSpacing.x2,
                  AppSpacing.x2,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurfaceVariant,
                          letterSpacing: 0.1,
                        ),
                      ),
                    ),
                    ?trailing,
                  ],
                ),
              ),
              Flexible(child: child),
              const SizedBox(height: AppSpacing.x2),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── result row + list ──────────────────────────────────────────────────────

class _ResultsColumn extends StatelessWidget {
  const _ResultsColumn({
    required this.items,
    required this.selected,
    required this.onHover,
    required this.onPick,
  });

  /// Already-ranked suggestions. Distance + matched ranges are
  /// pre-computed for us by [PlacesRanker]; the row just renders
  /// them.
  final List<RankedPlace> items;
  final PlaceSuggestion? selected;
  final void Function(PlaceSuggestion) onHover;
  final void Function(PlaceSuggestion) onPick;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      physics: const ClampingScrollPhysics(),
      itemCount: items.length,
      separatorBuilder: (_, i) => const _HairlineDivider(),
      itemBuilder: (_, i) {
        final r = items[i];
        final s = r.suggestion;
        final isSelected = selected?.placeId == s.placeId;
        return _ResultRow(
          ranked: r,
          selected: isSelected,
          onHover: () => onHover(s),
          onPick: () => onPick(s),
        );
      },
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({
    required this.ranked,
    required this.selected,
    required this.onHover,
    required this.onPick,
  });

  final RankedPlace ranked;
  final bool selected;
  final VoidCallback onHover;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: selected
          ? theme.colorScheme.primaryContainer.withValues(alpha: 0.5)
          : Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onHover();
          onPick();
        },
        onHover: (_) => onHover(),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.x4,
            vertical: AppSpacing.x3,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _CategoryAvatar(
                label: ranked.suggestion.label,
                selected: selected,
              ),
              const SizedBox(width: AppSpacing.x3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text.rich(
                            _highlightLabel(
                              label: ranked.suggestion.label,
                              ranges: ranked.matchedRanges,
                              selected: selected,
                              color: theme.colorScheme.onSurface,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (selected) ...[
                          const SizedBox(width: 6),
                          Icon(
                            Icons.check_circle_rounded,
                            size: 16,
                            color: theme.colorScheme.primary,
                          ),
                        ],
                      ],
                    ),
                    if (ranked.suggestion.secondary.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        ranked.suggestion.secondary,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontSize: 13,
                          color: theme.colorScheme.onSurfaceVariant,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.x2),
              _DistanceBadge(
                km: ranked.distanceKm,
                selected: selected,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Rounded-square avatar that picks a category-specific icon
/// based on keywords in the venue label (parks, beaches,
/// museums, etc.). Falls back to a generic place glyph when no
/// keyword matches.
class _CategoryAvatar extends StatelessWidget {
  const _CategoryAvatar({
    required this.label,
    required this.selected,
  });

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (icon, tint) = _categoryStyle(label, theme);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: selected
            ? theme.colorScheme.primary
            : tint.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.center,
      child: Icon(
        icon,
        size: 22,
        color: selected ? theme.colorScheme.onPrimary : tint,
      ),
    );
  }
}

/// Keyword → (icon, accent colour) table. Keep this small and
/// ordered from most specific → least specific.
final List<(RegExp, IconData, Color Function(ThemeData))> _kCategoryTable = [
  // Parks / gardens / domains.
  (RegExp(r'\b(park|garden|domain|reserve|playground)\b', caseSensitive: false),
      Icons.park_rounded,
      (t) => t.colorScheme.tertiary),
  // Beaches / bays / waterfront.
  (RegExp(r'\b(beach|bay|cove|harbour|harbor|waterfront|marina)\b',
      caseSensitive: false),
      Icons.beach_access_rounded,
      (t) => t.colorScheme.primary),
  // Creeks / rivers / lakes / falls.
  (RegExp(r'\b(creek|river|lake|falls?|springs?|stream)\b',
      caseSensitive: false),
      Icons.water_rounded,
      (t) => t.colorScheme.secondary),
  // Museums / galleries / libraries.
  (RegExp(r'\b(museum|gallery|library|archive)\b', caseSensitive: false),
      Icons.museum_rounded,
      (t) => t.colorScheme.tertiary),
  // Sports / stadium / arena / court.
  (RegExp(r'\b(stadium|arena|court|field|gym|pool|sports?)\b',
      caseSensitive: false),
      Icons.sports_soccer_rounded,
      (t) => t.colorScheme.secondary),
  // Mountains / hills / lookouts / tracks.
  (RegExp(r'\b(mount|mt\.?|hill|peak|lookout|track|ridge|summit)\b',
      caseSensitive: false),
      Icons.landscape_rounded,
      (t) => t.colorScheme.primary),
  // Cafe / restaurant / food.
  (RegExp(r'\b(cafe|café|coffee|restaurant|food|kitchen|bar)\b',
      caseSensitive: false),
      Icons.restaurant_rounded,
      (t) => t.colorScheme.tertiary),
];

(IconData, Color) _categoryStyle(String label, ThemeData theme) {
  for (final (pattern, icon, colorOf) in _kCategoryTable) {
    if (pattern.hasMatch(label)) return (icon, colorOf(theme));
  }
  return (Icons.place_rounded, theme.colorScheme.primary);
}

/// Renders the distance label + selected-arrow as a single right-
/// aligned column. Uses tabular figures so the distance text
/// doesn't visually "jump" between rows.
class _DistanceBadge extends StatelessWidget {
  const _DistanceBadge({required this.km, required this.selected});
  final double km;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = _formatDistance(km);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: selected
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurfaceVariant,
            fontFeatures: const [FontFeature.tabularFigures()],
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
        if (selected) ...[
          const SizedBox(height: 2),
          Icon(
            Icons.arrow_forward_rounded,
            size: 14,
            color: theme.colorScheme.primary,
          ),
        ],
      ],
    );
  }

  static String _formatDistance(double km) {
    if (km < 1) {
      final m = (km * 1000).round();
      return '${m}m';
    }
    if (km < 10) return '${km.toStringAsFixed(1)}km';
    return '${km.round()}km';
  }
}

/// Builds a TextSpan tree for the venue label with the matched
/// query ranges drawn in bold primary color. Falls back to a
/// plain TextStyle when there are no ranges.
TextSpan _highlightLabel({
  required String label,
  required List<(int, int)> ranges,
  required bool selected,
  required Color color,
}) {
  if (ranges.isEmpty) {
    return TextSpan(
      text: label,
      style: TextStyle(
        fontSize: 15,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
        color: color,
      ),
    );
  }
  final children = <TextSpan>[];
  var cursor = 0;
  final bold = FontWeight.w700;
  final regular = selected ? FontWeight.w600 : FontWeight.w500;
  for (final r in ranges) {
    if (cursor < r.$1) {
      children.add(TextSpan(
        text: label.substring(cursor, r.$1),
        style: TextStyle(
          fontSize: 15,
          fontWeight: regular,
          color: color,
        ),
      ));
    }
    children.add(TextSpan(
      text: label.substring(r.$1, r.$2),
      style: TextStyle(
        fontSize: 15,
        fontWeight: bold,
        color: color, // keep color consistent — bolder weight alone
                       // does the highlighting, avoids a noisy look.
      ),
    ));
    cursor = r.$2;
  }
  if (cursor < label.length) {
    children.add(TextSpan(
      text: label.substring(cursor),
      style: TextStyle(
        fontSize: 15,
        fontWeight: regular,
        color: color,
      ),
    ));
  }
  return TextSpan(children: children);
}

class _HairlineDivider extends StatelessWidget {
  const _HairlineDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 64),
      child: Container(
        height: 0.5,
        color: Theme.of(context).dividerColor.withValues(alpha: 0.6),
      ),
    );
  }
}

// ─── states ─────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.headline, required this.subline});

  final String headline;
  final String subline;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.x4,
        AppSpacing.x2,
        AppSpacing.x4,
        AppSpacing.x4,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.search_off_rounded,
              size: 26,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.x3),
          Text(
            headline,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subline,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.x4,
        AppSpacing.x2,
        AppSpacing.x4,
        AppSpacing.x4,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: theme.colorScheme.errorContainer.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(16),
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.cloud_off_rounded,
              size: 26,
              color: theme.colorScheme.onErrorContainer,
            ),
          ),
          const SizedBox(height: AppSpacing.x3),
          Text(
            message,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: AppSpacing.x3),
          FilledButton.tonalIcon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

class _ShimmerResults extends StatefulWidget {
  const _ShimmerResults({this.count = 4});
  final int count;

  @override
  State<_ShimmerResults> createState() => _ShimmerResultsState();
}

class _ShimmerResultsState extends State<_ShimmerResults>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final base = theme.colorScheme.surfaceContainerHighest;
    final highlight = theme.colorScheme.surfaceContainerHigh;
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: widget.count,
      separatorBuilder: (_, i) => const _HairlineDivider(),
      itemBuilder: (_, i) => Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.x4,
          vertical: AppSpacing.x3,
        ),
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (_, c) {
            final t = _ctrl.value;
            return Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Color.lerp(base, highlight, t),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(width: AppSpacing.x3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        height: 12,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Color.lerp(base, highlight, t),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 10,
                        width: 180,
                        decoration: BoxDecoration(
                          color: Color.lerp(base, highlight, t),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ─── floating "Use this location" ───────────────────────────────────────────

/// Card shown after a tap-on-map pick. Offers a small text field so the
/// user can NAME the dropped pin instead of keeping raw coordinates —
/// prefilled with the reverse-geocoded label when one is available
/// (none exists today: [PlacesRepository] only exposes autocomplete,
/// so it starts empty with the 'Name this place' hint). The entered
/// value becomes the location name on confirm; blank falls back to
/// the `lat, lng` coordinates as before.
class _PickedLocationCard extends StatefulWidget {
  const _PickedLocationCard({
    required this.latLng,
    required this.onConfirm,
  });

  final LatLng latLng;
  final ValueChanged<String> onConfirm;

  @override
  State<_PickedLocationCard> createState() => _PickedLocationCardState();
}

class _PickedLocationCardState extends State<_PickedLocationCard> {
  // No reverse-geocode endpoint exists ([PlacesRepository] only exposes
  // autocomplete), so the field starts empty with the hint below; when
  // a reverse lookup is available, prefill the controller with it here.
  late final TextEditingController _nameCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  void _confirm() {
    HapticFeedback.lightImpact();
    widget.onConfirm(_nameCtrl.text);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: context.colors.surface,
      elevation: 6,
      shadowColor: Colors.black.withValues(alpha: 0.18),
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.x3),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.place_rounded,
                    size: 20,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: AppSpacing.x3),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Dropped pin',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${widget.latLng.latitude.toStringAsFixed(5)}, '
                        '${widget.latLng.longitude.toStringAsFixed(5)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.x2),
            TextField(
              controller: _nameCtrl,
              textInputAction: TextInputAction.done,
              textCapitalization: TextCapitalization.words,
              maxLength: 80,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
              decoration: InputDecoration(
                hintText: 'Name this place',
                hintStyle: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant.withValues(
                    alpha: 0.7,
                  ),
                ),
                isDense: true,
                counterText: '',
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: theme.colorScheme.outlineVariant),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: theme.colorScheme.primary),
                ),
              ),
              onSubmitted: (_) => _confirm(),
            ),
            const SizedBox(height: AppSpacing.x2),
            FilledButton(
              onPressed: _confirm,
              child: const Text('Use'),
            ),
          ],
        ),
      ),
    );
  }
}
