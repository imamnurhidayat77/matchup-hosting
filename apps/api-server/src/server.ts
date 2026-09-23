import { createApp } from './app/app.js';
import { env } from './config/env.js';
import { checkFirestoreConnection } from './database/firebase.js';
import { firestoreAuthHint, isFirestoreAuthError } from './database/firestore-errors.js';
import { sweepExpiredActivities } from './modules/activities/activity-lifecycle.service.js';
import { sweepDueBroadcasts } from './modules/admin/broadcasts.service.js';

const app = createApp();

app.listen(env.PORT, () => {
    console.log(`API listening on port ${env.PORT}`);
});

// Fail-fast connectivity probe: an invalid/revoked service-account key
// otherwise surfaces as generic 500s on every route (UNAUTHENTICATED /
// ACCESS_TOKEN_EXPIRED). Log the actionable hint once at boot.
checkFirestoreConnection()
    .then(() => {
        console.log('[firebase] connectivity check ok');
    })
    .catch((error) => {
        if (isFirestoreAuthError(error)) {
            console.error(`[firebase] ${firestoreAuthHint()}`);
        } else {
            console.error('[firebase] connectivity check failed:', error);
        }
    });

// Broadcast-due sweeper — sends `scheduled` broadcasts whose
// `scheduledAt <= now` (flipping them to `sent`) every 60 seconds.
// Idempotent via the send guard, best-effort per broadcast, failures
// logged never thrown. NOTE: H-1 activity reminders are intentionally
// not here — they ride the per-join `activity_reminder` notification
// path (scoped to participants), not the admin broadcast fan-out.
const ONE_MINUTE_MS = 60 * 1000;
setInterval(() => {
    sweepDueBroadcasts()
        .then(({ sent }) => {
            if (sent > 0) {
                console.log(`[sweeper] sent ${sent} due broadcasts`);
            }
        })
        .catch((error) => {
            if (isFirestoreAuthError(error)) {
                console.error(`[sweeper] broadcast sweep failed: ${firestoreAuthHint()}`);
            } else {
                console.error('[sweeper] broadcast sweep failed:', error);
            }
        });
}, ONE_MINUTE_MS);

// Expiry sweeper — flips past-endTime `open` activities to
// `completed` (with review nudges) every 5 minutes. The read paths
// also trigger best-effort sweeps, so this interval is the steady
// driver, not the only one. Failures are logged, never thrown.
const FIVE_MINUTES_MS = 5 * 60 * 1000;
setInterval(() => {
    sweepExpiredActivities()
        .then(({ completed }) => {
            if (completed > 0) {
                console.log(`[sweeper] auto-completed ${completed} activities`);
            }
        })
        .catch((error) => {
            if (isFirestoreAuthError(error)) {
                console.error(`[sweeper] sweep failed: ${firestoreAuthHint()}`);
            } else {
                console.error('[sweeper] sweep failed:', error);
            }
        });
}, FIVE_MINUTES_MS);