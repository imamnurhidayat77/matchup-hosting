export type BroadcastStatus = 'Sent' | 'Scheduled' | 'Draft';
export type BroadcastAudience = 'All Users' | 'Hosts Only' | 'Players Only' | 'Inactive Users';

export interface Broadcast {
  id: string;
  title: string;
  message: string;
  audience: BroadcastAudience;
  status: BroadcastStatus;
  sentAt?: string;
  scheduledAt?: string;
  recipients: number;
  openRate?: number;
}

export const DUMMY_BROADCASTS: Broadcast[] = [
  { id: 'b1', title: 'New Feature: Location Sharing in Chat',   message: 'You can now share your live location in group chats. Tap the + button to try it!',       audience: 'All Users',     status: 'Sent',      sentAt: 'Oct 20, 2026',   recipients: 12483, openRate: 68 },
  { id: 'b2', title: 'Weekend Tournaments — Sign Up Now',       message: 'Exclusive weekend basketball and futsal tournaments are now open. Limited spots!',         audience: 'Players Only',  status: 'Sent',      sentAt: 'Oct 15, 2026',   recipients: 9840,  openRate: 74 },
  { id: 'b3', title: 'Host Verification Program Launch',        message: 'Get verified as a trusted host and unlock premium features. Apply in your profile.',       audience: 'Hosts Only',    status: 'Scheduled', scheduledAt: 'Nov 1, 2026', recipients: 2640 },
  { id: 'b4', title: 'We miss you! Come back & play',          message: 'It\'s been a while! Your favourite sports are waiting. Join an activity this weekend.',    audience: 'Inactive Users',status: 'Scheduled', scheduledAt: 'Nov 5, 2026', recipients: 1820 },
  { id: 'b5', title: 'Platform Maintenance Notice',             message: 'Scheduled maintenance on Oct 30, 2:00–4:00 AM. Services may be briefly unavailable.',     audience: 'All Users',     status: 'Draft',      recipients: 0 },
];
