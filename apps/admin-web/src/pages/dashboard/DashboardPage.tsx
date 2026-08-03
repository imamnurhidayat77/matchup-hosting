import { Card, PageHeader } from '../../components/ui';
import { useApi } from '../../hooks/useApi';

interface HealthResponse {
  status: string;
  service: string;
}

export function DashboardPage() {
  const { data, loading, error } = useApi<HealthResponse>('/health');
  return (
    <>
      <PageHeader title="Dashboard" />
      <div className="grid grid-cols-1 gap-4 md:grid-cols-3">
        <Card>
          <h3 className="text-sm font-medium text-ink-500">API status</h3>
          <p className="mt-2 text-2xl font-semibold">
            {loading ? '…' : error ? 'Offline' : (data?.status ?? '—')}
          </p>
          <p className="mt-1 text-xs text-ink-500">{data?.service ?? 'matchup-api'}</p>
        </Card>
        <Card>
          <h3 className="text-sm font-medium text-ink-500">Members</h3>
          <p className="mt-2 text-2xl font-semibold">—</p>
          <p className="mt-1 text-xs text-ink-500">To be added in MVP</p>
        </Card>
        <Card>
          <h3 className="text-sm font-medium text-ink-500">Open reports</h3>
          <p className="mt-2 text-2xl font-semibold">—</p>
          <p className="mt-1 text-xs text-ink-500">To be added in MVP</p>
        </Card>
      </div>
    </>
  );
}