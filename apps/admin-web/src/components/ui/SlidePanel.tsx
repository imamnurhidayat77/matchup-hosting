import type { ReactNode } from 'react';

export function SlidePanel({
  open,
  onClose,
  title,
  subtitle,
  children,
  width = 480,
}: {
  open: boolean;
  onClose: () => void;
  title: string;
  subtitle?: string;
  children: ReactNode;
  width?: number;
}) {
  if (!open) return null;

  return (
    <>
      {/* Scrim */}
      <div
        className="fixed inset-0 z-40 bg-ink-900/30 backdrop-blur-[1px] transition-opacity"
        onClick={onClose}
        aria-hidden
      />

      {/* Panel */}
      <div
        className="fixed inset-y-0 right-0 z-50 flex flex-col bg-white shadow-[−8px_0_32px_rgba(0,0,0,0.12)]"
        style={{ width: Math.min(width, typeof window !== 'undefined' ? window.innerWidth : width) }}
        role="dialog"
        aria-label={title}
      >
        {/* Header */}
        <div className="flex shrink-0 items-center justify-between border-b border-ink-200 bg-white px-6 py-4">
          <div className="min-w-0">
            <h2 className="truncate text-sm font-bold text-ink-900">{title}</h2>
            {subtitle && <p className="mt-0.5 truncate text-xs text-ink-400">{subtitle}</p>}
          </div>
          <button
            onClick={onClose}
            className="ml-4 flex h-8 w-8 shrink-0 items-center justify-center rounded-lg text-ink-400 hover:bg-ink-100 hover:text-ink-700 transition-colors"
            aria-label="Close"
          >
            <svg width="14" height="14" viewBox="0 0 14 14" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round">
              <path d="M2 2l10 10M12 2L2 12" />
            </svg>
          </button>
        </div>

        {/* Body */}
        <div className="flex-1 overflow-y-auto px-6 py-5">
          {children}
        </div>
      </div>
    </>
  );
}
