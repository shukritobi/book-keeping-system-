import { createFiscalLock } from "@/app/actions/accounting";
import { PageHeader } from "@/components/page-header";
import { requireOrganization } from "@/lib/organization";

export const metadata = { title: "Settings" };

export default async function SettingsPage({
  searchParams,
}: {
  searchParams: Promise<{ error?: string; message?: string }>;
}) {
  const { supabase, organization, role } = await requireOrganization();
  const params = await searchParams;

  const [{ data: members }, { data: locks }] = await Promise.all([
    supabase
      .from("organization_members")
      .select("id, user_id, role, created_at")
      .eq("organization_id", organization.id)
      .order("created_at"),
    supabase
      .from("fiscal_locks")
      .select("id, lock_date, reason, created_at")
      .eq("organization_id", organization.id)
      .order("lock_date", { ascending: false }),
  ]);

  return (
    <>
      <PageHeader title="Company settings" description="Company identity, access roles, fiscal controls, and audit posture." />

      <div className="two-column">
        <div>
          <section className="card">
            <div className="card-header"><h2>Company profile</h2></div>
            <dl className="definition-list">
              <dt>Name</dt><dd>{organization.name}</dd>
              <dt>Workspace</dt><dd>{organization.slug}</dd>
              <dt>Base currency</dt><dd>{organization.base_currency}</dd>
              <dt>Fiscal year starts</dt><dd>Month {organization.fiscal_year_start}</dd>
              <dt>Your role</dt><dd><span className="badge">{role}</span></dd>
            </dl>
          </section>

          <section className="card">
            <div className="card-header"><h2>Members</h2><span className="muted caption">Invitation UI is planned next</span></div>
            <div className="table-wrap">
              <table>
                <thead><tr><th>User ID</th><th>Role</th><th>Joined</th></tr></thead>
                <tbody>
                  {members?.map((member) => (
                    <tr key={member.id}>
                      <td><span className="code">{member.user_id}</span></td>
                      <td><span className="badge">{member.role}</span></td>
                      <td>{new Date(member.created_at).toLocaleDateString("en-MY")}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </section>

          <section className="card">
            <div className="card-header"><h2>Fiscal locks</h2></div>
            <div className="table-wrap">
              <table>
                <thead><tr><th>Locked through</th><th>Reason</th><th>Created</th></tr></thead>
                <tbody>
                  {locks?.length ? locks.map((lock) => (
                    <tr key={lock.id}>
                      <td>{lock.lock_date}</td>
                      <td>{lock.reason ?? "—"}</td>
                      <td>{new Date(lock.created_at).toLocaleDateString("en-MY")}</td>
                    </tr>
                  )) : <tr><td colSpan={3}>No fiscal periods locked.</td></tr>}
                </tbody>
              </table>
            </div>
          </section>
        </div>

        <aside className="card">
          <div className="card-header"><h2>Lock a period</h2></div>
          <p className="muted caption">
            Owners and admins can prevent journals dated on or before this date from being created, edited, posted, or deleted.
          </p>
          <form action={createFiscalLock} className="form-stack">
            {params.error ? <div className="alert error">{params.error}</div> : null}
            {params.message ? <div className="alert success">{params.message}</div> : null}
            <div className="field"><label htmlFor="lock_date">Lock through</label><input id="lock_date" name="lock_date" type="date" required /></div>
            <div className="field"><label htmlFor="reason">Reason</label><textarea id="reason" name="reason" placeholder="Year-end accounts finalized" /></div>
            <button className="button danger" type="submit">Lock accounting period</button>
          </form>
        </aside>
      </div>
    </>
  );
}
