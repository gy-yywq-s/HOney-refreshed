// The app's primary navigation, defined once. Desktop renders DESKTOP_TABS in
// the top nav; at <=640px the shell switches to the iOS-style bottom tab bar
// (MOBILE_TABS), where Settings — desktop's user-menu item — becomes the
// fourth tab. Icons are simple SF-Symbol-like line glyphs drawn inline.

import type { ReactNode } from "react";

export interface NavTab {
  to: string;
  label: string;
}

export interface MobileNavTab extends NavTab {
  icon: ReactNode;
}

export const DESKTOP_TABS: NavTab[] = [
  { to: "/home", label: "Home" },
  { to: "/experiences", label: "Experiences" },
  { to: "/timetable", label: "Timetable" },
];

function Icon({ children }: { children: ReactNode }) {
  return (
    <svg
      className="tabbar__icon"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="1.7"
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden="true"
    >
      {children}
    </svg>
  );
}

/* house */
const homeIcon = (
  <Icon>
    <path d="M3.5 10.5 12 3.5l8.5 7" />
    <path d="M5.5 9v10.5a1 1 0 0 0 1 1h11a1 1 0 0 0 1-1V9" />
    <path d="M9.75 20.5v-6h4.5v6" />
  </Icon>
);

/* speech bubble (experiences are shared voices) */
const experiencesIcon = (
  <Icon>
    <path d="M20.5 11.2c0 3.98-3.8 7.2-8.5 7.2-1.02 0-2-.15-2.9-.43L4.5 19.5l1.3-3.32c-1.42-1.27-2.3-3-2.3-4.98C3.5 7.22 7.3 4 12 4s8.5 3.22 8.5 7.2Z" />
  </Icon>
);

/* calendar */
const timetableIcon = (
  <Icon>
    <rect x="3.5" y="5" width="17" height="15.5" rx="2" />
    <path d="M3.5 9.5h17" />
    <path d="M8 2.75V6M16 2.75V6" />
  </Icon>
);

/* gear */
const settingsIcon = (
  <Icon>
    <circle cx="12" cy="12" r="3.1" />
    <path d="M12 2.8v2.6M12 18.6v2.6M21.2 12h-2.6M5.4 12H2.8M18.5 5.5l-1.84 1.84M7.34 16.66 5.5 18.5M18.5 18.5l-1.84-1.84M7.34 7.34 5.5 5.5" />
  </Icon>
);

export const MOBILE_TABS: MobileNavTab[] = [
  { to: "/home", label: "Home", icon: homeIcon },
  { to: "/experiences", label: "Experiences", icon: experiencesIcon },
  { to: "/timetable", label: "Timetable", icon: timetableIcon },
  { to: "/settings", label: "Settings", icon: settingsIcon },
];
