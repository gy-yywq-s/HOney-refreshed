// App-level refresh bus. The shell owns the viewport (body scroll is
// locked, §16.14), which removed the browser's native pull-to-refresh —
// so the app provides its own: PullToRefresh emits this event, and every
// data owner (useApi, useFeedController) re-fetches in place.

export const REFRESH_EVENT = "honey:refresh";

export function emitRefresh(): void {
  window.dispatchEvent(new Event(REFRESH_EVENT));
}
