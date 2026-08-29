export type TemplateCategory = 'Activity' | 'Account' | 'Moderation' | 'Engagement';
export type TemplateTrigger =
  | 'activity.joined'
  | 'activity.cancelled'
  | 'activity.reminder'
  | 'activity.full'
  | 'activity.starting_soon'
  | 'account.suspended'
  | 'account.reactivated'
  | 'account.welcome'
  | 'moderation.report_resolved'
  | 'moderation.appeal_approved'
  | 'moderation.appeal_rejected'
  | 'engagement.inactive'
  | 'engagement.new_activity_nearby';

export interface NotifTemplate {
  id: string;
  trigger: TemplateTrigger;
  category: TemplateCategory;
  name: string;
  /** Short description of when this fires */
  description: string;
  /** Notification title — supports {{variables}} */
  title: string;
  /** Notification body — supports {{variables}} */
  body: string;
  /** Available template variables */
  variables: string[];
  enabled: boolean;
  lastEditedAt: string;
}

export const DUMMY_NOTIF_TEMPLATES: NotifTemplate[] = [
  {
    id: 'nt1', trigger: 'activity.joined', category: 'Activity',
    name: 'Activity Joined',
    description: 'Sent to the host when a new participant joins their activity',
    title: '{{participantName}} joined your activity!',
    body: 'Great news — {{participantName}} has joined "{{activityName}}". You now have {{participantCount}}/{{capacity}} spots filled.',
    variables: ['participantName', 'activityName', 'participantCount', 'capacity'],
    enabled: true, lastEditedAt: '2026-10-15T09:00:00Z',
  },
  {
    id: 'nt2', trigger: 'activity.cancelled', category: 'Activity',
    name: 'Activity Cancelled',
    description: 'Sent to all participants when a host cancels an activity',
    title: '"{{activityName}}" has been cancelled',
    body: 'Unfortunately, "{{activityName}}" scheduled for {{activityDate}} has been cancelled by the host. Any paid fees will be refunded within 3–5 business days.',
    variables: ['activityName', 'activityDate', 'hostName'],
    enabled: true, lastEditedAt: '2026-10-10T14:00:00Z',
  },
  {
    id: 'nt3', trigger: 'activity.reminder', category: 'Activity',
    name: 'Activity Reminder (24h)',
    description: 'Reminder sent 24 hours before activity starts',
    title: 'Reminder: {{activityName}} is tomorrow!',
    body: 'Just a reminder that "{{activityName}}" starts tomorrow at {{activityTime}} at {{location}}. See you there!',
    variables: ['activityName', 'activityTime', 'location', 'hostName'],
    enabled: true, lastEditedAt: '2026-09-28T11:00:00Z',
  },
  {
    id: 'nt4', trigger: 'activity.full', category: 'Activity',
    name: 'Activity Now Full',
    description: 'Sent to host when their activity reaches capacity',
    title: 'Your activity is full!',
    body: '"{{activityName}}" has reached its capacity of {{capacity}} participants. The activity is now closed to new joiners.',
    variables: ['activityName', 'capacity'],
    enabled: true, lastEditedAt: '2026-10-01T08:00:00Z',
  },
  {
    id: 'nt5', trigger: 'activity.starting_soon', category: 'Activity',
    name: 'Activity Starting Soon (1h)',
    description: 'Sent to participants 1 hour before activity starts',
    title: '{{activityName}} starts in 1 hour',
    body: 'Head over to {{location}} — "{{activityName}}" starts in about 1 hour. Don\'t be late!',
    variables: ['activityName', 'location', 'activityTime'],
    enabled: false, lastEditedAt: '2026-09-20T10:00:00Z',
  },
  {
    id: 'nt6', trigger: 'account.suspended', category: 'Account',
    name: 'Account Suspended',
    description: 'Sent to user when their account is suspended by admin',
    title: 'Your MatchUp account has been suspended',
    body: 'Your account has been suspended due to a violation of our community guidelines: {{reason}}. You may submit an appeal through the app. If you believe this is a mistake, please contact {{supportEmail}}.',
    variables: ['reason', 'supportEmail', 'appealDeadline'],
    enabled: true, lastEditedAt: '2026-10-12T16:00:00Z',
  },
  {
    id: 'nt7', trigger: 'account.reactivated', category: 'Account',
    name: 'Account Reactivated',
    description: 'Sent when a suspended account is reinstated',
    title: 'Your account has been reinstated',
    body: 'Good news — your MatchUp account has been reactivated. You can now log in and join activities again. Welcome back!',
    variables: [],
    enabled: true, lastEditedAt: '2026-10-05T09:00:00Z',
  },
  {
    id: 'nt8', trigger: 'account.welcome', category: 'Account',
    name: 'Welcome Message',
    description: 'First notification sent after account creation',
    title: 'Welcome to MatchUp, {{userName}}!',
    body: 'You\'re all set! Start by browsing activities near you or create your own. Your first activity is just a tap away.',
    variables: ['userName'],
    enabled: true, lastEditedAt: '2026-08-01T00:00:00Z',
  },
  {
    id: 'nt9', trigger: 'moderation.report_resolved', category: 'Moderation',
    name: 'Report Resolved (to reporter)',
    description: 'Sent to the user who filed a report when it is resolved',
    title: 'Your report has been reviewed',
    body: 'Thank you for helping keep MatchUp safe. Your report has been reviewed and action has been taken in accordance with our community guidelines.',
    variables: [],
    enabled: true, lastEditedAt: '2026-10-08T13:00:00Z',
  },
  {
    id: 'nt10', trigger: 'moderation.appeal_approved', category: 'Moderation',
    name: 'Appeal Approved',
    description: 'Sent when an admin approves a user\'s appeal',
    title: 'Your appeal has been approved',
    body: 'We have reviewed your appeal and decided to reverse the previous action on your account. {{adminNote}} Thank you for your patience.',
    variables: ['adminNote'],
    enabled: true, lastEditedAt: '2026-10-14T10:00:00Z',
  },
  {
    id: 'nt11', trigger: 'moderation.appeal_rejected', category: 'Moderation',
    name: 'Appeal Rejected',
    description: 'Sent when an admin rejects a user\'s appeal',
    title: 'Your appeal has been reviewed',
    body: 'After careful review, we were unable to approve your appeal. {{adminNote}} If you have new information, please contact {{supportEmail}}.',
    variables: ['adminNote', 'supportEmail'],
    enabled: true, lastEditedAt: '2026-10-14T10:05:00Z',
  },
  {
    id: 'nt12', trigger: 'engagement.inactive', category: 'Engagement',
    name: 'Re-engagement (Inactive User)',
    description: 'Sent to users who haven\'t opened the app in 30+ days',
    title: 'We miss you on MatchUp!',
    body: 'It\'s been a while since you joined an activity. There are {{nearbyCount}} activities happening near you this week — come back and play!',
    variables: ['nearbyCount', 'userName'],
    enabled: false, lastEditedAt: '2026-09-15T08:00:00Z',
  },
  {
    id: 'nt13', trigger: 'engagement.new_activity_nearby', category: 'Engagement',
    name: 'New Activity Nearby',
    description: 'Sent when a new activity is created matching user\'s preferred sports',
    title: 'New {{sport}} activity near you',
    body: '"{{activityName}}" is happening {{distanceKm}}km from you on {{activityDate}}. Only {{spotsLeft}} spots left — join now!',
    variables: ['sport', 'activityName', 'distanceKm', 'activityDate', 'spotsLeft'],
    enabled: true, lastEditedAt: '2026-10-02T12:00:00Z',
  },
];
