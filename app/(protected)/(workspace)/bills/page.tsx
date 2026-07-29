import { approveBill, createBill, recordBillPayment } from "@/app/actions/accounting";
import { EmptyState } from "@/components/empty-state";
import { PageHeader } from "@/components/page-header";
import { formatMoney } from "@/lib/money";
import { requireOrganization } from "@/lib/organization";

export const metadata = { title: "Bills" };

export default async function BillsPage({
  searchParams,
}: {
  searchParams: Promise<{ error?: string; message?: string }>;
}) {
  const { supabase, organization } = await requireOrganization();
  const params = await searchParams;
  const today = new Date();
  const due = new Date(today);
  due.setDate(due.getDate() + 30);

  const [{ data: contacts }, { data: expenseAccounts }, { data: bills }, { data: bankAccounts }] = await Promise.all([
    supabase
      .from("contacts")
      .select("id, name")
      .eq("organization_id", organization.id)
      .in("contact_type", ["supplier", "both"])
      .order("name"),
    supabase
      .from("accounts")
      .select("id, code, name")
      .eq("organization_id", organization.id)
      .eq("type", "expense")
      .eq("is_active", true)
      .order("code"),
    supabase
      .from("bills")
      .select("id, bill_number, supplier_reference, bill_date, due_date, status, total, balance_due, contacts(name)")
      .eq("organization_id", organization.id)
      .order("bill_date", { ascending: false })
      .limit(100),
    supabase
      .from("bank_accounts")
      .select("id, name")
      .eq("organization_id", organization.id)
      .eq("is_active", true)
      .order("name"),
  ]);

  return (
    <>
      <PageHeader title="Bills" description="Capture supplier bills and post expenses and payables." />
      <div className="two-column">
        <section className="card">
          <div className="card-header"><h2>Supplier bills</h2></div>
          {bills?.length ? (
            <div className="table-wrap">
              <table>
                <thead><tr><th>Bill</th><th>Supplier</th><th>Date</th><th>Due</th><th>Status</th><th className="amount">Total</th><th className="amount">Balance</th><th /></tr></thead>
                <tbody>
                  {bills.map((bill) => {
                    const contact = Array.isArray(bill.contacts) ? bill.contacts[0] : bill.contacts;
                    return (
                      <tr key={bill.id}>
                        <td>{bill.bill_number}<div className="muted caption">{bill.supplier_reference ?? ""}</div></td>
                        <td>{contact?.name ?? "—"}</td>
                        <td>{bill.bill_date}</td>
                        <td>{bill.due_date}</td>
                        <td><span className={`badge ${bill.status}`}>{bill.status.replace("_", " ")}</span></td>
                        <td className="amount">{formatMoney(bill.total)}</td>
                        <td className="amount">{formatMoney(bill.balance_due)}</td>
                        <td>
                          {bill.status === "draft" ? (
                            <form action={approveBill}>
                              <input type="hidden" name="bill_id" value={bill.id} />
                              <button className="button secondary small" type="submit">Approve</button>
                            </form>
                          ) : null}
                        </td>
                      </tr>
                    );
                  })}
                </tbody>
              </table>
            </div>
          ) : <EmptyState title="No bills yet" description="Add a supplier and record your first bill." />}
        </section>

        <aside className="card">
          <div className="card-header"><h2>New bill</h2></div>
          <form action={createBill} className="form-stack">
            {params.error ? <div className="alert error">{params.error}</div> : null}
            {params.message ? <div className="alert success">{params.message}</div> : null}
            <div className="field">
              <label htmlFor="contact_id">Supplier</label>
              <select id="contact_id" name="contact_id" required>
                <option value="">Select supplier</option>
                {contacts?.map((contact) => <option key={contact.id} value={contact.id}>{contact.name}</option>)}
              </select>
            </div>
            <div className="form-grid">
              <div className="field"><label htmlFor="bill_date">Bill date</label><input id="bill_date" name="bill_date" type="date" defaultValue={today.toISOString().slice(0, 10)} required /></div>
              <div className="field"><label htmlFor="due_date">Due date</label><input id="due_date" name="due_date" type="date" defaultValue={due.toISOString().slice(0, 10)} required /></div>
            </div>
            <div className="field"><label htmlFor="supplier_reference">Supplier reference</label><input id="supplier_reference" name="supplier_reference" /></div>
            <div className="field"><label htmlFor="description">Line description</label><input id="description" name="description" placeholder="Cloud software subscription" required /></div>
            <div className="form-grid three">
              <div className="field"><label htmlFor="quantity">Qty</label><input id="quantity" name="quantity" type="number" min="0.01" step="0.01" defaultValue="1" required /></div>
              <div className="field"><label htmlFor="unit_price">Unit price</label><input id="unit_price" name="unit_price" type="number" min="0.01" step="0.01" required /></div>
              <div className="field"><label htmlFor="tax_rate">Tax %</label><input id="tax_rate" name="tax_rate" type="number" min="0" max="100" step="0.01" defaultValue="0" /></div>
            </div>
            <div className="field">
              <label htmlFor="expense_account_id">Expense account</label>
              <select id="expense_account_id" name="expense_account_id" required>
                <option value="">Select expense account</option>
                {expenseAccounts?.map((account) => <option key={account.id} value={account.id}>{account.code} · {account.name}</option>)}
              </select>
            </div>
            <div className="field"><label htmlFor="notes">Notes</label><textarea id="notes" name="notes" /></div>
            <button className="button" type="submit">Save draft bill</button>
          </form>
        </aside>
      </div>

      <section className="card">
        <div className="card-header"><h2>Record supplier payment</h2></div>
        <form action={recordBillPayment} className="form-grid three">
          <div className="field">
            <label htmlFor="payment_bill_id">Outstanding bill</label>
            <select id="payment_bill_id" name="bill_id" required>
              <option value="">Select bill</option>
              {bills?.filter((bill) => ["approved", "partially_paid", "overdue"].includes(bill.status)).map((bill) => (
                <option key={bill.id} value={bill.id}>{bill.bill_number} · {formatMoney(bill.balance_due)}</option>
              ))}
            </select>
          </div>
          <div className="field">
            <label htmlFor="payment_bank_account_id">Pay from</label>
            <select id="payment_bank_account_id" name="bank_account_id" required>
              <option value="">Select bank account</option>
              {bankAccounts?.map((account) => <option key={account.id} value={account.id}>{account.name}</option>)}
            </select>
          </div>
          <div className="field"><label htmlFor="payment_date">Payment date</label><input id="payment_date" name="payment_date" type="date" defaultValue={today.toISOString().slice(0, 10)} required /></div>
          <div className="field"><label htmlFor="payment_amount">Amount</label><input id="payment_amount" name="amount" type="number" min="0.01" step="0.01" required /></div>
          <div className="field"><label htmlFor="payment_reference">Reference</label><input id="payment_reference" name="reference" /></div>
          <div className="field" style={{ alignSelf: "end" }}><button className="button" type="submit">Record payment</button></div>
        </form>
      </section>
    </>
  );
}
