import { describe, expect, it, vi, beforeEach } from 'vitest';
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';

const { useAnalyticsMock, downloadCsvMock } = vi.hoisted(() => ({
  useAnalyticsMock: vi.fn(),
  downloadCsvMock: vi.fn(),
}));
vi.mock('../../hooks/useAnalytics', () => ({ useAnalytics: useAnalyticsMock }));
vi.mock('../../context/ThemeContext', () => ({ useTheme: () => ({ theme: 'light', toggle: vi.fn() }) }));
vi.mock('../../utils/csvExport', () => ({ downloadCsv: downloadCsvMock }));

import { AnalyticsPage } from './AnalyticsPage';

function makeData(overrides = {}) {
  return {
    kpis: [{ label: 'Users', value: '10', change: '+1' }],
    weekly: [{ day: 'Mon', signups: 1, activities: 2, reports: 0 }],
    topSports: [{ sport: 'Futsal', activities: 5, pct: 100 }],
    retention: [{ label: 'D1', value: 50 }],
    health: [{ label: 'Uptime', value: 99, color: '#0b1f8a' }],
    ...overrides,
  };
}

describe('AnalyticsPage audit fixes', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('F1: Export button downloads analytics CSV', async () => {
    const data = makeData();
    useAnalyticsMock.mockReturnValue({ loading: false, error: null, data, range: '7d', setRange: vi.fn(), reload: vi.fn() });
    const user = userEvent.setup();
    render(<AnalyticsPage />);
    await user.click(screen.getByRole('button', { name: 'Export' }));
    expect(downloadCsvMock).toHaveBeenCalledTimes(1);
    expect(downloadCsvMock.mock.calls[0][0]).toEqual([
      expect.objectContaining({ Day: 'Mon', Signups: 1, Activities: 2 }),
    ]);
    expect(downloadCsvMock.mock.calls[0][1]).toBe('matchup-analytics-7d.csv');
  });

  it('F4: shows empty-state when retention and health are empty', () => {
    const data = makeData({ retention: [], health: [] });
    useAnalyticsMock.mockReturnValue({ loading: false, error: null, data, range: '7d', setRange: vi.fn(), reload: vi.fn() });
    render(<AnalyticsPage />);
    expect(screen.getAllByText('No data yet — events not collected')).toHaveLength(2);
  });
});
