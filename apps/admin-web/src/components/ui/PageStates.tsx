/** Reusable loading skeleton + error state shared by all pages. */

export function Skeleton({ className = '' }: { className?: string }) {
  return <div className={`animate-pulse rounded-lg bg-ink-200 ${className}`} />;
}

export function PageSkeleton({ rows = 5 }: { rows?: number }) {
  return (
    <div className="page-container space-y-5">
      <div className="space-y-2">
        <Skeleton className="h-7 w-48" />
        <Skeleton className="h-4 w-80 max-w-full" />
      </div>
      <div className="grid grid-cols-2 gap-3 sm:grid-cols-4">
        {Array.from({ length: 4 }).map((_, i) => <Skeleton key={i} className="h-24" />)}
      </div>
      <Skeleton className="h-10 w-full" />
      {Array.from({ length: rows }).map((_, i) => <Skeleton key={i} className="h-14 w-full" />)}
    </div>
  );
}

export function PageError({ message, onRetry }: { message: string; onRetry: () => void }) {
  return (
    <div className="page-container flex flex-col items-center justify-center gap-4 py-24">
      <p className="text-sm text-danger-500">Failed to load: {message}</p>
      <button onClick={onRetry} className="btn-primary rounded-xl px-4 py-2 text-sm">
        Retry
      </button>
    </div>
  );
}
