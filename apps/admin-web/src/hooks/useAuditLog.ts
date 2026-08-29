import { useState } from 'react';
import { DUMMY_AUDIT_LOG } from '../data/auditLogDummy';
import type { AuditEntry, AuditCategory } from '../data/auditLogDummy';

export function useAuditLog() {
  const [entries] = useState<AuditEntry[]>(DUMMY_AUDIT_LOG);
  const [loading] = useState(false);
  const [error] = useState<string | null>(null);

  return { loading, error, entries };
}

export type { AuditCategory };
