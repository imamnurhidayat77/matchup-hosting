export type ActivityStatus = 'Active' | 'Full' | 'Completed' | 'Cancelled' | 'Flagged';

export interface AdminActivity {
  id: string;
  name: string;
  matchId: string;
  sport: string;
  skillLevel: string;
  host: string;
  hostAvatarSeed: string;
  hostRating: number;
  hostGamesCount: number;
  location: string;
  addressLine?: string;
  scheduledDate: string;       // human-readable date
  startTime: string;           // e.g. "4:00 PM"
  endTime: string;             // e.g. "6:00 PM"
  durationMinutes: number;
  participants: number;
  capacity: number;
  status: ActivityStatus;
  description: string;
  isPaid: boolean;
  fee?: number;
  vibeTags: string[];
  distanceKm?: number;
}

export const DUMMY_ACTIVITIES: AdminActivity[] = [
  {
    id: 'a1', name: 'Wednesday Night Futsal Cup', matchId: 'MU-1082',
    sport: 'Futsal', skillLevel: 'Intermediate',
    host: 'Nolan Vance', hostAvatarSeed: 'nolan', hostRating: 4.5, hostGamesCount: 11,
    location: 'Sports Hall B', addressLine: 'Gate 3, Sports Complex, Jakarta',
    scheduledDate: 'Oct 25, 2026', startTime: '7:00 PM', endTime: '9:00 PM', durationMinutes: 120,
    participants: 10, capacity: 10, status: 'Full',
    description: 'Competitive futsal session. Bring your own cleats. Teams picked randomly on arrival.',
    isPaid: true, fee: 10,
    vibeTags: ['Competitive', 'Teams balanced', 'Arrive 10m early'],
    distanceKm: 2.4,
  },
  {
    id: 'a2', name: 'Saturdays 5v5 Half-Court Run', matchId: 'MU-1156',
    sport: 'Basketball', skillLevel: 'Beginner',
    host: 'Marcus Brody', hostAvatarSeed: 'marcus', hostRating: 4.8, hostGamesCount: 28,
    location: 'Central Court', addressLine: 'Riverside Park, Court #2',
    scheduledDate: 'Oct 28, 2026', startTime: '8:00 AM', endTime: '10:00 AM', durationMinutes: 120,
    participants: 12, capacity: 15, status: 'Active',
    description: 'Casual half-court basketball. All levels welcome — we focus on fun over winning.',
    isPaid: false,
    vibeTags: ['Friendly people', 'Great vibes', 'Beginners welcome'],
    distanceKm: 1.2,
  },
  {
    id: 'a3', name: 'Morning Cardio & Running Club', matchId: 'MU-1193',
    sport: 'Running', skillLevel: 'All Levels',
    host: 'Julia Kent', hostAvatarSeed: 'julia', hostRating: 4.9, hostGamesCount: 42,
    location: 'Riverside Park', addressLine: 'Main entrance, Riverside Park',
    scheduledDate: 'Oct 29, 2026', startTime: '6:00 AM', endTime: '7:30 AM', durationMinutes: 90,
    participants: 28, capacity: 50, status: 'Active',
    description: 'Group run at an easy pace. 5km loop around the park. Perfect for beginners and regular runners alike.',
    isPaid: false,
    vibeTags: ['Chill pace', 'Outdoors', 'All fitness levels'],
    distanceKm: 3.1,
  },
  {
    id: 'a4', name: 'Elite Smash Court Badminton', matchId: 'MU-1119',
    sport: 'Badminton', skillLevel: 'Advanced',
    host: 'Hana Shiro', hostAvatarSeed: 'hana', hostRating: 4.7, hostGamesCount: 18,
    location: 'Indoor Hall 3', addressLine: 'Senayan Sports Centre, Hall 3',
    scheduledDate: 'Oct 22, 2026', startTime: '5:00 PM', endTime: '7:00 PM', durationMinutes: 120,
    participants: 8, capacity: 8, status: 'Completed',
    description: 'High-intensity doubles rotation. Advanced players only — must be able to sustain 20-shot rallies.',
    isPaid: true, fee: 8,
    vibeTags: ['Competitive', 'Advanced only', 'Court provided'],
    distanceKm: 5.8,
  },
  {
    id: 'a5', name: 'Coastal Highway Group Ride', matchId: 'MU-1082',
    sport: 'Cycling', skillLevel: 'Intermediate',
    host: 'Gavin Reed', hostAvatarSeed: 'gavin', hostRating: 3.8, hostGamesCount: 6,
    location: 'Coastal Road', addressLine: 'Coastal Hwy, Meeting point: 7-Eleven',
    scheduledDate: 'Oct 31, 2026', startTime: '6:30 AM', endTime: '9:30 AM', durationMinutes: 180,
    participants: 14, capacity: 20, status: 'Flagged',
    description: '60km road ride along the coast. Flat terrain, moderate pace. Bike must be in good condition.',
    isPaid: false,
    vibeTags: ['Scenic route', 'Bring water', 'Road bikes only'],
    distanceKm: 12.0,
  },
  {
    id: 'a6', name: 'Sunday Pick-Up Elite', matchId: 'MU-1201',
    sport: 'Basketball', skillLevel: 'Advanced',
    host: 'Alex Mercer', hostAvatarSeed: 'alex', hostRating: 4.9, hostGamesCount: 8,
    location: 'Park Courts', addressLine: 'Outdoor Court, Central Park',
    scheduledDate: 'Nov 3, 2026', startTime: '3:00 PM', endTime: '5:00 PM', durationMinutes: 120,
    participants: 6, capacity: 10, status: 'Active',
    description: 'Competitive pick-up game. Looking for players with solid fundamentals and good court vision.',
    isPaid: false,
    vibeTags: ['Competitive', 'Serious players', 'Full court'],
    distanceKm: 0.8,
  },
  {
    id: 'a7', name: 'Indoor Badminton Rally', matchId: 'MU-1230',
    sport: 'Badminton', skillLevel: 'Beginner',
    host: 'Coach Dave', hostAvatarSeed: 'dave', hostRating: 3.2, hostGamesCount: 1,
    location: 'City Sports', addressLine: 'City Sports Centre, Level 2',
    scheduledDate: 'Nov 5, 2026', startTime: '4:00 PM', endTime: '6:00 PM', durationMinutes: 120,
    participants: 4, capacity: 8, status: 'Cancelled',
    description: 'Casual mixed doubles. Racket provided if needed. Great for those new to badminton.',
    isPaid: true, fee: 12,
    vibeTags: ['Casual', 'Gear provided', 'Beginners welcome'],
    distanceKm: 4.5,
  },
];
