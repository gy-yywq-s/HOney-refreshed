// The HOney wordmark — Gary's chosen candidate (2026-09-01): grotesk "H",
// a large open circular O (gap at the upper right), serif "ney". Drawn as
// SVG over the loaded webfonts so it themes with currentColor.

interface WordmarkProps {
  /** Rendered height in px; the drawing scales as one unit. */
  height?: number;
}

export function WordmarkHOney({ height = 26 }: WordmarkProps) {
  return (
    <svg
      className="wordmark"
      viewBox="0 0 148 44"
      style={{ height, width: (height * 148) / 44 }}
      role="img"
      aria-label="HOney"
    >
      <text
        x="0"
        y="34"
        fontFamily="'Space Grotesk Variable', 'Space Grotesk', system-ui, sans-serif"
        fontWeight="600"
        fontSize="34"
        letterSpacing="-1"
      >
        H
      </text>
      {/* Open O: stroke leaves a ~35° gap, rotated to the upper right. */}
      <circle
        cx="42"
        cy="23"
        r="13.6"
        fill="none"
        stroke="currentColor"
        strokeWidth="5.4"
        strokeDasharray="77 100"
        transform="rotate(-28 42 23)"
      />
      <text
        x="60"
        y="34"
        fontFamily="'Fraunces Variable', Fraunces, Georgia, serif"
        fontWeight="520"
        fontSize="33"
      >
        ney
      </text>
    </svg>
  );
}
