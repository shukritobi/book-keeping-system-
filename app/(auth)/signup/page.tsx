import Link from "next/link";
import { signup } from "@/app/actions/auth";

export const metadata = { title: "Create account" };

export default async function SignupPage({
  searchParams,
}: {
  searchParams: Promise<{ error?: string; message?: string }>;
}) {
  const params = await searchParams;

  return (
    <div className="auth-card">
      <div className="brand-mark">
        <span className="brand-dot">L</span>
        LedgerMY
      </div>
      <h2>Create your account</h2>
      <p>Your company data will be isolated from every other organization.</p>

      <form action={signup} className="form-stack">
        {params.error ? <div className="alert error">{params.error}</div> : null}
        {params.message ? <div className="alert success">{params.message}</div> : null}

        <div className="field">
          <label htmlFor="name">Full name</label>
          <input id="name" name="name" autoComplete="name" minLength={2} required />
        </div>

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
            autoComplete="new-password"
            minLength={8}
            required
          />
        </div>

        <button className="button" type="submit">Create secure account</button>
      </form>

      <p className="caption" style={{ marginTop: 20 }}>
        Already have an account? <Link className="link" href="/login">Sign in</Link>
      </p>
    </div>
  );
}
