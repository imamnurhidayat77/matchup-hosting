import { Badge, PageHeader, TableWrapper } from '../../components/ui';

export function MembersPage() {
  return (
    <>
      <PageHeader title="Members" />
      <TableWrapper>
        <table className="min-w-full divide-y divide-ink-200">
          <thead className="bg-ink-50">
            <tr>
              <th className="px-4 py-2 text-left text-xs font-semibold uppercase tracking-wide text-ink-500">
                Name
              </th>
              <th className="px-4 py-2 text-left text-xs font-semibold uppercase tracking-wide text-ink-500">
                Email
              </th>
              <th className="px-4 py-2 text-left text-xs font-semibold uppercase tracking-wide text-ink-500">
                Role
              </th>
              <th className="px-4 py-2 text-left text-xs font-semibold uppercase tracking-wide text-ink-500">
                Status
              </th>
            </tr>
          </thead>
          <tbody className="divide-y divide-ink-200 bg-white">
            <tr>
              <td colSpan={4} className="px-4 py-8 text-center text-sm text-ink-500">
                No members yet — list endpoint arrives in MVP phase.
              </td>
            </tr>
          </tbody>
        </table>
      </TableWrapper>
      <p className="mt-4 text-xs text-ink-500">
        Example badge tones: <Badge tone="success">active</Badge>{' '}
        <Badge tone="warning">pending</Badge> <Badge tone="danger">suspended</Badge>
      </p>
    </>
  );
}