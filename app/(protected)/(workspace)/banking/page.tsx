import { createBankAccount } from "@/app/actions/accounting";
import { EmptyState } from "@/components/empty-state";
import { PageHeader } from "@/components/page-header";
import { formatMoney } from "@/lib/money";
import { requireOrganization } from "@/lib/organization";

export const metadata = { title: "Banking" };

export default async function BankingPage({
  searchParams,
}: {
  searchParams: Promise<{ error?: string; message?: string }>;
}) {
  const { supabase, organization } = await requireOrganization();
  const params = await searchParams;

  const [{ data: ledgerAccounts }, { data: bankAccounts }, { data: bankTransactions }] = await Promise.all([
    supabase
      .from("accounts")
      .select("id, code, name")
      .eq("organization_id", organization.id)
      .eq("type", "asset")
      .eq("is_active", true)
      .order("code"),
    supabase
      .from("bank_accounts")
      .select("id, name, bank_name, masked_number, currency, opening_balance, account_id")
      .eq("organization_id", organization.id)
      .order("name"),
    supabase
      .from("bank_transactions")
      .select("id, transaction_date, description, reference, amount, status, bank_accounts(name)")
      .eq("organization_id", organization.id)
      .order("transaction_date", { ascending: false })
      .limit(100),
  ]);

  return (
    <>
      <PageHeader title="Banking" description="Map bank accounts to the ledger and prepare transactions for reconciliation." />
      <div className="two-column">
        <div>
          <section className="card">
            <div className="card-header"><h2>Bank accounts</h2></div>
            {bankAccounts?.length ? (
              <div className="table-wrap">
                <table>
                  <thead><tr><th>Name</th><th>Bank</th><th>Account</th><th>Currency</th><th className="amount">Opening balance</th></tr></thead>
                  <tbody>
                    {bankAccounts.map((account) => (
                      <tr key={account.id}>
                        <td>{account.name}</td>
                        <td>{account.bank_name ?? "—"}</td>
                        <td>{account.masked_number ?? "—"}</td>
                        <td>{account.currency}</td>
                        <td className="amount">{formatMoney(account.opening_balance)}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            ) : <EmptyState title="No bank accounts" description="Map a cash or bank ledger account first." />}
          </section>

          <section className="card">
            <div className="card-header"><h2>Imported transactions</h2><span className="muted caption">CSV/API import foundation</span></div>
            {bankTransactions?.length ? (
              <div className="table-wrap">
                <table>
                  <thead><tr><th>Date</th><th>Bank</th><th>Description</th><th>Reference</th><th>Status</th><th className="amount">Amount</th></tr></thead>
                  <tbody>
                    {bankTransactions.map((transaction) => {
                      const bank = Array.isArray(transaction.bank_accounts) ? transaction.bank_accounts[0] : transaction.bank_accounts;
                      return (
                        <tr key={transaction.id}>
                          <td>{transaction.transaction_date}</td>
                          <td>{bank?.name ?? "—"}</td>
                          <td>{transaction.description}</td>
                          <td>{transaction.reference ?? "—"}</td>
                          <td><span className={`badge ${transaction.status}`}>{transaction.status}</span></td>
                          <td className="amount">{formatMoney(transaction.amount)}</td>
                        </tr>
                      );
                    })}
                  </tbody>
                </table>
              </div>
            ) : <EmptyState title="No imported transactions" description="The schema supports deduplicated imports and reconciliation matching." />}
          </section>
        </div>

        <aside className="card">
          <div className="card-header"><h2>Add bank account</h2></div>
          <form action={createBankAccount} className="form-stack">
            {params.error ? <div className="alert error">{params.error}</div> : null}
            {params.message ? <div className="alert success">{params.message}</div> : null}
            <div className="field"><label htmlFor="name">Display name</label><input id="name" name="name" placeholder="Maybank Current" required /></div>
            <div className="field"><label htmlFor="bank_name">Bank name</label><input id="bank_name" name="bank_name" /></div>
            <div className="field"><label htmlFor="masked_number">Masked account no.</label><input id="masked_number" name="masked_number" placeholder="•••• 4321" /></div>
            <div className="field">
              <label htmlFor="account_id">Ledger account</label>
              <select id="account_id" name="account_id" required>
                <option value="">Select asset account</option>
                {ledgerAccounts?.map((account) => <option key={account.id} value={account.id}>{account.code} · {account.name}</option>)}
              </select>
            </div>
            <div className="field"><label htmlFor="opening_balance">Opening balance</label><input id="opening_balance" name="opening_balance" type="number" step="0.01" defaultValue="0" /></div>
            <button className="button" type="submit">Add bank account</button>
          </form>
        </aside>
      </div>
    </>
  );
}
