import { afterEach } from 'vitest';
import { cleanup } from '@testing-library/react';
import '@testing-library/jest-dom/vitest';

// `globals: false` in vite.config.ts means Testing Library's automatic
// afterEach cleanup (which relies on detecting a global `afterEach`)
// never registers itself — wire it up explicitly instead.
afterEach(() => {
  cleanup();
});
