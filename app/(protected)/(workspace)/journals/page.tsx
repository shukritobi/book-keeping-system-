import { createManualJournal, postJournal } from "@/app/actions/accounting";
import { EmptyState } from "@/components/empty-state";
import { PageHeader } from "@/components/page-header";
import { formatMoney } from "@/lib/money";
import { requireOrganization } from "@/lib/organization";

export const metadata = { title: "Journals" };

export default async function JournalsPage({
  searchParams,
}: {
  searchParams: Promise<{ error?: string; message?: string }>;
}) {
  const { supabase, organization } = await requireOrganization();
  const params = await searchParams;
  const today = new Date().toISOString().slice(0, 10);

  const [{ data: accounts }, { data: journals }] = await Promise.all([
    supabase
      .from("accounts")
      .select("id, code, name")
      .eq("organization_id", organization.id)
      .eq("is_active", true)
      .order("code"),
    supabase
      .from("journal_entries")
      .select("id, entry_number, entry_date, reference, description, status, source_type, total_debit")
      .eq("organization_id", organization.id)
      .order("entry_date", { ascending: false })
      .order("created_at", { ascending: false })
      .limit(100),
  ]);

  return (
    <>
      <PageHeader title="Journals" description="Balanced double-entry transactions. Posted entries are immutable." />
      <div className="two-column">
        <section className="card">
          <div className="card-header"><h2>Journal register</h2></div>
          {journals?.length ? (
            <div className="table-wrap">
              <table>
                <thead><tr><th>Number</th><th>Date</th><th>Description</th><th>Source</th><th>Status</th><th className="amount">Debit</th><th /></tr></thead>
                <tbody>
                  {journals.map((journal) => (
                    <tr key={journal.id}>
                      <td>{journal.entry_number}</td>
                      <td>{journal.entry_date}</td>
                      <td>{journal.description}<div className="muted caption">{journal.reference ?? ""}</div></td>
                      <td>{journal.source_type}</td>
                      <td><span className={`badge ${journal.status}`}>{journal.status}</span></td>
                      <td className="amount">{formatMoney(journal.total_debit)}</td>
                      <td>
                        {journal.status === "draft" ? (
                          <form action={postJournal}>
                            <input type="hidden" name="journal_entry_id" value={journal.id} />
                            <button className="button secondary small" type="submit">Post</button>
                          </form>
                        ) : null}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          ) : <EmptyState title="No journals yet" description="Create a balanced manual journal or issue an invoice." />}
        </section>

        <aside className="card">
          <div className="card-header"><h2>Manual journal</h2></div>
          <form action={createManualJournal} className="form-stack">
            {params.error ? <div className="alert error">{params.error}</div> : null}
            {params.message ? <div className="alert success">{params.message}</div> : null}
            <div className="form-grid">
              <div className="field"><label htmlFor="entry_date">Date</label><input id="entry_date" name="entry_date" type="date" defaultValue={today} required /></div>
              <div className="field"><label htmlFor="reference">Reference</label><input id="reference" name="reference" /></div>
            </div>
            <div className="field"><label htmlFor="description">Description</label><input id="description" name="description" required /></div>
            <div className="field">
              <label htmlFor="debit_account_id">Debit account</label>
              <select id="debit_account_id" name="debit_account_id" required>
                <option value="">Select account</option>
                {accounts?.map((account) => <option key={account.id} value={account.id}>{account.code} · {account.name}</option>)}
              </select>
            </div>
            <div className="field">
              <label htmlFor="credit_account_id">Credit account</label>
              <select id="credit_account_id" name="credit_account_id" required>
                <option value="">Select account</option>
                {accounts?.map((account) => <option key={account.id} value={account.id}>{account.code} · {account.name}</option>)}
              </select>
            </div>
            <div className="field"><label htmlFor="amount">Amount (MYR)</label><input id="amount" name="amount" type="number" step="0.01" min="0.01" required /></div>
            <label className="caption"><input type="checkbox" name="post_now" /> Post immediately</label>
            <button className="button" type="submit">Create journal</button>
          </form>
        </aside>
      </div>
    </>
  );
}
