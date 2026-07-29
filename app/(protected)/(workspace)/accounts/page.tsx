import { createAccount } from "@/app/actions/accounting";
import { EmptyState } from "@/components/empty-state";
import { PageHeader } from "@/components/page-header";
import { ACCOUNT_TYPES } from "@/lib/constants";
import { requireOrganization } from "@/lib/organization";

export const metadata = { title: "Chart of accounts" };

export default async function AccountsPage({
  searchParams,
}: {
  searchParams: Promise<{ error?: string; message?: string }>;
}) {
  const { supabase, organization } = await requireOrganization();
  const params = await searchParams;
  const { data: accounts } = await supabase
    .from("accounts")
    .select("id, code, name, type, subtype, is_system, is_active")
    .eq("organization_id", organization.id)
    .order("code");

  return (
    <>
      <PageHeader
        title="Chart of accounts"
        description="The structure behind every transaction and financial report."
      />
      <div className="two-column">
        <section className="card">
          <div className="card-header"><h2>Accounts</h2></div>
          {accounts?.length ? (
            <div className="table-wrap">
              <table>
                <thead><tr><th>Code</th><th>Name</th><th>Type</th><th>Subtype</th><th>Status</th></tr></thead>
                <tbody>
                  {accounts.map((account) => (
                    <tr key={account.id}>
                      <td>{account.code}</td>
                      <td>{account.name}{account.is_system ? <span className="muted caption"> · system</span> : null}</td>
                      <td><span className="badge">{account.type}</span></td>
                      <td>{account.subtype ?? "—"}</td>
                      <td><span className={`badge ${account.is_active ? "active" : ""}`}>{account.is_active ? "active" : "inactive"}</span></td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          ) : <EmptyState title="No accounts" description="Your starter chart is created during onboarding." />}
        </section>

        <aside className="card">
          <div className="card-header"><h2>Add account</h2></div>
          <form action={createAccount} className="form-stack">
            {params.error ? <div className="alert error">{params.error}</div> : null}
            {params.message ? <div className="alert success">{params.message}</div> : null}
            <div className="form-grid">
              <div className="field">
                <label htmlFor="code">Code</label>
                <input id="code" name="code" placeholder="6100" required />
              </div>
              <div className="field">
                <label htmlFor="type">Type</label>
                <select id="type" name="type" required>
                  {ACCOUNT_TYPES.map((type) => <option key={type} value={type}>{type}</option>)}
                </select>
              </div>
            </div>
            <div className="field">
              <label htmlFor="name">Account name</label>
              <input id="name" name="name" placeholder="Software subscriptions" required />
            </div>
            <div className="field">
              <label htmlFor="subtype">Subtype</label>
              <input id="subtype" name="subtype" placeholder="Operating expense" />
            </div>
            <div className="field">
              <label htmlFor="description">Description</label>
              <textarea id="description" name="description" />
            </div>
            <button className="button" type="submit">Create account</button>
          </form>
        </aside>
      </div>
    </>
  );
}
