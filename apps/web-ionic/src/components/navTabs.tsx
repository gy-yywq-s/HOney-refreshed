import {
  calendarOutline,
  chatbubbleEllipsesOutline,
  homeOutline,
  settingsOutline,
} from "ionicons/icons";

export interface NavTab {
  to: string;
  label: string;
}

export interface MobileNavTab extends NavTab {
  icon: string;
}

export const DESKTOP_TABS: NavTab[] = [
  { to: "/home", label: "Home" },
  { to: "/experiences", label: "Experiences" },
  { to: "/timetable", label: "Timetable" },
];

export const MOBILE_TABS: MobileNavTab[] = [
  { to: "/home", label: "Home", icon: homeOutline },
  { to: "/experiences", label: "Experiences", icon: chatbubbleEllipsesOutline },
  { to: "/timetable", label: "Timetable", icon: calendarOutline },
  { to: "/settings", label: "Settings", icon: settingsOutline },
];
