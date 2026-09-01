import { createContext, useContext, useMemo, useRef } from "react";
import type { ReactNode } from "react";
import {
  IonContent,
  IonPage,
  IonRefresher,
  IonRefresherContent,
} from "@ionic/react";
import { useLocation } from "react-router-dom";
import { emitRefresh } from "../lib/refresh";
import { apiCache } from "../lib/useApi";

export type ScrollModel =
  | "FIT"
  | "COMPACT_OVERFLOW"
  | "FRAMED_SCROLL"
  | "FRAMED_EDITOR"
  | "DOCUMENT";

interface ScrollOwner {
  getY: () => number;
  scrollTo: (y: number, duration?: number) => void;
}

const ScrollOwnerContext = createContext<ScrollOwner>({
  getY: () => window.scrollY,
  scrollTo: (y) => window.scrollTo({ top: y }),
});

export function useScrollOwner(): ScrollOwner {
  return useContext(ScrollOwnerContext);
}

interface IonicRoutePageProps {
  model: ScrollModel;
  children: ReactNode;
  refreshable?: boolean;
  publicScreen?: boolean;
}

/**
 * One Ionic page = one intentional scroll owner. IonRouterOutlet keeps page
 * instances alive when that is useful, so tab and back navigation preserve
 * native scroll position without turning the document into a second scroller.
 */
export function IonicRoutePage({
  model,
  children,
  refreshable = true,
  publicScreen = false,
}: IonicRoutePageProps) {
  const contentRef = useRef<HTMLIonContentElement>(null);
  const scrollYRef = useRef(0);
  const location = useLocation();

  const scrollOwner = useMemo<ScrollOwner>(
    () => ({
      getY: () => scrollYRef.current,
      scrollTo: (y, duration = 0) => {
        scrollYRef.current = y;
        void contentRef.current?.scrollToPoint(0, y, duration);
      },
    }),
    [],
  );

  return (
    <IonPage className={publicScreen ? "route-page route-page--public" : "route-page"} data-scroll-model={model}>
      <IonContent
        ref={contentRef}
        className="route-content"
        data-scroll-owner
        fullscreen
        scrollEvents
        forceOverscroll
        onIonScroll={(event) => {
          scrollYRef.current = event.detail.scrollTop;
        }}
      >
        {refreshable && (
          <IonRefresher
            slot="fixed"
            pullFactor={0.72}
            pullMin={64}
            pullMax={112}
            onIonRefresh={(event) => {
              apiCache.clear();
              emitRefresh();
              window.setTimeout(() => void event.detail.complete(), 650);
            }}
          >
            <IonRefresherContent pullingText="Pull to refresh" refreshingSpinner="crescent" />
          </IonRefresher>
        )}
        <ScrollOwnerContext.Provider value={scrollOwner}>
          <div className="view" key={location.pathname}>
            {children}
          </div>
        </ScrollOwnerContext.Provider>
      </IonContent>
    </IonPage>
  );
}
