import { Component } from "react";
import type { ReactNode } from "react";

interface Props {
  children: ReactNode;
}

interface State {
  error: Error | null;
}

export class ErrorBoundary extends Component<Props, State> {
  override state: State = { error: null };

  static getDerivedStateFromError(error: Error): State {
    return { error };
  }

  override render() {
    if (this.state.error) {
      return (
        <main className="login">
          <div className="card login__card">
            <h1 className="section-title">Something broke</h1>
            <p className="muted">
              An unexpected error stopped this page from rendering. Reloading usually fixes it.
            </p>
            <p className="caption">{this.state.error.message}</p>
            <button className="btn btn--primary btn--block" onClick={() => window.location.reload()}>
              Reload
            </button>
          </div>
        </main>
      );
    }
    return this.props.children;
  }
}
