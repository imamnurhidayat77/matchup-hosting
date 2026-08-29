export type AppealStatus = 'Pending' | 'Approved' | 'Rejected';
export type AppealType = 'Suspension' | 'Activity Removal' | 'Account Ban' | 'Content Removal';

export interface Appeal {
  id: string;
  userId: string;
  userName: string;
  userAvatarSeed: string;
  userEmail: string;
  type: AppealType;
  /** Original admin action that triggered this appeal */
  originalAction: string;
  /** User's appeal statement */
  statement: string;
  status: AppealStatus;
  createdAt: string;
  resolvedAt?: string;
  adminResponse?: string;
  /** ID of the related report/action for cross-linking */
  relatedId?: string;
}

const BASE = '2026-10';

export const DUMMY_APPEALS: Appeal[] = [
  {
    id: 'ap1',
    userId: 'm3',
    userName: 'Marcus Lee',
    userAvatarSeed: 'marcus',
    userEmail: 'marcus@example.com',
    type: 'Suspension',
    originalAction: 'Account suspended — discriminatory content in bio',
    statement: 'I understand the concern but the content in my bio was taken out of context. It was a sports quote referencing my training philosophy, not targeted at any individual. I have removed it and would appreciate having my account reinstated.',
    status: 'Pending',
    createdAt: `${BASE}-25T08:12:00Z`,
    relatedId: 'r1',
  },
  {
    id: 'ap2',
    userId: 'm8',
    userName: 'Coach Dave',
    userAvatarSeed: 'dave',
    userEmail: 'dave@example.com',
    type: 'Suspension',
    originalAction: 'Account suspended — offline payment collection',
    statement: 'The payment was for equipment rental, not an activity fee. I was upfront with all participants and no one complained. I have documentation of the agreement. Please review before taking further action.',
    status: 'Pending',
    createdAt: `${BASE}-24T15:30:00Z`,
    relatedId: 'r2',
  },
  {
    id: 'ap3',
    userId: 'u42',
    userName: 'Jordan Torres',
    userAvatarSeed: 'jordan',
    userEmail: 'jordan@example.com',
    type: 'Activity Removal',
    originalAction: 'Activity "Morning Beach Volleyball" removed — no-show host',
    statement: 'There was an emergency in my family that day. I tried to cancel through the app but it was not working. I notified participants through group chat. This was not negligent behaviour and I would like the activity history restored.',
    status: 'Approved',
    createdAt: `${BASE}-23T12:00:00Z`,
    resolvedAt: `${BASE}-24T09:00:00Z`,
    adminResponse: 'We reviewed the group chat logs and confirmed you notified participants. Activity record restored. Please use the in-app cancel button in future — the issue has been escalated to our tech team.',
    relatedId: 'r3',
  },
  {
    id: 'ap4',
    userId: 'u77',
    userName: 'Priya Nair',
    userAvatarSeed: 'priya2',
    userEmail: 'priya.n@example.com',
    type: 'Content Removal',
    originalAction: 'Profile photo removed — violates community guidelines',
    statement: 'My profile photo is a sports action shot from a professional event. I don\'t understand why it was flagged. Can you explain which guideline it violates?',
    status: 'Rejected',
    createdAt: `${BASE}-20T10:00:00Z`,
    resolvedAt: `${BASE}-21T11:00:00Z`,
    adminResponse: 'The photo was removed because it depicted a third party (other athlete) without visible consent indication. You are welcome to upload a photo where you are the sole subject.',
  },
  {
    id: 'ap5',
    userId: 'u91',
    userName: 'Hana Shiro',
    userAvatarSeed: 'hana',
    userEmail: 'hana@example.com',
    type: 'Activity Removal',
    originalAction: 'Activity "Indoor Badminton Rally" flagged for misleading category',
    statement: 'The sport category listed was correct — Badminton. The activity was flagged based on a misunderstanding by another user. I have hosted this event 12 times without issue.',
    status: 'Approved',
    createdAt: `${BASE}-19T16:00:00Z`,
    resolvedAt: `${BASE}-20T08:30:00Z`,
    adminResponse: 'Confirmed — flag was a false positive. Activity reinstated and reporter\'s report marked as dismissed.',
  },
];
