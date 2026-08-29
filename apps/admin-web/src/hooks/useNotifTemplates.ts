import { useState, useCallback } from 'react';
import { DUMMY_NOTIF_TEMPLATES } from '../data/notifTemplatesDummy';
import type { NotifTemplate } from '../data/notifTemplatesDummy';

export function useNotifTemplates() {
  const [templates, setTemplates] = useState<NotifTemplate[]>(DUMMY_NOTIF_TEMPLATES);
  const [loading] = useState(false);
  const [error] = useState<string | null>(null);

  const handleUpdate = useCallback((id: string, patch: Partial<NotifTemplate>) => {
    setTemplates((prev) =>
      prev.map((t) =>
        t.id === id ? { ...t, ...patch, lastEditedAt: new Date().toISOString() } : t,
      ),
    );
  }, []);

  const handleToggle = useCallback((id: string) => {
    setTemplates((prev) =>
      prev.map((t) =>
        t.id === id ? { ...t, enabled: !t.enabled, lastEditedAt: new Date().toISOString() } : t,
      ),
    );
  }, []);

  return { loading, error, templates, handleUpdate, handleToggle };
}
