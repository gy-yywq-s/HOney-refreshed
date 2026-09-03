// The app's hierarchy, defined once (Gary, 2026-09-02: "kind of native
// app" — on any screen you know what is above it, and the top-left arrow
// takes you there). Five roots are the tabs; everything else hangs under
// one of them. AppLayout renders the back bar, marks the tab of the root
// ancestor, sets the document title and answers the edge swipe from this.

import { matchPath } from "react-router-dom";

export interface RouteNode {
  pattern: string;
  title: string;
  /** Parent route, or null for a root (a tab). */
  parent: string | null;
}

export interface Parent {
  to: string;
  title: string;
}

const NODES: RouteNode[] = [
  { pattern: "/home", title: "Home", parent: null },
  { pattern: "/timetable", title: "Timetable", parent: null },
  { pattern: "/history", title: "History", parent: "/timetable" },
  { pattern: "/history/lesson/:id", title: "Lesson", parent: "/history" },
  { pattern: "/notices", title: "From school", parent: "/home" },
  { pattern: "/notices/:id", title: "Notice", parent: "/notices" },
  { pattern: "/experiences", title: "Experiences", parent: null },
  { pattern: "/experiences/explore", title: "Explore", parent: "/experiences" },
  { pattern: "/experiences/mine", title: "Your notes & posts", parent: "/experiences" },
  { pattern: "/experiences/why", title: "Why this space exists", parent: "/experiences" },
  { pattern: "/experiences/compose", title: "Share an experience", parent: "/experiences" },
  { pattern: "/experiences/teacher/:id", title: "Teacher", parent: "/experiences" },
  { pattern: "/experiences/course/:id", title: "Course", parent: "/experiences" },
  { pattern: "/experiences/room/:id", title: "Room", parent: "/experiences" },
  { pattern: "/experiences/dish/:id", title: "Dish", parent: "/experiences" },
  { pattern: "/experiences/place/:id", title: "Place", parent: "/experiences" },
  { pattern: "/experiences/food/:id", title: "Food", parent: "/experiences" },
  { pattern: "/access", title: "Access", parent: null },
  { pattern: "/access/how", title: "How Access works", parent: "/access" },
  { pattern: "/settings", title: "Settings", parent: null },
  { pattern: "/settings/account", title: "Account", parent: "/settings" },
  { pattern: "/settings/connection", title: "School connection", parent: "/settings" },
  { pattern: "/settings/privacy", title: "How anonymity works", parent: "/settings" },
  { pattern: "/settings/appearance", title: "Appearance", parent: "/settings" },
  { pattern: "/settings/post-controls", title: "Post controls", parent: "/settings" },
  { pattern: "/settings/post-controls/how", title: "How post controls work", parent: "/settings/post-controls" },
  { pattern: "/settings/post-controls/recovery-words", title: "Recovery words", parent: "/settings/post-controls" },
  { pattern: "/settings/post-controls/pair", title: "Another device", parent: "/settings/post-controls" },
  { pattern: "/settings/post-controls/replace-root", title: "Replace control root", parent: "/settings/post-controls" },
  { pattern: "/dash", title: "Dash", parent: "/settings" },
];

export function nodeFor(pathname: string): RouteNode | null {
  return NODES.find((n) => matchPath({ path: n.pattern, end: true }, pathname) !== null) ?? null;
}

export function isKnownRoute(pathname: string): boolean {
  return nodeFor(pathname) !== null;
}

/** Title for the document; null for an unknown route. */
export function titleOf(pathname: string): string | null {
  return nodeFor(pathname)?.title ?? null;
}

/** The screen one level up, or null on a root. */
export function parentOf(pathname: string, search: string): Parent | null {
  const node = nodeFor(pathname);
  if (!node) return { to: "/home", title: "Home" };
  if (node.pattern === "/experiences/compose") {
    // The composer hangs under what it is about.
    const params = new URLSearchParams(search);
    const entityKey = params.get("entityKey");
    const lessonId = params.get("lessonId");
    if (entityKey) {
      const [kind, id] = entityKey.split(":");
      const to = kind && id ? `/experiences/${kind}/${id}` : null;
      const title = to ? titleOf(to) : null;
      if (to && title) return { to, title };
    }
    if (lessonId) return { to: `/history/lesson/${lessonId}`, title: "Lesson" };
  }
  if (!node.parent) return null;
  const parent = nodeFor(node.parent);
  return parent ? { to: node.parent, title: parent.title } : null;
}

/** The root (tab) this screen lives under; null for an unknown route. */
export function rootOf(pathname: string): string | null {
  let node = nodeFor(pathname);
  if (!node) return null;
  while (node.parent) {
    const up = nodeFor(node.parent);
    if (!up) break;
    node = up;
  }
  return node.pattern;
}
