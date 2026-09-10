import { createApp } from './app/app.js';
import { env } from './config/env.js';
import { sweepExpiredActivities } from './modules/activities/activity-lifecycle.service.js';

const app = createApp();

app.listen(env.PORT, () => {
    console.log(`API listening on port ${env.PORT}`);
});

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
            console.error('[sweeper] sweep failed:', error);
        });
}, FIVE_MINUTES_MS);