import { useEffect } from "react";
import { Link } from "react-router-dom";

export function NotFoundPage() {
  useEffect(() => {
    document.title = "Page not found · HOney";
  }, []);
  return (
    <main className="login" id="main" tabIndex={-1}>
      <a className="skip-link" href="#not-found-home">
        Skip to content
      </a>
      <div className="card placeholder">
        <h1 className="section-title">Page not found</h1>
        <p className="muted">That page doesn’t exist.</p>
        <Link className="btn btn--primary" to="/home" id="not-found-home">
          Go home
        </Link>
      </div>
    </main>
  );
}
