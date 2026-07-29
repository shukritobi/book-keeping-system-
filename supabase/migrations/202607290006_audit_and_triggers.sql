-- LedgerMY migration segment
begin;

-- User profile provisioning.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, full_name)
  values (new.id, nullif(new.raw_user_meta_data ->> 'full_name', ''))
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- Audit trail. The application has no INSERT/UPDATE/DELETE policy on audit_logs.
create or replace function public.audit_row_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_old jsonb := case when tg_op in ('UPDATE', 'DELETE') then to_jsonb(old) else null end;
  v_new jsonb := case when tg_op in ('INSERT', 'UPDATE') then to_jsonb(new) else null end;
  v_row jsonb := coalesce(v_new, v_old);
  v_org uuid;
  v_row_id text;
begin
  v_org := public.safe_uuid(v_row ->> 'organization_id');
  v_row_id := v_row ->> 'id';

  if v_org is null and tg_table_name = 'journal_lines' then
    select organization_id into v_org
    from public.journal_entries
    where id = public.safe_uuid(v_row ->> 'journal_entry_id');
  elsif v_org is null and tg_table_name = 'invoice_items' then
    select organization_id into v_org
    from public.invoices
    where id = public.safe_uuid(v_row ->> 'invoice_id');
  elsif v_org is null and tg_table_name = 'bill_items' then
    select organization_id into v_org
    from public.bills
    where id = public.safe_uuid(v_row ->> 'bill_id');
  elsif v_org is null and tg_table_name = 'payment_allocations' then
    select organization_id into v_org
    from public.payments
    where id = public.safe_uuid(v_row ->> 'payment_id');
  elsif v_org is null and tg_table_name = 'organizations' then
    v_org := public.safe_uuid(v_row ->> 'id');
  end if;

  insert into public.audit_logs (
    organization_id, actor_id, table_name, row_id, operation, old_data, new_data
  )
  values (
    v_org, auth.uid(), tg_table_name, v_row_id, tg_op, v_old, v_new
  );

  return case when tg_op = 'DELETE' then old else new end;
end;
$$;

-- Updated-at triggers.
drop trigger if exists profiles_updated_at on public.profiles;
create trigger profiles_updated_at before update on public.profiles
for each row execute function public.set_updated_at();

drop trigger if exists organizations_updated_at on public.organizations;
create trigger organizations_updated_at before update on public.organizations
for each row execute function public.set_updated_at();

drop trigger if exists accounts_updated_at on public.accounts;
create trigger accounts_updated_at before update on public.accounts
for each row execute function public.set_updated_at();

drop trigger if exists contacts_updated_at on public.contacts;
create trigger contacts_updated_at before update on public.contacts
for each row execute function public.set_updated_at();

drop trigger if exists invoices_updated_at on public.invoices;
create trigger invoices_updated_at before update on public.invoices
for each row execute function public.set_updated_at();

drop trigger if exists bills_updated_at on public.bills;
create trigger bills_updated_at before update on public.bills
for each row execute function public.set_updated_at();

drop trigger if exists bank_accounts_updated_at on public.bank_accounts;
create trigger bank_accounts_updated_at before update on public.bank_accounts
for each row execute function public.set_updated_at();

-- Journal integrity triggers.
drop trigger if exists protect_journal_entry_changes on public.journal_entries;
create trigger protect_journal_entry_changes
before insert or update or delete on public.journal_entries
for each row execute function public.protect_journal_entry();

drop trigger if exists protect_journal_line_changes on public.journal_lines;
create trigger protect_journal_line_changes
before insert or update or delete on public.journal_lines
for each row execute function public.protect_journal_line();

drop trigger if exists journal_line_totals on public.journal_lines;
create trigger journal_line_totals
after insert or update or delete on public.journal_lines
for each row execute function public.recalculate_journal_totals();

-- Audit selected business tables.
do $$
declare
  v_table text;
begin
  foreach v_table in array array[
    'organizations',
    'organization_members',
    'accounts',
    'contacts',
    'journal_entries',
    'journal_lines',
    'invoices',
    'invoice_items',
    'bills',
    'bill_items',
    'bank_accounts',
    'payments',
    'payment_allocations',
    'bank_transactions',
    'reconciliation_matches',
    'documents',
    'fiscal_locks'
  ]
  loop
    execute format('drop trigger if exists audit_%I on public.%I', v_table, v_table);
    execute format(
      'create trigger audit_%I after insert or update or delete on public.%I for each row execute function public.audit_row_change()',
      v_table, v_table
    );
  end loop;
end;
$$;

commit;
