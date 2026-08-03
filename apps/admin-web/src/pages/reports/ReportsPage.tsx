import { Card, PageHeader } from '../../components/ui';

export function ReportsPage() {
  return (
    <>
      <PageHeader title="Reports" />
      <Card>
        <p className="text-sm text-ink-500">
          Moderation queue will be added during the MVP phase.
        </p>
      </Card>
    </>
  );
}