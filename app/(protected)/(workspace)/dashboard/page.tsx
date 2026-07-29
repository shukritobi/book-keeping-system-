import Link from "next/link";
import { EmptyState } from "@/components/empty-state";
import { PageHeader } from "@/components/page-header";
import { StatCard } from "@/components/stat-card";
import { formatMoney } from "@/lib/money";
import { requireOrganization } from "@/lib/organization";

type Metrics = {
  cash_balance: number;
  receivables: number;
  payables: number;
  current_month_profit: number;
};

export const metadata = { title: "Dashboard" };

export default async function DashboardPage() {
  const { supabase, organization } = await requireOrganization();
  const [{ data: metricsData }, { data: entries }] = await Promise.all([
    supabase.rpc("get_dashboard_metrics", { p_organization_id: organization.id }),
    supabase
      .from("journal_entries")
      .select("id, entry_number, entry_date, description, status, total_debit")
      .eq("organization_id", organization.id)
      .order("entry_date", { ascending: false })
      .order("created_at", { ascending: false })
      .limit(6),
  ]);

  const metrics = (metricsData ?? {
    cash_balance: 0,
    receivables: 0,
    payables: 0,
    current_month_profit: 0,
  }) as Metrics;

  return (
    <>
      <PageHeader
        title="Dashboard"
        description="A live view of your ledger, cash, receivables, and payables."
        actions={
          <>
            <Link className="button secondary" href="/bills">Add bill</Link>
            <Link className="button" href="/invoices">New invoice</Link>
          </>
        }
      />

      <section className="stats-grid">
        <StatCard label="Cash and bank" value={formatMoney(metrics.cash_balance)} note="Posted ledger balance" />
        <StatCard label="Accounts receivable" value={formatMoney(metrics.receivables)} note="Issued, unpaid invoices" />
        <StatCard label="Accounts payable" value={formatMoney(metrics.payables)} note="Approved, unpaid bills" />
        <StatCard
          label="Profit this month"
          value={formatMoney(metrics.current_month_profit)}
          note="Income less expenses"
        />
      </section>

      <section className="card">
        <div className="card-header">
          <h2>Recent journal activity</h2>
          <Link className="link caption" href="/journals">View all journals</Link>
        </div>
        {entries?.length ? (
          <div className="table-wrap">
            <table>
              <thead>
                <tr>
                  <th>Number</th>
                  <th>Date</th>
                  <th>Description</th>
                  <th>Status</th>
                  <th className="amount">Amount</th>
                </tr>
              </thead>
              <tbody>
                {entries.map((entry) => (
                  <tr key={entry.id}>
                    <td>{entry.entry_number}</td>
                    <td>{entry.entry_date}</td>
                    <td>{entry.description}</td>
                    <td><span className={`badge ${entry.status}`}>{entry.status}</span></td>
                    <td className="amount">{formatMoney(entry.total_debit)}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        ) : (
          <EmptyState
            title="No journal activity yet"
            description="Create an invoice, bill, or manual journal to start your ledger."
          />
        )}
      </section>
    </>
  );
}
