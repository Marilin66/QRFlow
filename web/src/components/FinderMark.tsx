/**
 * FinderMark — le motif de repérage d'un QR code, signe visuel de QRFlow.
 */
export default function FinderMark({
  size = 32,
  className = '',
}: {
  size?: number;
  className?: string;
}) {
  return (
    <svg
      width={size}
      height={size}
      viewBox="0 0 48 48"
      fill="none"
      className={className}
      aria-hidden="true"
    >
      <g stroke="currentColor" strokeWidth="3.5">
        {/* Coin supérieur gauche : repérage complet */}
        <rect x="4" y="4" width="14" height="14" rx="2.5" />
        <rect x="8.5" y="8.5" width="5" height="5" rx="1" />
        {/* Coin supérieur droit */}
        <rect x="30" y="4" width="14" height="14" rx="2.5" />
        <rect x="34.5" y="8.5" width="5" height="5" rx="1" />
        {/* Coin inférieur gauche */}
        <rect x="4" y="30" width="14" height="14" rx="2.5" />
        <rect x="8.5" y="34.5" width="5" height="5" rx="1" />
      </g>
      {/* Données simulées */}
      <g fill="currentColor" opacity="0.55">
        <circle cx="27" cy="19" r="1.6" />
        <circle cx="31.5" cy="22.5" r="1.6" />
        <circle cx="25.5" cy="26" r="1.6" />
        <circle cx="29.5" cy="29.5" r="1.6" />
        <circle cx="21" cy="22" r="1.6" />
      </g>
    </svg>
  );
}
