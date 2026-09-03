// A flow diagram for the explanation pages (Gary 2026-09-03: 必要的地方配
// 流程图): a vertical chain of steps, each labelled with WHERE it happens,
// joined by plain chevrons; a step may fan into a few equal options. Built
// from the app's field/card vocabulary — no diagram library, no colours
// beyond the tokens, and it reads top-to-bottom on a phone.

import { ChevronDownIcon } from "./icons";

export interface FlowStep {
  /** Where this happens — "This device", "HOney Core", "School portal"… */
  where?: string;
  title: string;
  note?: string;
  /** Equal alternatives at this step (rendered as a small grid). */
  options?: string[];
}

export function Flow({ label, steps }: { label: string; steps: FlowStep[] }) {
  return (
    <ol className="flow" aria-label={label}>
      {steps.map((s, i) => (
        <li key={i} className={s.options ? "flow__step flow__step--choice" : "flow__step"}>
          {i > 0 && (
            <span className="flow__arrow" aria-hidden="true">
              <ChevronDownIcon size={18} />
            </span>
          )}
          <span className="flow__box">
            {s.where && <span className="flow__where">{s.where}</span>}
            <span className="flow__title">{s.title}</span>
            {s.note && <span className="flow__note">{s.note}</span>}
            {s.options && (
              <span className="flow__options">
                {s.options.map((o) => (
                  <span key={o} className="flow__option">
                    {o}
                  </span>
                ))}
              </span>
            )}
          </span>
        </li>
      ))}
    </ol>
  );
}
