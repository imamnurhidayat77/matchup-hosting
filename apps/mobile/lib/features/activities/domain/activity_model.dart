/// Domain model for a sports activity card displayed in the discovery feed.
class ActivityModel {
  final String id;
  final String title;
  final String sportType;
  final String description;

  /// Venue name — the primary location line (e.g. `Brooklyn Public Courts`).
  final String location;

  /// Street-level address shown beneath [location] on the detail screen
  /// (e.g. `Court #3, Prospect Park, NY`). When null the UI falls back to
  /// showing [distanceKm] instead, so the second line is never blank.
  final String? addressLine;

  final double distanceKm;
  final DateTime dateTime;
  final String skillLevel;
  final int capacity;
  final int participantCount;
  final String hostName;
  final String? coverImageUrl;
  final ActivityStatus status;

  const ActivityModel({
    required this.id,
    required this.title,
    required this.sportType,
    required this.description,
    required this.location,
    this.addressLine,
    required this.distanceKm,
    required this.dateTime,
    required this.skillLevel,
    required this.capacity,
    required this.participantCount,
    required this.hostName,
    this.coverImageUrl,
    this.status = ActivityStatus.available,
  });

  bool get isFull => participantCount >= capacity;
  bool get isAlmostFull => participantCount >= (capacity * 0.8).ceil();

  int get spotsLeft => capacity - participantCount;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'sportType': sportType,
      'description': description,
      'location': location,
      'addressLine': addressLine,
      'distanceKm': distanceKm,
      'dateTime': dateTime.toIso8601String(),
      'skillLevel': skillLevel,
      'capacity': capacity,
      'participantCount': participantCount,
      'hostName': hostName,
      'coverImageUrl': coverImageUrl,
      'status': status.index,
    };
  }

  factory ActivityModel.fromJson(Map<String, dynamic> json) {
    return ActivityModel(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      sportType: json['sportType'] as String? ?? '',
      description: json['description'] as String? ?? '',
      location: json['location'] as String? ?? '',
      addressLine: json['addressLine'] as String?,
      distanceKm: (json['distanceKm'] as num?)?.toDouble() ?? 0.0,
      dateTime: DateTime.parse(
        json['dateTime'] as String? ?? DateTime.now().toIso8601String(),
      ),
      skillLevel: json['skillLevel'] as String? ?? '',
      capacity: json['capacity'] as int? ?? 10,
      participantCount: json['participantCount'] as int? ?? 0,
      hostName: json['hostName'] as String? ?? '',
      coverImageUrl: json['coverImageUrl'] as String?,
      status: ActivityStatus.values[json['status'] as int? ?? 0],
    );
  }
}

enum ActivityStatus { available, almostFull, full, joined, hosted, past }
