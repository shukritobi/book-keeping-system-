-- LedgerMY migration segment
begin;

-- Common timestamp helper.
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- Safely parse a UUID from an untrusted storage path.
create or replace function public.safe_uuid(value text)
returns uuid
language plpgsql
immutable
as $$
begin
  return value::uuid;
exception when others then
  return null;
end;
$$;

-- Membership helpers are SECURITY DEFINER to avoid RLS recursion.
create or replace function public.is_org_member(p_organization_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.organization_members
    where organization_id = p_organization_id
      and user_id = auth.uid()
  );
$$;

create or replace function public.has_org_role(
  p_organization_id uuid,
  p_roles public.organization_role[]
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.organization_members
    where organization_id = p_organization_id
      and user_id = auth.uid()
      and role = any(p_roles)
  );
$$;

create or replace function public.is_period_locked(
  p_organization_id uuid,
  p_entry_date date
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.fiscal_locks
    where organization_id = p_organization_id
      and lock_date >= p_entry_date
  );
$$;

create or replace function public.assert_period_open(
  p_organization_id uuid,
  p_entry_date date
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if public.is_period_locked(p_organization_id, p_entry_date) then
    raise exception 'The accounting period containing % is locked.', p_entry_date;
  end if;
end;
$$;

create or replace function public.next_document_number(
  p_organization_id uuid,
  p_document_type text,
  p_document_date date
)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_period text := to_char(p_document_date, 'YYYY');
  v_value bigint;
  v_prefix text;
begin
  if not public.has_org_role(
    p_organization_id,
    array['owner', 'admin', 'bookkeeper']::public.organization_role[]
  ) then
    raise exception 'You do not have permission to create accounting documents.';
  end if;

  insert into public.document_sequences (
    organization_id, document_type, period_key, last_value
  )
  values (p_organization_id, lower(p_document_type), v_period, 1)
  on conflict (organization_id, document_type, period_key)
  do update set last_value = public.document_sequences.last_value + 1
  returning last_value into v_value;

  v_prefix := case lower(p_document_type)
    when 'invoice' then 'INV'
    when 'bill' then 'BILL'
    when 'journal' then 'JRN'
    else upper(left(p_document_type, 6))
  end;

  return format('%s-%s-%s', v_prefix, v_period, lpad(v_value::text, 5, '0'));
end;
$$;

create or replace function public.seed_default_accounts(p_organization_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.accounts
    (organization_id, code, name, type, subtype, description, is_system)
  values
    (p_organization_id, '1000', 'Cash on Hand', 'asset', 'cash', 'Physical cash and petty cash.', true),
    (p_organization_id, '1010', 'Bank Account', 'asset', 'bank', 'Primary business bank account.', true),
    (p_organization_id, '1100', 'Accounts Receivable', 'asset', 'receivable', 'Amounts owed by customers.', true),
    (p_organization_id, '1300', 'Input Tax', 'asset', 'tax', 'Recoverable input tax.', true),
    (p_organization_id, '1500', 'Equipment', 'asset', 'fixed_asset', 'Business equipment at cost.', true),
    (p_organization_id, '1590', 'Accumulated Depreciation', 'asset', 'contra_asset', 'Accumulated depreciation.', true),
    (p_organization_id, '2100', 'Accounts Payable', 'liability', 'payable', 'Amounts owed to suppliers.', true),
    (p_organization_id, '2200', 'Output Tax Payable', 'liability', 'tax', 'Collected tax payable.', true),
    (p_organization_id, '2300', 'Accrued Expenses', 'liability', 'current_liability', 'Expenses incurred but not yet paid.', true),
    (p_organization_id, '3000', 'Owner Capital', 'equity', 'capital', 'Owner contributions.', true),
    (p_organization_id, '3100', 'Retained Earnings', 'equity', 'retained_earnings', 'Cumulative retained profits.', true),
    (p_organization_id, '4000', 'Sales Revenue', 'income', 'revenue', 'Income from goods or services.', true),
    (p_organization_id, '4100', 'Service Revenue', 'income', 'revenue', 'Income from professional services.', true),
    (p_organization_id, '5000', 'Cost of Sales', 'expense', 'cost_of_sales', 'Direct costs of sales.', true),
    (p_organization_id, '6000', 'Advertising and Marketing', 'expense', 'operating_expense', null, true),
    (p_organization_id, '6100', 'Software and Subscriptions', 'expense', 'operating_expense', null, true),
    (p_organization_id, '6200', 'Office Expenses', 'expense', 'operating_expense', null, true),
    (p_organization_id, '6300', 'Professional Fees', 'expense', 'operating_expense', null, true),
    (p_organization_id, '6400', 'Travel and Transport', 'expense', 'operating_expense', null, true),
    (p_organization_id, '6500', 'Utilities', 'expense', 'operating_expense', null, true),
    (p_organization_id, '6900', 'Other Expenses', 'expense', 'operating_expense', null, true)
  on conflict (organization_id, code) do nothing;
end;
$$;

create or replace function public.create_organization(p_name text, p_slug text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user uuid := auth.uid();
  v_organization uuid;
begin
  if v_user is null then raise exception 'Authentication required.'; end if;
  if char_length(trim(p_name)) < 2 then raise exception 'Company name is too short.'; end if;
  if lower(trim(p_slug)) !~ '^[a-z0-9]+(?:-[a-z0-9]+)*$' then
    raise exception 'Invalid workspace slug.';
  end if;

  insert into public.organizations (name, slug, created_by)
  values (trim(p_name), lower(trim(p_slug)), v_user)
  returning id into v_organization;

  insert into public.organization_members (organization_id, user_id, role)
  values (v_organization, v_user, 'owner');

  perform public.seed_default_accounts(v_organization);
  return v_organization;
end;
$$;

commit;
