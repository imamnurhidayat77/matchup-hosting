/**
 * Single-admin moderation model — no escalation, no priority triage.
 * Two outcomes only: Resolved (action taken) or Dismissed (no action needed).
 */

export type ReportStatus = 'Pending' | 'Resolved' | 'Dismissed';
export type ReportCategory =
  | 'Harassment'
  | 'Spam'
  | 'Policy Breach'
  | 'Fraud'
  | 'Inappropriate Content'
  | 'Other';

export interface Report {
  id: string;
  reporter: string;
  reporterAvatarSeed: string;
  target: string;
  targetType: 'user' | 'activity';
  reason: string;
  category: ReportCategory;
  activityTitle: string;
  sport: string;
  status: ReportStatus;
  createdAt: string;
  /** Admin's internal note written when resolving or dismissing. */
  adminNote?: string;
  resolvedAt?: string;
}

export const DUMMY_REPORTS: Report[] = [
  {
    id: 'r1', reporter: 'Kevin D.', reporterAvatarSeed: 'kevin',
    target: 'Marcus L.', targetType: 'user',
    reason: 'Discriminatory title & bio chat',
    category: 'Harassment', activityTitle: 'Sunday Pick-Up Elite', sport: 'Basketball',
    status: 'Pending', createdAt: '2026-10-24T14:23:00Z',
  },
  {
    id: 'r2', reporter: 'Sarah P.', reporterAvatarSeed: 'sarah',
    target: 'Coach Dave', targetType: 'user',
    reason: 'Charged money offline (policy breach)',
    category: 'Policy Breach', activityTitle: 'Indoor Badminton Rally', sport: 'Badminton',
    status: 'Pending', createdAt: '2026-10-24T11:05:00Z',
  },
  {
    id: 'r3', reporter: 'Ali M.', reporterAvatarSeed: 'ali',
    target: 'Jordan T.', targetType: 'user',
    reason: 'No-show host — cancelled last minute',
    category: 'Other', activityTitle: 'Morning Beach Volleyball', sport: 'Volleyball',
    status: 'Pending', createdAt: '2026-10-23T09:45:00Z',
  },
  {
    id: 'r4', reporter: 'Priya N.', reporterAvatarSeed: 'priya',
    target: 'MU-1082', targetType: 'activity',
    reason: 'Fake activity — location does not exist',
    category: 'Fraud', activityTitle: 'Coastal Highway Group Ride', sport: 'Cycling',
    status: 'Pending', createdAt: '2026-10-22T16:00:00Z',
  },
  {
    id: 'r5', reporter: 'Tom W.', reporterAvatarSeed: 'tom',
    target: 'Nolan V.', targetType: 'user',
    reason: 'Spam messages in group chat',
    category: 'Spam', activityTitle: 'Wednesday Night Futsal', sport: 'Futsal',
    status: 'Resolved', createdAt: '2026-10-21T08:30:00Z',
    adminNote: 'Confirmed — user warned and chat history cleared.',
    resolvedAt: '2026-10-21T10:00:00Z',
  },
  {
    id: 'r6', reporter: 'Mei L.', reporterAvatarSeed: 'mei',
    target: 'MU-1230', targetType: 'activity',
    reason: 'Misleading sport category listed',
    category: 'Inappropriate Content', activityTitle: 'Indoor Badminton Rally', sport: 'Badminton',
    status: 'Dismissed', createdAt: '2026-10-20T12:00:00Z',
    adminNote: 'Category was correct — reporter misunderstood the sport type.',
    resolvedAt: '2026-10-20T13:30:00Z',
  },
];
