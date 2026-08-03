import { Button, Card, Input, PageHeader } from '../../components/ui';

export function LoginPage() {
  return (
    <>
      <PageHeader title="Sign in" />
      <Card className="max-w-sm">
        <form className="space-y-4">
          <div>
            <label className="mb-1 block text-sm font-medium text-ink-700">Email</label>
            <Input type="email" placeholder="admin@matchup.app" />
          </div>
          <div>
            <label className="mb-1 block text-sm font-medium text-ink-700">Password</label>
            <Input type="password" placeholder="••••••••" />
          </div>
          <Button type="submit" className="w-full">
            Sign in
          </Button>
          <p className="text-xs text-ink-500">
            Auth wiring will be added in the MVP phase.
          </p>
        </form>
      </Card>
    </>
  );
}