import 'package:flutter/widgets.dart';

import '../domain/tour_step.dart';

/// Static registry of [GlobalKey]s that coach-mark steps spotlight.
///
/// There is exactly one key per anchor for the whole app — each key must be
/// applied to exactly one live widget at a time (a duplicate-GlobalKey
/// exception is thrown otherwise). `swipeDeck` and `actionRow` live on
/// Discovery; the `tab*` keys live on [AppShell]'s tab bar, which is
/// mounted once for the whole app (inside the `ShellRoute`), so they are
/// never duplicated across screens.
class TourAnchors {
  TourAnchors._();

  static final swipeDeck = GlobalKey(debugLabel: 'tour.swipeDeck');
  static final actionRow = GlobalKey(debugLabel: 'tour.actionRow');
  static final filterButton = GlobalKey(debugLabel: 'tour.filterButton');
  static final tabMyGames = GlobalKey(debugLabel: 'tour.tabMyGames');
  static final tabCreate = GlobalKey(debugLabel: 'tour.tabCreate');
  static final tabChat = GlobalKey(debugLabel: 'tour.tabChat');
  static final tabProfile = GlobalKey(debugLabel: 'tour.tabProfile');

  /// Resolves a [TourAnchorId] to its registered [GlobalKey].
  /// [TourAnchorId.none] has no anchor by design and returns `null`.
  static GlobalKey? keyFor(TourAnchorId id) {
    switch (id) {
      case TourAnchorId.none:
        return null;
      case TourAnchorId.swipeDeck:
        return swipeDeck;
      case TourAnchorId.actionRow:
        return actionRow;
      case TourAnchorId.filterButton:
        return filterButton;
      case TourAnchorId.tabMyGames:
        return tabMyGames;
      case TourAnchorId.tabCreate:
        return tabCreate;
      case TourAnchorId.tabChat:
        return tabChat;
      case TourAnchorId.tabProfile:
        return tabProfile;
    }
  }
}
