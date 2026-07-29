-- LedgerMY migration segment
begin;

-- Keep journal header totals synchronized with journal lines.
create or replace function public.recalculate_journal_totals()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_entry_id uuid;
begin
  v_entry_id := case when tg_op = 'DELETE' then old.journal_entry_id else new.journal_entry_id end;

  update public.journal_entries
  set
    total_debit = coalesce((select sum(debit) from public.journal_lines where journal_entry_id = v_entry_id), 0),
    total_credit = coalesce((select sum(credit) from public.journal_lines where journal_entry_id = v_entry_id), 0),
    updated_at = now()
  where id = v_entry_id;

  return case when tg_op = 'DELETE' then old else new end;
end;
$$;

create or replace function public.protect_journal_entry()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_org uuid;
  v_date date;
begin
  if tg_op = 'INSERT' then
    perform public.assert_period_open(new.organization_id, new.entry_date);
    return new;
  end if;

  if old.status = 'posted' then
    raise exception 'Posted journal entries are immutable.';
  end if;

  v_org := old.organization_id;
  v_date := old.entry_date;
  perform public.assert_period_open(v_org, v_date);

  if tg_op = 'UPDATE' then
    perform public.assert_period_open(new.organization_id, new.entry_date);
    return new;
  end if;

  return old;
end;
$$;

create or replace function public.protect_journal_line()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_entry_id uuid;
  v_entry public.journal_entries%rowtype;
  v_account_org uuid;
begin
  v_entry_id := case when tg_op = 'DELETE' then old.journal_entry_id else new.journal_entry_id end;

  select * into v_entry
  from public.journal_entries
  where id = v_entry_id;

  if not found then raise exception 'Journal entry not found.'; end if;
  if v_entry.status <> 'draft' then raise exception 'Only draft journals can be changed.'; end if;
  perform public.assert_period_open(v_entry.organization_id, v_entry.entry_date);

  if tg_op <> 'DELETE' then
    select organization_id into v_account_org
    from public.accounts
    where id = new.account_id;

    if v_account_org is distinct from v_entry.organization_id then
      raise exception 'Journal account belongs to a different organization.';
    end if;

    if new.contact_id is not null and not exists (
      select 1 from public.contacts
      where id = new.contact_id and organization_id = v_entry.organization_id
    ) then
      raise exception 'Journal contact belongs to a different organization.';
    end if;

    return new;
  end if;

  return old;
end;
$$;

create or replace function public.create_manual_journal(
  p_organization_id uuid,
  p_entry_date date,
  p_reference text,
  p_description text,
  p_debit_account_id uuid,
  p_credit_account_id uuid,
  p_amount numeric
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_entry_id uuid;
begin
  if not public.has_org_role(
    p_organization_id,
    array['owner', 'admin', 'bookkeeper']::public.organization_role[]
  ) then raise exception 'Insufficient permission.'; end if;

  if p_amount <= 0 then raise exception 'Amount must be greater than zero.'; end if;
  if p_debit_account_id = p_credit_account_id then raise exception 'Debit and credit accounts must differ.'; end if;
  perform public.assert_period_open(p_organization_id, p_entry_date);

  if not exists (
    select 1 from public.accounts
    where organization_id = p_organization_id
      and id in (p_debit_account_id, p_credit_account_id)
    group by organization_id
    having count(*) = 2
  ) then raise exception 'One or more accounts are invalid.'; end if;

  insert into public.journal_entries (
    organization_id, entry_number, entry_date, reference, description, source_type
  )
  values (
    p_organization_id,
    public.next_document_number(p_organization_id, 'journal', p_entry_date),
    p_entry_date,
    nullif(trim(p_reference), ''),
    trim(p_description),
    'manual'
  )
  returning id into v_entry_id;

  insert into public.journal_lines
    (journal_entry_id, account_id, description, debit, credit)
  values
    (v_entry_id, p_debit_account_id, trim(p_description), round(p_amount, 2), 0),
    (v_entry_id, p_credit_account_id, trim(p_description), 0, round(p_amount, 2));

  return v_entry_id;
end;
$$;

create or replace function public.post_journal_entry(p_journal_entry_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_entry public.journal_entries%rowtype;
  v_line_count integer;
begin
  select * into v_entry
  from public.journal_entries
  where id = p_journal_entry_id
  for update;

  if not found then raise exception 'Journal entry not found.'; end if;
  if not public.has_org_role(
    v_entry.organization_id,
    array['owner', 'admin', 'bookkeeper']::public.organization_role[]
  ) then raise exception 'Insufficient permission.'; end if;
  if v_entry.status <> 'draft' then raise exception 'Only draft journals can be posted.'; end if;

  perform public.assert_period_open(v_entry.organization_id, v_entry.entry_date);

  select count(*) into v_line_count
  from public.journal_lines
  where journal_entry_id = p_journal_entry_id;

  if v_line_count < 2 then raise exception 'A journal needs at least two lines.'; end if;

  select * into v_entry
  from public.journal_entries
  where id = p_journal_entry_id;

  if v_entry.total_debit <= 0 or v_entry.total_debit <> v_entry.total_credit then
    raise exception 'Journal is not balanced.';
  end if;

  update public.journal_entries
  set status = 'posted', posted_at = now(), posted_by = auth.uid(), updated_at = now()
  where id = p_journal_entry_id;
end;
$$;

commit;
