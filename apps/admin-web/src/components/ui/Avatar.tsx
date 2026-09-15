interface AvatarProps {
  name: string;
  photoUrl?: string | null;
  seed?: string;
  className?: string;
}

function initials(name: string): string {
  const parts = name.trim().split(/\s+/).filter(Boolean);
  if (parts.length === 0) return '?';
  if (parts.length === 1) return parts[0].slice(0, 2).toUpperCase();
  return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
}

function bgFor(seed: string): string {
  let h = 0;
  for (let i = 0; i < seed.length; i++) h = (h * 31 + seed.charCodeAt(i)) % 360;
  return `hsl(${h} 45% 88%)`;
}

function fgFor(seed: string): string {
  let h = 0;
  for (let i = 0; i < seed.length; i++) h = (h * 31 + seed.charCodeAt(i)) % 360;
  return `hsl(${h} 55% 28%)`;
}

/**
 * Database-backed avatar: renders the user's photoUrl when present,
 * otherwise deterministic initials (no external placeholder service).
 */
export function Avatar({ name, photoUrl, seed, className = 'h-8 w-8 rounded-full' }: AvatarProps) {
  if (photoUrl) {
    return <img src={photoUrl} alt={name} className={`${className} object-cover`} loading="lazy" />;
  }
  const key = seed ?? name;
  return (
    <span
      aria-label={name}
      className={`${className} inline-flex shrink-0 items-center justify-center text-xs font-bold`}
      style={{ backgroundColor: bgFor(key), color: fgFor(key) }}
    >
      {initials(name)}
    </span>
  );
}
