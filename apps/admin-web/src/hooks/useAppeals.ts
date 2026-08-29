import { useState, useCallback } from 'react';
import { DUMMY_APPEALS } from '../data/appealsDummy';
import type { Appeal, AppealStatus } from '../data/appealsDummy';

export function useAppeals() {
  const [appeals, setAppeals] = useState<Appeal[]>(DUMMY_APPEALS);
  const [loading] = useState(false);
  const [error] = useState<string | null>(null);

  const handleDecision = useCallback(
    (id: string, decision: 'approve' | 'reject', response: string) => {
      const status: AppealStatus = decision === 'approve' ? 'Approved' : 'Rejected';
      setAppeals((prev) =>
        prev.map((a) =>
          a.id === id
            ? { ...a, status, adminResponse: response, resolvedAt: new Date().toISOString() }
            : a,
        ),
      );
    },
    [],
  );

  return { loading, error, appeals, handleDecision };
}
