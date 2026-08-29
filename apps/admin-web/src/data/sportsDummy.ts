/**
 * Master sports list — single source of truth for which sports appear in the
 * mobile app across: onboarding sport picker, discovery filter, and activity
 * creation form.
 *
 * Fields:
 *   id           — stable identifier used as sportType in ActivityModel
 *   name         — display name shown in mobile UI
 *   emoji        — icon shown in sport chip (mobile + admin)
 *   enabled      — whether it appears in the mobile app at all
 *   showInFilter — appears in the discovery filter screen
 *   showInOnboarding — appears in onboarding "which sports do you play?"
 *   canHost      — users can create activities of this type
 *   sortOrder    — lower = shown first in the mobile grid
 */
export interface SportConfig {
  id: string;
  name: string;
  emoji: string;
  enabled: boolean;
  showInFilter: boolean;
  showInOnboarding: boolean;
  canHost: boolean;
  sortOrder: number;
  activityCount: number; // read-only stat from platform
}

/** Default list — mirrors current mobile hardcoded _sportOptions */
export const DEFAULT_SPORTS: SportConfig[] = [
  { id: 'basketball', name: 'Basketball', emoji: '🏀', enabled: true,  showInFilter: true,  showInOnboarding: true,  canHost: true,  sortOrder: 1,  activityCount: 342 },
  { id: 'football',   name: 'Soccer',     emoji: '⚽', enabled: true,  showInFilter: true,  showInOnboarding: true,  canHost: true,  sortOrder: 2,  activityCount: 198 },
  { id: 'tennis',     name: 'Tennis',     emoji: '🎾', enabled: true,  showInFilter: true,  showInOnboarding: true,  canHost: true,  sortOrder: 3,  activityCount: 112 },
  { id: 'running',    name: 'Running',    emoji: '🏃', enabled: true,  showInFilter: true,  showInOnboarding: true,  canHost: true,  sortOrder: 4,  activityCount: 197 },
  { id: 'badminton',  name: 'Badminton',  emoji: '🏸', enabled: true,  showInFilter: true,  showInOnboarding: true,  canHost: true,  sortOrder: 5,  activityCount: 231 },
  { id: 'volleyball', name: 'Volleyball', emoji: '🏐', enabled: true,  showInFilter: true,  showInOnboarding: true,  canHost: true,  sortOrder: 6,  activityCount: 98  },
  { id: 'cycling',    name: 'Cycling',    emoji: '🚴', enabled: true,  showInFilter: true,  showInOnboarding: true,  canHost: true,  sortOrder: 7,  activityCount: 148 },
  { id: 'swimming',   name: 'Swimming',   emoji: '🏊', enabled: true,  showInFilter: true,  showInOnboarding: true,  canHost: true,  sortOrder: 8,  activityCount: 87  },
  { id: 'fitness',    name: 'Fitness',    emoji: '💪', enabled: true,  showInFilter: true,  showInOnboarding: true,  canHost: true,  sortOrder: 9,  activityCount: 74  },
  { id: 'golf',       name: 'Golf',       emoji: '⛳', enabled: true,  showInFilter: true,  showInOnboarding: true,  canHost: false, sortOrder: 10, activityCount: 41  },
  { id: 'squash',     name: 'Squash',     emoji: '🎱', enabled: true,  showInFilter: false, showInOnboarding: true,  canHost: true,  sortOrder: 11, activityCount: 29  },
  { id: 'yoga',       name: 'Yoga',       emoji: '🧘', enabled: true,  showInFilter: false, showInOnboarding: true,  canHost: false, sortOrder: 12, activityCount: 55  },
  { id: 'futsal',     name: 'Futsal',     emoji: '🥅', enabled: true,  showInFilter: false, showInOnboarding: false, canHost: true,  sortOrder: 13, activityCount: 278 },
  { id: 'cricket',    name: 'Cricket',    emoji: '🏏', enabled: false, showInFilter: false, showInOnboarding: false, canHost: false, sortOrder: 14, activityCount: 12  },
  { id: 'tabletennis',name: 'Table Tennis',emoji: '🏓',enabled: false, showInFilter: false, showInOnboarding: false, canHost: false, sortOrder: 15, activityCount: 8   },
];

const STORAGE_KEY = 'matchup_admin_sports';

export function loadSports(): SportConfig[] {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (raw) return JSON.parse(raw) as SportConfig[];
  } catch {
    // localStorage unavailable or corrupt — fall through to defaults
  }
  return DEFAULT_SPORTS;
}

export function saveSports(sports: SportConfig[]): void {
  localStorage.setItem(STORAGE_KEY, JSON.stringify(sports));
}
