import Link from "next/link";
import { login } from "@/app/actions/auth";

export const metadata = { title: "Sign in" };

export default async function LoginPage({
  searchParams,
}: {
  searchParams: Promise<{ error?: string; message?: string; next?: string }>;
}) {
  const params = await searchParams;

  return (
    <div className="auth-card">
      <div className="brand-mark">
        <span className="brand-dot">L</span>
        LedgerMY
      </div>
      <h2>Welcome back</h2>
      <p>Sign in to continue to your company books.</p>

      <form action={login} className="form-stack">
        {params.error ? <div className="alert error">{params.error}</div> : null}
        {params.message ? <div className="alert success">{params.message}</div> : null}
        <input type="hidden" name="next" value={params.next ?? "/dashboard"} />

        <div className="field">
          <label htmlFor="email">Email address</label>
          <input id="email" name="email" type="email" autoComplete="email" required />
        </div>

        <div className="field">
          <label htmlFor="password">Password</label>
          <input
            id="password"
            name="password"
            type="password"
            autoComplete="current-password"
            minLength={8}
            required
          />
        </div>

        <button className="button" type="submit">Sign in</button>
      </form>

      <p className="caption" style={{ marginTop: 20 }}>
        New here? <Link className="link" href="/signup">Create an account</Link>
      </p>
    </div>
  );
}
