import { Building2 } from "lucide-react";
import { createOrganization } from "@/app/actions/organizations";
import { requireUser } from "@/lib/auth";

export const metadata = { title: "Set up company" };

export default async function OnboardingPage({
  searchParams,
}: {
  searchParams: Promise<{ error?: string }>;
}) {
  await requireUser();
  const params = await searchParams;

  return (
    <main className="onboarding">
      <section className="onboarding-card">
        <div className="brand-mark">
          <span className="brand-dot"><Building2 size={18} /></span>
          LedgerMY
        </div>
        <h1>Create your first company</h1>
        <p className="muted">
          We will create a Malaysian small-business chart of accounts and make you the owner.
        </p>

        <form action={createOrganization} className="form-stack" style={{ marginTop: 24 }}>
          {params.error ? <div className="alert error">{params.error}</div> : null}
          <div className="field">
            <label htmlFor="name">Company name</label>
            <input id="name" name="name" placeholder="Shukry Design Build" required />
          </div>
          <div className="field">
            <label htmlFor="slug">Workspace slug</label>
            <input
              id="slug"
              name="slug"
              placeholder="shukry-design-build"
              pattern="[a-z0-9]+(?:-[a-z0-9]+)*"
              required
            />
          </div>
          <button className="button" type="submit">Create company books</button>
        </form>
      </section>
    </main>
  );
}
