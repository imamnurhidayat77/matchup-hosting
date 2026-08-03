import { Button, Card, PageHeader, Textarea } from '../../components/ui';

export function BroadcastsPage() {
  return (
    <>
      <PageHeader title="Broadcasts" actions={<Button>Send broadcast</Button>} />
      <Card>
        <Textarea placeholder="Write a broadcast message to send to all members…" rows={6} />
        <p className="mt-2 text-xs text-ink-500">
          Broadcast delivery will be wired in the MVP phase.
        </p>
      </Card>
    </>
  );
}