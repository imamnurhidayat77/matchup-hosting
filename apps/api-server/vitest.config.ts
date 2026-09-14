import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    // `npm run build` compiles src (including *.test.ts) into dist/.
    // Without this, vitest's default include pattern collects both the
    // fresh src tests AND the stale compiled dist copies — running every
    // suite twice and reporting phantom failures from outdated build
    // output. dist/ is gitignored build output, never a test source.
    exclude: ['node_modules', 'dist'],
  },
});
