import { PageHeader } from "@/components/page-header";
import { formatMoney } from "@/lib/money";
import { requireOrganization } from "@/lib/organization";

type TrialBalanceRow = {
  account_code: string;
  account_name: string;
  account_type: string;
  debit: number;
  credit: number;
};

type ProfitLossRow = {
  section: string;
  account_code: string;
  account_name: string;
  amount: number;
};

export const metadata = { title: "Reports" };

export default async function ReportsPage({
  searchParams,
}: {
  searchParams: Promise<{ from?: string; to?: string }>;
}) {
  const { supabase, organization } = await requireOrganization();
  const params = await searchParams;
  const today = new Date();
  const yearStart = `${today.getFullYear()}-01-01`;
  const from = /^\d{4}-\d{2}-\d{2}$/.test(params.from ?? "") ? params.from! : yearStart;
  const to = /^\d{4}-\d{2}-\d{2}$/.test(params.to ?? "") ? params.to! : today.toISOString().slice(0, 10);

  const [{ data: trialBalance }, { data: profitLoss }] = await Promise.all([
    supabase.rpc("trial_balance", {
      p_organization_id: organization.id,
      p_from: from,
      p_to: to,
    }),
    supabase.rpc("profit_and_loss", {
      p_organization_id: organization.id,
      p_from: from,
      p_to: to,
    }),
  ]);

  const tb = (trialBalance ?? []) as TrialBalanceRow[];
  const pnl = (profitLoss ?? []) as ProfitLossRow[];
  const income = pnl.filter((row) => row.section === "income").reduce((sum, row) => sum + Number(row.amount), 0);
  const expenses = pnl.filter((row) => row.section === "expense").reduce((sum, row) => sum + Number(row.amount), 0);

  return (
    <>
      <PageHeader title="Financial reports" description="Reports are calculated from posted journal entries only." />

      <section className="card">
        <div className="card-header"><h2>Reporting period</h2></div>
        <form method="get" className="form-grid three">
          <div className="field"><label htmlFor="from">From</label><input id="from" name="from" type="date" defaultValue={from} /></div>
          <div className="field"><label htmlFor="to">To</label><input id="to" name="to" type="date" defaultValue={to} /></div>
          <div className="field" style={{ alignSelf: "end" }}><button className="button" type="submit">Run reports</button></div>
        </form>
      </section>

      <section className="stats-grid">
        <article className="stat-card"><p>Total income</p><strong>{formatMoney(income)}</strong></article>
        <article className="stat-card"><p>Total expenses</p><strong>{formatMoney(expenses)}</strong></article>
        <article className="stat-card"><p>Net profit</p><strong>{formatMoney(income - expenses)}</strong></article>
        <article className="stat-card"><p>Period</p><strong style={{ fontSize: 17 }}>{from}<br />to {to}</strong></article>
      </section>

      <section className="card">
        <div className="card-header"><h2>Profit and loss</h2></div>
        <div className="table-wrap">
          <table>
            <thead><tr><th>Section</th><th>Account</th><th>Name</th><th className="amount">Amount</th></tr></thead>
            <tbody>
              {pnl.map((row) => (
                <tr key={`${row.section}-${row.account_code}`}>
                  <td><span className="badge">{row.section}</span></td>
                  <td>{row.account_code}</td>
                  <td>{row.account_name}</td>
                  <td className="amount">{formatMoney(row.amount)}</td>
                </tr>
              ))}
              <tr><td colSpan={3}><strong>Net profit</strong></td><td className="amount"><strong>{formatMoney(income - expenses)}</strong></td></tr>
            </tbody>
          </table>
        </div>
      </section>

      <section className="card">
        <div className="card-header"><h2>Trial balance</h2></div>
        <div className="table-wrap">
          <table>
            <thead><tr><th>Code</th><th>Account</th><th>Type</th><th className="amount">Debit</th><th className="amount">Credit</th></tr></thead>
            <tbody>
              {tb.map((row) => (
                <tr key={row.account_code}>
                  <td>{row.account_code}</td>
                  <td>{row.account_name}</td>
                  <td><span className="badge">{row.account_type}</span></td>
                  <td className="amount">{formatMoney(row.debit)}</td>
                  <td className="amount">{formatMoney(row.credit)}</td>
                </tr>
              ))}
              <tr>
                <td colSpan={3}><strong>Total</strong></td>
                <td className="amount"><strong>{formatMoney(tb.reduce((sum, row) => sum + Number(row.debit), 0))}</strong></td>
                <td className="amount"><strong>{formatMoney(tb.reduce((sum, row) => sum + Number(row.credit), 0))}</strong></td>
              </tr>
            </tbody>
          </table>
        </div>
      </section>
    </>
  );
}
