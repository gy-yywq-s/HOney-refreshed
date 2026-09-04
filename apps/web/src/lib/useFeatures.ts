// What the app shows, as Dash set it. One fetch per session, shared by every
// screen that has a switchable entry.

import { api } from "../api/client";
import type { FeatureFlags } from "../api/types";
import { useApi } from "./useApi";

const DEFAULTS: FeatureFlags = { lessonFeedback: false, schoolFeedback: true };

export function useFeatures(): FeatureFlags {
  const features = useApi(() => api.features(), [], "features");
  return features.data ?? DEFAULTS;
}
