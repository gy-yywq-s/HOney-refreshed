import { useEffect } from "react";
import { Link } from "react-router-dom";

export function NotFoundPage() {
  useEffect(() => {
    document.title = "Not found · HOney";
  }, []);
  return (
    <main className="login">
      <div className="card placeholder">
        <h1 className="section-title">Page not found</h1>
        <p className="muted">Nothing is listed at this address.</p>
        <Link className="btn btn--primary" to="/home">
          Go home
        </Link>
      </div>
    </main>
  );
}
