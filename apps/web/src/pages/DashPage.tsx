import { Navigate } from "react-router-dom";
import { useAuth } from "../auth/AuthContext";

const SECTIONS = [
  {
    title: "Kill switches",
    body: "Pause Experiences posting or the portal sync for everyone at once.",
  },
  {
    title: "Moderation policy",
    body: "Review and bump the active moderation policy version.",
  },
  {
    title: "Moderation LLM key",
    body: "Set the production OpenRouter key and pick the moderation model.",
  },
] as const;

export function DashPage() {
  const { me } = useAuth();
  if (!me) return null;
  if (!me.isAdmin) return <Navigate to="/home" replace />;

  return (
    <div>
      <h1 className="page-title">Dash</h1>
      <p className="muted">
        Ops console. The controls below arrive with M3 — for now this page maps out what will live
        here.
      </p>
      <div className="stack" style={{ marginTop: "var(--space-lg)" }}>
        {SECTIONS.map((section) => (
          <section className="card" key={section.title}>
            <h2 className="section-title">{section.title}</h2>
            <p className="muted">{section.body}</p>
            <span className="caption">Coming with M3</span>
          </section>
        ))}
      </div>
    </div>
  );
}
