-- LedgerMY integrity hardening
begin;

create or replace function public.validate_bank_account_link()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_account_org uuid;
  v_account_type public.account_type;
begin
  select organization_id, type
  into v_account_org, v_account_type
  from public.accounts
  where id = new.account_id and is_active;

  if v_account_org is null then
    raise exception 'The selected ledger account does not exist or is inactive.';
  end if;
  if v_account_org is distinct from new.organization_id then
    raise exception 'The bank and ledger accounts belong to different organizations.';
  end if;
  if v_account_type <> 'asset' then
    raise exception 'A bank account must map to an asset ledger account.';
  end if;

  return new;
end;
$$;

create or replace function public.validate_bank_transaction_link()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_bank_org uuid;
  v_journal_org uuid;
begin
  select organization_id into v_bank_org
  from public.bank_accounts
  where id = new.bank_account_id;

  if v_bank_org is null or v_bank_org is distinct from new.organization_id then
    raise exception 'The bank transaction belongs to an invalid organization.';
  end if;

  if new.journal_entry_id is not null then
    select organization_id into v_journal_org
    from public.journal_entries
    where id = new.journal_entry_id and status = 'posted';

    if v_journal_org is null or v_journal_org is distinct from new.organization_id then
      raise exception 'The linked journal is invalid or belongs to another organization.';
    end if;
  end if;

  return new;
end;
$$;

create or replace function public.validate_reconciliation_link()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_transaction_org uuid;
  v_transaction_amount numeric(18,2);
  v_journal_org uuid;
  v_existing_total numeric(18,2);
begin
  select organization_id, abs(amount)
  into v_transaction_org, v_transaction_amount
  from public.bank_transactions
  where id = new.bank_transaction_id;

  select organization_id into v_journal_org
  from public.journal_entries
  where id = new.journal_entry_id and status = 'posted';

  if v_transaction_org is null
     or v_journal_org is null
     or v_transaction_org is distinct from new.organization_id
     or v_journal_org is distinct from new.organization_id then
    raise exception 'Reconciliation records must belong to the same organization.';
  end if;

  select coalesce(sum(matched_amount), 0)
  into v_existing_total
  from public.reconciliation_matches
  where bank_transaction_id = new.bank_transaction_id
    and id <> coalesce(new.id, gen_random_uuid());

  if v_existing_total + new.matched_amount > v_transaction_amount then
    raise exception 'Matched amounts cannot exceed the bank transaction amount.';
  end if;

  return new;
end;
$$;

create or replace function public.sync_bank_transaction_status()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_transaction_id uuid;
  v_matched numeric(18,2);
  v_total numeric(18,2);
begin
  v_transaction_id := case when tg_op = 'DELETE' then old.bank_transaction_id else new.bank_transaction_id end;

  select abs(amount) into v_total
  from public.bank_transactions
  where id = v_transaction_id;

  select coalesce(sum(matched_amount), 0) into v_matched
  from public.reconciliation_matches
  where bank_transaction_id = v_transaction_id;

  update public.bank_transactions
  set status = case when v_matched >= v_total then 'matched' else 'unmatched' end
  where id = v_transaction_id and status <> 'excluded';

  return case when tg_op = 'DELETE' then old else new end;
end;
$$;

drop trigger if exists validate_bank_account_link on public.bank_accounts;
create trigger validate_bank_account_link
before insert or update of organization_id, account_id on public.bank_accounts
for each row execute function public.validate_bank_account_link();

drop trigger if exists validate_bank_transaction_link on public.bank_transactions;
create trigger validate_bank_transaction_link
before insert or update of organization_id, bank_account_id, journal_entry_id on public.bank_transactions
for each row execute function public.validate_bank_transaction_link();

drop trigger if exists validate_reconciliation_link on public.reconciliation_matches;
create trigger validate_reconciliation_link
before insert or update on public.reconciliation_matches
for each row execute function public.validate_reconciliation_link();

drop trigger if exists sync_bank_transaction_status on public.reconciliation_matches;
create trigger sync_bank_transaction_status
after insert or update or delete on public.reconciliation_matches
for each row execute function public.sync_bank_transaction_status();

-- Preserve actor attribution for tables that permit direct authenticated inserts.
drop policy if exists "accounts_insert_bookkeepers" on public.accounts;
create policy "accounts_insert_bookkeepers" on public.accounts
for insert with check (
  created_by = auth.uid()
  and not is_system
  and public.has_org_role(
    organization_id,
    array['owner', 'admin', 'bookkeeper']::public.organization_role[]
  )
);

drop policy if exists "contacts_insert_bookkeepers" on public.contacts;
create policy "contacts_insert_bookkeepers" on public.contacts
for insert with check (
  created_by = auth.uid()
  and public.has_org_role(
    organization_id,
    array['owner', 'admin', 'bookkeeper']::public.organization_role[]
  )
);

drop policy if exists "bank_accounts_insert_bookkeepers" on public.bank_accounts;
create policy "bank_accounts_insert_bookkeepers" on public.bank_accounts
for insert with check (
  created_by = auth.uid()
  and public.has_org_role(
    organization_id,
    array['owner', 'admin', 'bookkeeper']::public.organization_role[]
  )
);

drop policy if exists "bank_transactions_insert_bookkeepers" on public.bank_transactions;
create policy "bank_transactions_insert_bookkeepers" on public.bank_transactions
for insert with check (
  imported_by = auth.uid()
  and public.has_org_role(
    organization_id,
    array['owner', 'admin', 'bookkeeper']::public.organization_role[]
  )
);

drop policy if exists "fiscal_locks_insert_admins" on public.fiscal_locks;
create policy "fiscal_locks_insert_admins" on public.fiscal_locks
for insert with check (
  created_by = auth.uid()
  and public.has_org_role(
    organization_id,
    array['owner', 'admin']::public.organization_role[]
  )
);

revoke execute on function public.next_document_number(uuid, text, date) from public;
revoke execute on function public.assert_period_open(uuid, date) from public;
revoke execute on function public.validate_bank_account_link() from public;
revoke execute on function public.validate_bank_transaction_link() from public;
revoke execute on function public.validate_reconciliation_link() from public;
revoke execute on function public.sync_bank_transaction_status() from public;

commit;
