-- LedgerMY migration segment
begin;

-- LedgerMY initial schema
-- Supabase/PostgreSQL, multi-tenant, double-entry, audit-first.


create extension if not exists pgcrypto;

do $$ begin
  create type public.organization_role as enum ('owner', 'admin', 'bookkeeper', 'viewer');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.account_type as enum ('asset', 'liability', 'equity', 'income', 'expense');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.contact_type as enum ('customer', 'supplier', 'both');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.journal_status as enum ('draft', 'posted', 'void');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.invoice_status as enum ('draft', 'issued', 'partially_paid', 'paid', 'overdue', 'void');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.bill_status as enum ('draft', 'approved', 'partially_paid', 'paid', 'overdue', 'void');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.bank_transaction_status as enum ('unmatched', 'matched', 'excluded');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.payment_type as enum ('customer_receipt', 'supplier_payment');
exception when duplicate_object then null; end $$;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text,
  avatar_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.organizations (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(name) between 2 and 120),
  slug text not null unique check (slug ~ '^[a-z0-9]+(?:-[a-z0-9]+)*$'),
  base_currency char(3) not null default 'MYR',
  fiscal_year_start smallint not null default 1 check (fiscal_year_start between 1 and 12),
  registration_number text,
  tax_number text,
  address text,
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.organization_members (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role public.organization_role not null default 'viewer',
  invited_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  unique (organization_id, user_id)
);

create index if not exists organization_members_user_idx
  on public.organization_members(user_id, organization_id);

create table if not exists public.accounts (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  code text not null check (char_length(code) between 1 and 20),
  name text not null check (char_length(name) between 2 and 120),
  type public.account_type not null,
  subtype text,
  description text,
  is_system boolean not null default false,
  is_active boolean not null default true,
  created_by uuid not null default auth.uid() references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, code)
);

create index if not exists accounts_org_type_idx
  on public.accounts(organization_id, type, is_active);

create table if not exists public.contacts (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  name text not null check (char_length(name) between 1 and 160),
  contact_type public.contact_type not null,
  email text,
  phone text,
  registration_number text,
  tax_number text,
  address text,
  is_active boolean not null default true,
  created_by uuid not null default auth.uid() references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists contacts_org_type_idx
  on public.contacts(organization_id, contact_type, is_active);

create table if not exists public.document_sequences (
  organization_id uuid not null references public.organizations(id) on delete cascade,
  document_type text not null,
  period_key text not null,
  last_value bigint not null default 0,
  primary key (organization_id, document_type, period_key)
);

create table if not exists public.journal_entries (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  entry_number text not null,
  entry_date date not null,
  reference text,
  description text not null check (char_length(description) between 1 and 500),
  status public.journal_status not null default 'draft',
  source_type text not null default 'manual',
  source_id uuid,
  total_debit numeric(18,2) not null default 0,
  total_credit numeric(18,2) not null default 0,
  posted_at timestamptz,
  posted_by uuid references auth.users(id),
  created_by uuid not null default auth.uid() references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, entry_number)
);

create index if not exists journal_entries_org_date_idx
  on public.journal_entries(organization_id, entry_date desc);
create index if not exists journal_entries_source_idx
  on public.journal_entries(organization_id, source_type, source_id);

create table if not exists public.journal_lines (
  id uuid primary key default gen_random_uuid(),
  journal_entry_id uuid not null references public.journal_entries(id) on delete cascade,
  account_id uuid not null references public.accounts(id),
  contact_id uuid references public.contacts(id),
  description text,
  debit numeric(18,2) not null default 0 check (debit >= 0),
  credit numeric(18,2) not null default 0 check (credit >= 0),
  created_at timestamptz not null default now(),
  check (
    (debit > 0 and credit = 0)
    or (credit > 0 and debit = 0)
  )
);

create index if not exists journal_lines_entry_idx
  on public.journal_lines(journal_entry_id);
create index if not exists journal_lines_account_idx
  on public.journal_lines(account_id, journal_entry_id);

create table if not exists public.invoices (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  contact_id uuid not null references public.contacts(id),
  invoice_number text not null,
  issue_date date not null,
  due_date date not null,
  status public.invoice_status not null default 'draft',
  currency char(3) not null default 'MYR',
  subtotal numeric(18,2) not null default 0,
  tax_total numeric(18,2) not null default 0,
  total numeric(18,2) not null default 0,
  amount_paid numeric(18,2) not null default 0,
  balance_due numeric(18,2) generated always as (total - amount_paid) stored,
  notes text,
  journal_entry_id uuid references public.journal_entries(id),
  created_by uuid not null default auth.uid() references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (due_date >= issue_date),
  check (subtotal >= 0 and tax_total >= 0 and total >= 0 and amount_paid >= 0),
  check (amount_paid <= total),
  unique (organization_id, invoice_number)
);

create index if not exists invoices_org_status_due_idx
  on public.invoices(organization_id, status, due_date);

create table if not exists public.invoice_items (
  id uuid primary key default gen_random_uuid(),
  invoice_id uuid not null references public.invoices(id) on delete cascade,
  description text not null,
  quantity numeric(18,4) not null check (quantity > 0),
  unit_price numeric(18,4) not null check (unit_price >= 0),
  tax_rate numeric(7,4) not null default 0 check (tax_rate between 0 and 100),
  subtotal numeric(18,2) not null,
  tax_amount numeric(18,2) not null default 0,
  total numeric(18,2) not null,
  revenue_account_id uuid not null references public.accounts(id),
  created_at timestamptz not null default now()
);

