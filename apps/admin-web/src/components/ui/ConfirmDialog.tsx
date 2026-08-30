/**
 * Lightweight confirm dialog — used for destructive actions like
 * suspend/remove member. No routing, pure overlay.
 */
export function ConfirmDialog({
  open,
  title,
  description,
  confirmLabel = 'Confirm',
  cancelLabel = 'Cancel',
  destructive = false,
  onConfirm,
  onCancel,
}: {
  open: boolean;
  title: string;
  description?: string;
  confirmLabel?: string;
  cancelLabel?: string;
  destructive?: boolean;
  onConfirm: () => void;
  onCancel: () => void;
}) {
  if (!open) return null;
  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-ink-900/50 dark:bg-black/60 px-4">
      <div className="w-full max-w-sm rounded-2xl bg-white dark:bg-ink-800 p-6 shadow-panel border border-ink-200 dark:border-ink-700">
        <h3 className="text-base font-bold text-ink-900 dark:text-ink-100">{title}</h3>
        {description && (
          <p className="mt-2 text-sm text-ink-500 dark:text-ink-400">{description}</p>
        )}
        <div className="mt-5 flex gap-2 justify-end">
          <button
            onClick={onCancel}
            className="btn-outline rounded-xl px-4 py-2 text-sm"
          >
            {cancelLabel}
          </button>
          <button
            onClick={onConfirm}
            className={`rounded-xl px-4 py-2 text-sm font-semibold text-white transition-colors ${
              destructive ? 'bg-danger-500 hover:bg-danger-600' : 'bg-brand-500 hover:bg-brand-600'
            }`}
          >
            {confirmLabel}
          </button>
        </div>
      </div>
    </div>
  );
}
