export type AuditAction =
  | 'report.resolve'
  | 'report.dismiss'
  | 'member.suspend'
  | 'member.activate'
  | 'member.remove'
  | 'activity.cancel'
  | 'activity.flag'
  | 'activity.remove'
  | 'appeal.approve'
  | 'appeal.reject'
  | 'broadcast.send'
  | 'broadcast.delete'
  | 'sport.add'
  | 'sport.disable'
  | 'sport.publish'
  | 'settings.update';

export type AuditCategory = 'Reports' | 'Members' | 'Activities' | 'Appeals' | 'Broadcasts' | 'Sports' | 'Settings';

export interface AuditEntry {
  id: string;
  action: AuditAction;
  category: AuditCategory;
  adminName: string;
  adminEmail: string;
  /** Human-readable description */
  description: string;
  /** Target entity name (user, activity, report id) */
  targetLabel: string;
  targetId?: string;
  metadata?: Record<string, string>;
  createdAt: string;
}

function entry(
  id: string, action: AuditAction, category: AuditCategory,
  description: string, targetLabel: string, createdAt: string,
  targetId?: string, metadata?: Record<string, string>,
): AuditEntry {
  return { id, action, category, adminName: 'Devon Lane', adminEmail: 'admin@matchup.app', description, targetLabel, targetId, metadata, createdAt };
}

export const DUMMY_AUDIT_LOG: AuditEntry[] = [
  entry('al01', 'report.resolve',   'Reports',    'Resolved report — user warned and chat cleared',     'Report r5 (Tom W. → Nolan V.)',      '2026-10-25T10:15:00Z', 'r5', { note: 'User warned and chat history cleared.' }),
  entry('al02', 'member.suspend',   'Members',    'Suspended member account',                           'Marcus Lee (m3)',                    '2026-10-25T09:50:00Z', 'm3', { reason: 'Discriminatory bio content' }),
  entry('al03', 'appeal.approve',   'Appeals',    'Approved appeal — activity record restored',         'Jordan Torres (ap3)',                '2026-10-24T09:00:00Z', 'ap3'),
  entry('al04', 'broadcast.send',   'Broadcasts', 'Sent broadcast to All Users',                        'New Feature: Location Sharing (b1)',  '2026-10-24T08:30:00Z', 'b1', { audience: 'All Users', recipients: '12483' }),
  entry('al05', 'report.dismiss',   'Reports',    'Dismissed report — false positive, category correct','Report r6 (Mei L. → MU-1230)',        '2026-10-24T07:00:00Z', 'r6', { note: 'Category was correct, reporter misunderstood.' }),
  entry('al06', 'activity.flag',    'Activities', 'Flagged activity for review',                        'Coastal Highway Group Ride (MU-1082)','2026-10-23T16:40:00Z', 'MU-1082'),
  entry('al07', 'appeal.reject',    'Appeals',    'Rejected appeal — third-party photo policy',         'Priya Nair (ap4)',                   '2026-10-23T11:00:00Z', 'ap4', { reason: 'Third party in photo without consent' }),
  entry('al08', 'member.activate',  'Members',    'Reactivated member account',                         'Gavin Reed (m6)',                    '2026-10-22T14:20:00Z', 'm6'),
  entry('al09', 'sport.publish',    'Sports',     'Published sports catalogue changes',                  '12 sports, 1 added (Pickleball)',    '2026-10-22T11:00:00Z', undefined, { added: 'Pickleball', total: '13' }),
  entry('al10', 'settings.update',  'Settings',   'Updated moderation settings',                        'Auto-flag threshold: 3 → 5',         '2026-10-22T10:30:00Z', undefined, { field: 'autoFlagThreshold', from: '3', to: '5' }),
  entry('al11', 'report.resolve',   'Reports',    'Resolved report — offline payment policy breach',    'Report r2 (Sarah P. → Coach Dave)',  '2026-10-21T13:00:00Z', 'r2', { note: 'User suspended pending appeal.' }),
  entry('al12', 'activity.cancel',  'Activities', 'Cancelled activity by admin',                        'Morning Beach Volleyball (MU-0940)', '2026-10-21T12:00:00Z', 'MU-0940', { reason: 'No-show host' }),
  entry('al13', 'broadcast.send',   'Broadcasts', 'Sent broadcast to Players Only',                     'Weekend Tournaments (b2)',           '2026-10-21T08:00:00Z', 'b2', { audience: 'Players Only', recipients: '9840' }),
  entry('al14', 'member.remove',    'Members',    'Permanently removed member account',                  'Inactive bot account (u99)',         '2026-10-20T16:00:00Z', 'u99', { reason: 'Confirmed spam bot' }),
  entry('al15', 'sport.disable',    'Sports',     'Disabled sport from discovery filter',               'Skydiving',                          '2026-10-20T09:00:00Z', undefined, { reason: 'No active activities in 90 days' }),
  entry('al16', 'settings.update',  'Settings',   'Enabled profanity filter',                           'profanityFilter: false → true',      '2026-10-19T11:00:00Z', undefined, { field: 'profanityFilter', from: 'false', to: 'true' }),
  entry('al17', 'appeal.approve',   'Appeals',    'Approved appeal — false positive flag removed',      'Hana Shiro (ap5)',                   '2026-10-19T08:30:00Z', 'ap5'),
  entry('al18', 'activity.remove',  'Activities', 'Removed activity permanently',                       'Fake Cycling Event (MU-1082)',       '2026-10-18T14:00:00Z', 'MU-1082', { reason: 'Confirmed fraudulent listing' }),
  entry('al19', 'report.resolve',   'Reports',    'Resolved report — account permanently removed',      'Report r4 (Priya N. → MU-1082)',     '2026-10-18T13:50:00Z', 'r4', { note: 'Activity was fraudulent — removed.' }),
  entry('al20', 'broadcast.delete', 'Broadcasts', 'Deleted draft broadcast',                            'Platform Maintenance Notice (b5)',   '2026-10-17T10:00:00Z', 'b5'),
];
