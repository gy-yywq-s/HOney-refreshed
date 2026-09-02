// Scroll model: DOCUMENT — a short page inside the shell (nav + skip link
// come from AppLayout), so a wrong address is still one tap from anywhere.
import { useEffect } from "react";
import { Link } from "react-router-dom";

export function NotFoundPage() {
  useEffect(() => {
    document.title = "Page not found · HOney";
  }, []);
  return (
    <div className="stack">
      <h1 className="page-title">Page not found</h1>
      <p className="muted">That page doesn’t exist.</p>
      <div className="card-actions">
        <Link className="btn btn--primary" to="/home">
          Go home
        </Link>
      </div>
    </div>
  );
}
