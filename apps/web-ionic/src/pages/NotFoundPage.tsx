import { Link } from "react-router-dom";

export function NotFoundPage() {
  return (
    <main className="login">
      <div className="card placeholder">
        <h1 className="section-title">Page not found</h1>
        <p className="muted">Nothing lives at this address.</p>
        <Link className="btn btn--primary" to="/home">
          Go home
        </Link>
      </div>
    </main>
  );
}
