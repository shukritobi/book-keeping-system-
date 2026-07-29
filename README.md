# LedgerMY Bookkeeping System

A secure, multi-company bookkeeping foundation for Malaysian small businesses. The application uses double-entry accounting, Supabase authentication and PostgreSQL row-level security, private document storage, immutable posted journals, and an append-only audit trail.

## What is included

- Email/password authentication with verified server-side sessions
- Multi-company data model with owner, admin, bookkeeper, and viewer roles
- Malaysian starter chart of accounts with MYR as the default currency
- Customers and suppliers
- Manual double-entry journals with database-enforced balancing
- Draft, issue, and posting flow for sales invoices
- Draft, approve, and posting flow for supplier bills
- Customer receipts and supplier payments
- Bank account mapping and a bank-feed/reconciliation-ready schema
- Private document vault with expiring signed links
- Trial balance, profit and loss, balance sheet function, and dashboard metrics
- Fiscal period locks
- Append-only audit records
- CI workflow and architecture/security documentation

## Stack

- Next.js App Router
- React and TypeScript
- Supabase Auth
- Supabase PostgreSQL
- Supabase Storage
- PostgreSQL functions, triggers, constraints, and row-level security
- Zod validation

## Local setup

### 1. Create a Supabase project

Create a project in Supabase, then copy the project URL and publishable key.

### 2. Configure environment variables

```bash
cp .env.example .env.local
```

Fill in:

```env
NEXT_PUBLIC_SUPABASE_URL=https://your-project.supabase.co
NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY=your-publishable-key
NEXT_PUBLIC_APP_URL=http://localhost:3000
```

Do not put a Supabase service-role key in this application.

### 3. Apply the database migration

Using the Supabase CLI:

```bash
supabase link --project-ref YOUR_PROJECT_REF
supabase db push
```

For a local Supabase stack:

```bash
supabase start
supabase db reset
```

The migration creates the database, RLS policies, accounting functions, private `documents` bucket, and starter chart of accounts.

### 4. Configure Auth URLs

In Supabase Auth URL Configuration, set:

- Site URL: `http://localhost:3000`
- Redirect URL: `http://localhost:3000/auth/callback`

Add the production equivalents before deployment.

### 5. Install and run

```bash
npm install
npm run dev
```

Open `http://localhost:3000`, create an account, verify the email, and create the first company.

## Production checklist

Before handling real financial records:

1. Deploy to a managed platform with HTTPS.
2. Set the production app URL and Supabase redirect URL.
3. Enable MFA for privileged users when the chosen Auth flow is added.
4. Configure database backups and periodically test restoration.
5. Enable Supabase point-in-time recovery for an appropriate production plan.
6. Add monitoring for authentication failures, database errors, and storage failures.
7. Have an accountant validate the chart of accounts, taxes, and reports for the business.
8. Run a security review and penetration test before public launch.
9. Add data export, retention, and account deletion processes.
10. Add Malaysia e-Invoice integration only after validating the latest LHDN requirements.

## Accounting rules implemented

- Every posted journal must have at least two lines.
- Total debits must equal total credits.
- Debit and credit cannot exist on the same journal line.
- Posted journals cannot be edited or deleted.
- Locked accounting periods reject new or changed journals.
- Invoices post debit Accounts Receivable and credit revenue/output tax.
- Bills post debit expense/input tax and credit Accounts Payable.
- Customer receipts debit bank and credit Accounts Receivable.
- Supplier payments debit Accounts Payable and credit bank.
- Reports use posted entries only.

## Repository guide

- `app/` pages and server actions
- `components/` shared interface components
- `lib/` authentication, Supabase, organization, money, and validation helpers
- `supabase/migrations/` complete database and security migration
- `docs/ARCHITECTURE.md` system design and data flows
- `docs/SECURITY.md` threat model and security controls
- `docs/ROADMAP.md` path from this foundation to a broader production product

## Important scope note

This repository is a strong working foundation, not a substitute for an accountant-reviewed production accounting product. The database protects the essential double-entry rules, but tax treatment, opening balances, adjustments, depreciation, credit notes, payroll, inventory, and statutory reporting still need business-specific validation.
