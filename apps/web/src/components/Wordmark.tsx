// The HOney wordmark — the Infinite-colour pack (Gary 2026-09-04). Two
// artworks, not one inverted: the night surface has its own, so the coloured
// joints keep their hues instead of being hue-rotated into something else.

interface WordmarkProps {
  /** Rendered height in px (the artwork is 570x253). */
  height?: number;
}

export function WordmarkHOney({ height = 26 }: WordmarkProps) {
  const width = (height * 570) / 253;
  return (
    <span className="wordmark" style={{ height, width }} role="img" aria-label="HOney">
      <img className="wordmark__light" src="/wordmark.png" alt="" width={width} height={height} />
      <img className="wordmark__night" src="/wordmark-dark.png" alt="" width={width} height={height} />
    </span>
  );
}
