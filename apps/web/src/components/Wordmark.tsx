// The HOney wordmark — cropped directly from Gary's chosen artwork
// (bottom-left candidate, 2026-09-01). PNG with alpha, solid ink glyphs;
// the night surface inverts it via CSS.

interface WordmarkProps {
  /** Rendered height in px (the PNG is 570x191). */
  height?: number;
}

export function WordmarkHOney({ height = 26 }: WordmarkProps) {
  return (
    <img
      className="wordmark"
      src="/wordmark.png"
      alt="HOney"
      style={{ height, width: (height * 570) / 191 }}
    />
  );
}
