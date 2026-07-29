import { Landmark } from "lucide-react";

export default function AuthLayout({ children }: { children: React.ReactNode }) {
  return (
    <main className="auth-shell">
      <section className="auth-brand">
        <div className="brand-mark">
          <span className="brand-dot"><Landmark size={19} /></span>
          LedgerMY
        </div>
        <div>
          <h1>Books you can trust. Decisions you can make.</h1>
          <p>
            Secure double-entry bookkeeping, documents, invoicing, bills, banking,
            and reporting for Malaysian small businesses.
          </p>
        </div>
        <small>Built around least privilege, auditability, and private document access.</small>
      </section>
      <section className="auth-panel">{children}</section>
    </main>
  );
}
