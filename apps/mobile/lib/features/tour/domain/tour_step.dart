/// Identifies which anchor a [TourStep] should spotlight. `none` means the
/// step is a centered dialog with no cut-out (used for the welcome step).
enum TourAnchorId {
  none,
  swipeDeck,
  actionRow,
  filterButton,
  tabMyGames,
  tabCreate,
  tabChat,
  tabProfile,
}

/// Shape of the spotlight cut-out drawn around the anchor's bounds.
enum TourSpotlightShape { roundedRect, circle }

/// A single step in a coach-mark tour: which element to highlight, and the
/// copy to show alongside it.
class TourStep {
  const TourStep({
    required this.anchor,
    required this.title,
    required this.body,
    this.shape = TourSpotlightShape.roundedRect,
    this.padding = 8,
  });

  /// Which registered [TourAnchorId] to spotlight. [TourAnchorId.none]
  /// renders the callout centered on screen with no cut-out.
  final TourAnchorId anchor;

  final String title;
  final String body;

  /// Shape of the cut-out around the anchor's bounds.
  final TourSpotlightShape shape;

  /// Extra space (in logical pixels) between the anchor's bounds and the
  /// edge of the spotlight cut-out.
  final double padding;
}
