export type MemberStatus = 'Active' | 'Inactive' | 'Suspended' | 'Pending';
export type MemberRole = 'Player' | 'Host' | 'Moderator';

export interface Member {
  id: string;
  name: string;
  username: string;       // @handle derived from name
  email: string;
  phone?: string;
  role: MemberRole;
  status: MemberStatus;
  // Sports + skill level pairs — matches mobile UserModel
  sports: { sport: string; level: string }[];
  bio?: string;
  location?: string;
  joinedDate: string;
  activitiesJoined: number;
  activitiesHosted: number;
  rating: number;
  avatarSeed: string;
  // Edit Profile fields (admin-only view)
  dateOfBirth?: string;   // ISO date string
  heightCm?: number;
  weightKg?: number;
  goal?: string;
}

export const DUMMY_MEMBERS: Member[] = [
  {
    id: 'm1', name: 'Alex Mercer', username: '@alexmercer',
    email: 'alex@example.com', phone: '+62 812-3456-7890',
    role: 'Host', status: 'Active',
    sports: [{ sport: 'Basketball', level: 'Intermediate' }, { sport: 'Running', level: 'Beginner' }],
    bio: 'Weekend basketball fanatic. Love organising pick-up games and meeting new players.',
    location: 'Jakarta, Indonesia',
    joinedDate: 'Jan 12, 2026', activitiesJoined: 24, activitiesHosted: 8, rating: 4.9,
    avatarSeed: 'alex',
    dateOfBirth: '1995-03-15', heightCm: 178, weightKg: 72, goal: 'Stay active 3x/week',
  },
  {
    id: 'm2', name: 'Sarah Chen', username: '@sarahchen',
    email: 'sarah@example.com',
    role: 'Player', status: 'Active',
    sports: [{ sport: 'Tennis', level: 'Advanced' }, { sport: 'Yoga', level: 'Intermediate' }],
    bio: 'Tennis player and yoga enthusiast. Always looking for doubles partners.',
    location: 'Bandung, Indonesia',
    joinedDate: 'Feb 3, 2026', activitiesJoined: 17, activitiesHosted: 0, rating: 4.6,
    avatarSeed: 'sarah',
    dateOfBirth: '1998-07-22', heightCm: 163, weightKg: 55,
  },
  {
    id: 'm3', name: 'Marcus Lee', username: '@marcuslee',
    email: 'marcus@example.com', phone: '+62 878-9012-3456',
    role: 'Host', status: 'Suspended',
    sports: [{ sport: 'Futsal', level: 'Advanced' }],
    bio: 'Futsal coach. Organising weekly sessions since 2024.',
    location: 'Surabaya, Indonesia',
    joinedDate: 'Mar 8, 2026', activitiesJoined: 5, activitiesHosted: 3, rating: 2.1,
    avatarSeed: 'marcus',
    dateOfBirth: '1990-11-05', heightCm: 172, weightKg: 68,
  },
  {
    id: 'm4', name: 'Julia Kent', username: '@juliakent',
    email: 'julia@example.com',
    role: 'Player', status: 'Active',
    sports: [{ sport: 'Running', level: 'Intermediate' }, { sport: 'Cycling', level: 'Beginner' }],
    bio: 'Marathon runner training for my first half-marathon. Open to any cardio activities!',
    location: 'Jakarta, Indonesia',
    joinedDate: 'Jan 20, 2026', activitiesJoined: 31, activitiesHosted: 0, rating: 4.8,
    avatarSeed: 'julia',
    heightCm: 165, weightKg: 57, goal: 'Run half-marathon under 2h',
  },
  {
    id: 'm5', name: 'Hana Shiro', username: '@hanashiro',
    email: 'hana@example.com',
    role: 'Host', status: 'Active',
    sports: [{ sport: 'Badminton', level: 'Advanced' }, { sport: 'Tennis', level: 'Intermediate' }],
    bio: 'Badminton coach with 8 years experience. Hosting regular sessions at Senayan.',
    location: 'Jakarta, Indonesia',
    joinedDate: 'Feb 14, 2026', activitiesJoined: 12, activitiesHosted: 5, rating: 4.7,
    avatarSeed: 'hana',
    dateOfBirth: '1993-05-30', heightCm: 158, weightKg: 50,
  },
  {
    id: 'm6', name: 'Gavin Reed', username: '@gavinreed',
    email: 'gavin@example.com',
    role: 'Player', status: 'Inactive',
    sports: [{ sport: 'Cycling', level: 'Intermediate' }],
    location: 'Bali, Indonesia',
    joinedDate: 'Apr 1, 2026', activitiesJoined: 4, activitiesHosted: 0, rating: 3.9,
    avatarSeed: 'gavin',
  },
  {
    id: 'm7', name: 'Nolan Vance', username: '@nolanvance',
    email: 'nolan@example.com', phone: '+62 856-7890-1234',
    role: 'Host', status: 'Active',
    sports: [{ sport: 'Futsal', level: 'Intermediate' }, { sport: 'Basketball', level: 'Beginner' }],
    bio: 'Organising futsal sessions every Wednesday. DM for details.',
    location: 'Jakarta, Indonesia',
    joinedDate: 'Jan 5, 2026', activitiesJoined: 9, activitiesHosted: 11, rating: 4.5,
    avatarSeed: 'nolan',
    dateOfBirth: '1992-08-18', heightCm: 181, weightKg: 80,
  },
  {
    id: 'm8', name: 'Coach Dave', username: '@coachdave',
    email: 'dave@example.com',
    role: 'Host', status: 'Pending',
    sports: [{ sport: 'Badminton', level: 'Advanced' }],
    bio: 'Professional badminton coach. Looking to connect with players in Jakarta.',
    location: 'Depok, Indonesia',
    joinedDate: 'May 2, 2026', activitiesJoined: 2, activitiesHosted: 1, rating: 3.2,
    avatarSeed: 'dave',
  },
  {
    id: 'm9', name: 'Jordan Torres', username: '@jordantorres',
    email: 'jordan@example.com',
    role: 'Player', status: 'Active',
    sports: [{ sport: 'Volleyball', level: 'Intermediate' }, { sport: 'Swimming', level: 'Beginner' }],
    bio: 'Beach volleyball player. Always up for outdoor activities.',
    location: 'Tangerang, Indonesia',
    joinedDate: 'Mar 15, 2026', activitiesJoined: 19, activitiesHosted: 0, rating: 4.4,
    avatarSeed: 'jordan',
    heightCm: 180, weightKg: 75,
  },
  {
    id: 'm10', name: 'Priya Nair', username: '@priyanair',
    email: 'priya@example.com',
    role: 'Moderator', status: 'Active',
    sports: [{ sport: 'Yoga', level: 'Advanced' }, { sport: 'Running', level: 'Intermediate' }],
    bio: 'Yoga instructor and platform moderator. Here to help keep the community healthy.',
    location: 'Jakarta, Indonesia',
    joinedDate: 'Feb 28, 2026', activitiesJoined: 7, activitiesHosted: 2, rating: 4.9,
    avatarSeed: 'priya',
    dateOfBirth: '1994-12-01', heightCm: 160, weightKg: 53, goal: 'Teach yoga to 100 people this year',
  },
];
