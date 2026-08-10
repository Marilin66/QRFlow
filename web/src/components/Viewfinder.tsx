/**
 * Viewfinder — cadre de visée avec coins de repérage et ligne de scan.
 */
export default function Viewfinder({
  active = false,
  children,
  className = '',
}: {
  /** Affiche la ligne de scan animée. */
  active?: boolean;
  children?: React.ReactNode;
  className?: string;
}) {
  return (
    <div className={`relative ${className}`}>
      <span aria-hidden="true" className="corner corner-tl" />
      <span aria-hidden="true" className="corner corner-tr" />
      <span aria-hidden="true" className="corner corner-bl" />
      <span aria-hidden="true" className="corner corner-br" />
      {active && <span aria-hidden="true" className="scanline" />}
      {children}
    </div>
  );
}