create table if not exists public.bills (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  contact_id uuid not null references public.contacts(id),
  bill_number text not null,
  supplier_reference text,
  bill_date date not null,
  due_date date not null,
  status public.bill_status not null default 'draft',
  currency char(3) not null default 'MYR',
  subtotal numeric(18,2) not null default 0,
  tax_total numeric(18,2) not null default 0,
  total numeric(18,2) not null default 0,
  amount_paid numeric(18,2) not null default 0,
  balance_due numeric(18,2) generated always as (total - amount_paid) stored,
  notes text,
  journal_entry_id uuid references public.journal_entries(id),
  created_by uuid not null default auth.uid() references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (due_date >= bill_date),
  check (subtotal >= 0 and tax_total >= 0 and total >= 0 and amount_paid >= 0),
  check (amount_paid <= total),
  unique (organization_id, bill_number)
);

create index if not exists bills_org_status_due_idx
  on public.bills(organization_id, status, due_date);

create table if not exists public.bill_items (
  id uuid primary key default gen_random_uuid(),
  bill_id uuid not null references public.bills(id) on delete cascade,
  description text not null,
  quantity numeric(18,4) not null check (quantity > 0),
  unit_price numeric(18,4) not null check (unit_price >= 0),
  tax_rate numeric(7,4) not null default 0 check (tax_rate between 0 and 100),
  subtotal numeric(18,2) not null,
  tax_amount numeric(18,2) not null default 0,
  total numeric(18,2) not null,
  expense_account_id uuid not null references public.accounts(id),
  created_at timestamptz not null default now()
);

create table if not exists public.bank_accounts (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  account_id uuid not null references public.accounts(id),
  name text not null,
  bank_name text,
  masked_number text,
  currency char(3) not null default 'MYR',
  opening_balance numeric(18,2) not null default 0,
  is_active boolean not null default true,
  created_by uuid not null default auth.uid() references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, account_id)
);


create table if not exists public.payments (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  contact_id uuid not null references public.contacts(id),
  bank_account_id uuid not null references public.bank_accounts(id),
  payment_type public.payment_type not null,
  payment_date date not null,
  amount numeric(18,2) not null check (amount > 0),
  reference text,
  journal_entry_id uuid not null references public.journal_entries(id),
  created_by uuid not null default auth.uid() references auth.users(id),
  created_at timestamptz not null default now()
);

create index if not exists payments_org_date_idx
  on public.payments(organization_id, payment_date desc);

create table if not exists public.payment_allocations (
  id uuid primary key default gen_random_uuid(),
  payment_id uuid not null references public.payments(id) on delete cascade,
  invoice_id uuid references public.invoices(id),
  bill_id uuid references public.bills(id),
  amount numeric(18,2) not null check (amount > 0),
  created_at timestamptz not null default now(),
  check (
    (invoice_id is not null and bill_id is null)
    or (invoice_id is null and bill_id is not null)
  )
);

create table if not exists public.bank_transactions (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  bank_account_id uuid not null references public.bank_accounts(id) on delete cascade,
  transaction_date date not null,
  value_date date,
  description text not null,
  reference text,
  amount numeric(18,2) not null check (amount <> 0),
  status public.bank_transaction_status not null default 'unmatched',
  external_id text,
  import_hash text,
  journal_entry_id uuid references public.journal_entries(id),
  imported_by uuid not null default auth.uid() references auth.users(id),
  created_at timestamptz not null default now(),
  unique (bank_account_id, external_id),
  unique (bank_account_id, import_hash)
);

create index if not exists bank_transactions_org_date_idx
  on public.bank_transactions(organization_id, transaction_date desc);

create table if not exists public.reconciliation_matches (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  bank_transaction_id uuid not null references public.bank_transactions(id) on delete cascade,
  journal_entry_id uuid not null references public.journal_entries(id),
  matched_amount numeric(18,2) not null check (matched_amount > 0),
  matched_by uuid not null default auth.uid() references auth.users(id),
  matched_at timestamptz not null default now(),
  unique (bank_transaction_id, journal_entry_id)
);

create table if not exists public.documents (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  uploaded_by uuid not null references auth.users(id),
  name text not null check (char_length(name) between 1 and 180),
  category text not null default 'other',
  storage_path text not null unique,
  mime_type text not null,
  size_bytes bigint not null check (size_bytes > 0 and size_bytes <= 10485760),
  linked_entity_type text,
  linked_entity_id uuid,
  created_at timestamptz not null default now()
);

create index if not exists documents_org_created_idx
  on public.documents(organization_id, created_at desc);

create table if not exists public.fiscal_locks (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  lock_date date not null,
  reason text,
  created_by uuid not null default auth.uid() references auth.users(id),
  created_at timestamptz not null default now(),
  unique (organization_id, lock_date)
);

create table if not exists public.audit_logs (
  id bigint generated always as identity primary key,
  organization_id uuid references public.organizations(id) on delete set null,
  actor_id uuid references auth.users(id) on delete set null,
  table_name text not null,
  row_id text,
  operation text not null check (operation in ('INSERT', 'UPDATE', 'DELETE')),
  old_data jsonb,
  new_data jsonb,
  occurred_at timestamptz not null default now()
);

create index if not exists audit_logs_org_time_idx
  on public.audit_logs(organization_id, occurred_at desc);

commit;
