import { createInvoice, issueInvoice, recordInvoicePayment } from "@/app/actions/accounting";
import { EmptyState } from "@/components/empty-state";
import { PageHeader } from "@/components/page-header";
import { formatMoney } from "@/lib/money";
import { requireOrganization } from "@/lib/organization";

export const metadata = { title: "Invoices" };

export default async function InvoicesPage({
  searchParams,
}: {
  searchParams: Promise<{ error?: string; message?: string }>;
}) {
  const { supabase, organization } = await requireOrganization();
  const params = await searchParams;
  const today = new Date();
  const due = new Date(today);
  due.setDate(due.getDate() + 30);

  const [{ data: contacts }, { data: revenueAccounts }, { data: invoices }, { data: bankAccounts }] = await Promise.all([
    supabase
      .from("contacts")
      .select("id, name")
      .eq("organization_id", organization.id)
      .in("contact_type", ["customer", "both"])
      .order("name"),
    supabase
      .from("accounts")
      .select("id, code, name")
      .eq("organization_id", organization.id)
      .eq("type", "income")
      .eq("is_active", true)
      .order("code"),
    supabase
      .from("invoices")
      .select("id, invoice_number, issue_date, due_date, status, total, balance_due, contacts(name)")
      .eq("organization_id", organization.id)
      .order("issue_date", { ascending: false })
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
      <PageHeader title="Invoices" description="Create customer invoices and post receivables into the ledger." />
      <div className="two-column">
        <section className="card">
          <div className="card-header"><h2>Sales invoices</h2></div>
          {invoices?.length ? (
            <div className="table-wrap">
              <table>
                <thead><tr><th>Invoice</th><th>Customer</th><th>Issued</th><th>Due</th><th>Status</th><th className="amount">Total</th><th className="amount">Balance</th><th /></tr></thead>
                <tbody>
                  {invoices.map((invoice) => {
                    const contact = Array.isArray(invoice.contacts) ? invoice.contacts[0] : invoice.contacts;
                    return (
                      <tr key={invoice.id}>
                        <td>{invoice.invoice_number}</td>
                        <td>{contact?.name ?? "—"}</td>
                        <td>{invoice.issue_date}</td>
                        <td>{invoice.due_date}</td>
                        <td><span className={`badge ${invoice.status}`}>{invoice.status.replace("_", " ")}</span></td>
                        <td className="amount">{formatMoney(invoice.total)}</td>
                        <td className="amount">{formatMoney(invoice.balance_due)}</td>
                        <td>
                          {invoice.status === "draft" ? (
                            <form action={issueInvoice}>
                              <input type="hidden" name="invoice_id" value={invoice.id} />
                              <button className="button secondary small" type="submit">Issue</button>
                            </form>
                          ) : null}
                        </td>
                      </tr>
                    );
                  })}
                </tbody>
              </table>
            </div>
          ) : <EmptyState title="No invoices yet" description="Add a customer, then create your first invoice." />}
        </section>

        <aside className="card">
          <div className="card-header"><h2>New invoice</h2></div>
          <form action={createInvoice} className="form-stack">
            {params.error ? <div className="alert error">{params.error}</div> : null}
            {params.message ? <div className="alert success">{params.message}</div> : null}
            <div className="field">
              <label htmlFor="contact_id">Customer</label>
              <select id="contact_id" name="contact_id" required>
                <option value="">Select customer</option>
                {contacts?.map((contact) => <option key={contact.id} value={contact.id}>{contact.name}</option>)}
              </select>
            </div>
            <div className="form-grid">
              <div className="field"><label htmlFor="issue_date">Issue date</label><input id="issue_date" name="issue_date" type="date" defaultValue={today.toISOString().slice(0, 10)} required /></div>
              <div className="field"><label htmlFor="due_date">Due date</label><input id="due_date" name="due_date" type="date" defaultValue={due.toISOString().slice(0, 10)} required /></div>
            </div>
            <div className="field"><label htmlFor="description">Line description</label><input id="description" name="description" placeholder="Architectural drafting services" required /></div>
            <div className="form-grid three">
              <div className="field"><label htmlFor="quantity">Qty</label><input id="quantity" name="quantity" type="number" min="0.01" step="0.01" defaultValue="1" required /></div>
              <div className="field"><label htmlFor="unit_price">Unit price</label><input id="unit_price" name="unit_price" type="number" min="0.01" step="0.01" required /></div>
              <div className="field"><label htmlFor="tax_rate">Tax %</label><input id="tax_rate" name="tax_rate" type="number" min="0" max="100" step="0.01" defaultValue="0" /></div>
            </div>
            <div className="field">
              <label htmlFor="revenue_account_id">Revenue account</label>
              <select id="revenue_account_id" name="revenue_account_id" required>
                <option value="">Select revenue account</option>
                {revenueAccounts?.map((account) => <option key={account.id} value={account.id}>{account.code} · {account.name}</option>)}
              </select>
            </div>
            <div className="field"><label htmlFor="notes">Notes</label><textarea id="notes" name="notes" /></div>
            <button className="button" type="submit">Save draft invoice</button>
          </form>
        </aside>
      </div>

      <section className="card">
        <div className="card-header"><h2>Record customer payment</h2></div>
        <form action={recordInvoicePayment} className="form-grid three">
          <div className="field">
            <label htmlFor="payment_invoice_id">Outstanding invoice</label>
            <select id="payment_invoice_id" name="invoice_id" required>
              <option value="">Select invoice</option>
              {invoices?.filter((invoice) => ["issued", "partially_paid", "overdue"].includes(invoice.status)).map((invoice) => (
                <option key={invoice.id} value={invoice.id}>{invoice.invoice_number} · {formatMoney(invoice.balance_due)}</option>
              ))}
            </select>
          </div>
          <div className="field">
            <label htmlFor="payment_bank_account_id">Deposit to</label>
            <select id="payment_bank_account_id" name="bank_account_id" required>
              <option value="">Select bank account</option>
              {bankAccounts?.map((account) => <option key={account.id} value={account.id}>{account.name}</option>)}
            </select>
          </div>
          <div className="field"><label htmlFor="payment_date">Payment date</label><input id="payment_date" name="payment_date" type="date" defaultValue={today.toISOString().slice(0, 10)} required /></div>
          <div className="field"><label htmlFor="payment_amount">Amount</label><input id="payment_amount" name="amount" type="number" min="0.01" step="0.01" required /></div>
          <div className="field"><label htmlFor="payment_reference">Reference</label><input id="payment_reference" name="reference" /></div>
          <div className="field" style={{ alignSelf: "end" }}><button className="button" type="submit">Record receipt</button></div>
        </form>
      </section>
    </>
  );
}
