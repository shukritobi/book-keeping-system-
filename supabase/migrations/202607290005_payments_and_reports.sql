-- LedgerMY migration segment
begin;

create or replace function public.record_invoice_payment(
  p_invoice_id uuid,
  p_bank_account_id uuid,
  p_payment_date date,
  p_amount numeric,
  p_reference text
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_invoice public.invoices%rowtype;
  v_bank_account uuid;
  v_ar_account uuid;
  v_journal uuid;
  v_payment uuid;
begin
  select * into v_invoice from public.invoices where id = p_invoice_id for update;
  if not found then raise exception 'Invoice not found.'; end if;
  if not public.has_org_role(
    v_invoice.organization_id,
    array['owner', 'admin', 'bookkeeper']::public.organization_role[]
  ) then raise exception 'Insufficient permission.'; end if;
  if v_invoice.status not in ('issued', 'partially_paid', 'overdue') then
    raise exception 'This invoice cannot receive a payment.';
  end if;
  if p_amount <= 0 or p_amount > v_invoice.balance_due then
    raise exception 'Payment must be positive and cannot exceed the outstanding balance.';
  end if;

  perform public.assert_period_open(v_invoice.organization_id, p_payment_date);

  select account_id into v_bank_account
  from public.bank_accounts
  where id = p_bank_account_id
    and organization_id = v_invoice.organization_id
    and is_active;

  select id into v_ar_account
  from public.accounts
  where organization_id = v_invoice.organization_id and code = '1100';

  if v_bank_account is null then raise exception 'Invalid bank account.'; end if;
  if v_ar_account is null then raise exception 'Accounts Receivable account 1100 is missing.'; end if;

  insert into public.journal_entries (
    organization_id, entry_number, entry_date, reference, description, source_type, source_id
  )
  values (
    v_invoice.organization_id,
    public.next_document_number(v_invoice.organization_id, 'journal', p_payment_date),
    p_payment_date,
    nullif(trim(p_reference), ''),
    'Payment for ' || v_invoice.invoice_number,
    'invoice_payment',
    v_invoice.id
  )
  returning id into v_journal;

  insert into public.journal_lines
    (journal_entry_id, account_id, contact_id, description, debit, credit)
  values
    (v_journal, v_bank_account, v_invoice.contact_id, 'Customer payment', round(p_amount, 2), 0),
    (v_journal, v_ar_account, v_invoice.contact_id, 'Reduce receivable', 0, round(p_amount, 2));

  perform public.post_journal_entry(v_journal);

  insert into public.payments (
    organization_id, contact_id, bank_account_id, payment_type,
    payment_date, amount, reference, journal_entry_id
  )
  values (
    v_invoice.organization_id, v_invoice.contact_id, p_bank_account_id, 'customer_receipt',
    p_payment_date, round(p_amount, 2), nullif(trim(p_reference), ''), v_journal
  )
  returning id into v_payment;

  insert into public.payment_allocations (payment_id, invoice_id, amount)
  values (v_payment, v_invoice.id, round(p_amount, 2));

  update public.invoices
  set
    amount_paid = amount_paid + round(p_amount, 2),
    status = case
      when amount_paid + round(p_amount, 2) >= total then 'paid'::public.invoice_status
      else 'partially_paid'::public.invoice_status
    end,
    updated_at = now()
  where id = v_invoice.id;

  return v_payment;
end;
$$;

create or replace function public.record_bill_payment(
  p_bill_id uuid,
  p_bank_account_id uuid,
  p_payment_date date,
  p_amount numeric,
  p_reference text
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_bill public.bills%rowtype;
  v_bank_account uuid;
  v_ap_account uuid;
  v_journal uuid;
  v_payment uuid;
begin
  select * into v_bill from public.bills where id = p_bill_id for update;
  if not found then raise exception 'Bill not found.'; end if;
  if not public.has_org_role(
    v_bill.organization_id,
    array['owner', 'admin', 'bookkeeper']::public.organization_role[]
  ) then raise exception 'Insufficient permission.'; end if;
  if v_bill.status not in ('approved', 'partially_paid', 'overdue') then
    raise exception 'This bill cannot be paid.';
  end if;
  if p_amount <= 0 or p_amount > v_bill.balance_due then
    raise exception 'Payment must be positive and cannot exceed the outstanding balance.';
  end if;

  perform public.assert_period_open(v_bill.organization_id, p_payment_date);

  select account_id into v_bank_account
  from public.bank_accounts
  where id = p_bank_account_id
    and organization_id = v_bill.organization_id
    and is_active;

  select id into v_ap_account
  from public.accounts
  where organization_id = v_bill.organization_id and code = '2100';

  if v_bank_account is null then raise exception 'Invalid bank account.'; end if;
  if v_ap_account is null then raise exception 'Accounts Payable account 2100 is missing.'; end if;

  insert into public.journal_entries (
    organization_id, entry_number, entry_date, reference, description, source_type, source_id
  )
  values (
    v_bill.organization_id,
    public.next_document_number(v_bill.organization_id, 'journal', p_payment_date),
    p_payment_date,
    nullif(trim(p_reference), ''),
    'Payment for ' || v_bill.bill_number,
    'bill_payment',
    v_bill.id
  )
  returning id into v_journal;

  insert into public.journal_lines
    (journal_entry_id, account_id, contact_id, description, debit, credit)
  values
    (v_journal, v_ap_account, v_bill.contact_id, 'Reduce payable', round(p_amount, 2), 0),
    (v_journal, v_bank_account, v_bill.contact_id, 'Supplier payment', 0, round(p_amount, 2));

  perform public.post_journal_entry(v_journal);

  insert into public.payments (
    organization_id, contact_id, bank_account_id, payment_type,
    payment_date, amount, reference, journal_entry_id
  )
  values (
    v_bill.organization_id, v_bill.contact_id, p_bank_account_id, 'supplier_payment',
    p_payment_date, round(p_amount, 2), nullif(trim(p_reference), ''), v_journal
  )
  returning id into v_payment;

  insert into public.payment_allocations (payment_id, bill_id, amount)
  values (v_payment, v_bill.id, round(p_amount, 2));

  update public.bills
  set
    amount_paid = amount_paid + round(p_amount, 2),
    status = case
      when amount_paid + round(p_amount, 2) >= total then 'paid'::public.bill_status
      else 'partially_paid'::public.bill_status
    end,
    updated_at = now()
  where id = v_bill.id;

  return v_payment;
end;
$$;

-- Reporting functions only return data to organization members.
create or replace function public.trial_balance(
  p_organization_id uuid,
  p_from date,
  p_to date
)
returns table (
  account_code text,
  account_name text,
  account_type public.account_type,
  debit numeric,
  credit numeric
)
language sql
stable
security definer
set search_path = public
as $$
  select
    a.code,
    a.name,
    a.type,
    greatest(coalesce(sum(jl.debit - jl.credit), 0), 0) as debit,
    greatest(coalesce(sum(jl.credit - jl.debit), 0), 0) as credit
  from public.accounts a
  join public.journal_lines jl on jl.account_id = a.id
  join public.journal_entries je on je.id = jl.journal_entry_id
  where a.organization_id = p_organization_id
    and public.is_org_member(p_organization_id)
    and je.status = 'posted'
    and je.entry_date between p_from and p_to
  group by a.id, a.code, a.name, a.type
  having coalesce(sum(jl.debit - jl.credit), 0) <> 0
  order by a.code;
$$;

create or replace function public.profit_and_loss(
  p_organization_id uuid,
  p_from date,
  p_to date
)
returns table (
  section text,
  account_code text,
  account_name text,
  amount numeric
)
language sql
stable
security definer
set search_path = public
as $$
  select
    case when a.type = 'income' then 'income' else 'expense' end,
    a.code,
    a.name,
    case
      when a.type = 'income' then coalesce(sum(jl.credit - jl.debit), 0)
      else coalesce(sum(jl.debit - jl.credit), 0)
    end as amount
  from public.accounts a
  join public.journal_lines jl on jl.account_id = a.id
  join public.journal_entries je on je.id = jl.journal_entry_id
  where a.organization_id = p_organization_id
    and public.is_org_member(p_organization_id)
    and a.type in ('income', 'expense')
    and je.status = 'posted'
    and je.entry_date between p_from and p_to
  group by a.id, a.type, a.code, a.name
  having case
    when a.type = 'income' then coalesce(sum(jl.credit - jl.debit), 0)
    else coalesce(sum(jl.debit - jl.credit), 0)
  end <> 0
  order by case when a.type = 'income' then 1 else 2 end, a.code;
$$;

create or replace function public.balance_sheet(
  p_organization_id uuid,
  p_as_of date
)
returns table (
  section text,
  account_code text,
  account_name text,
  amount numeric
)
language sql
stable
security definer
set search_path = public
as $$
  select
    a.type::text,
    a.code,
    a.name,
    case
      when a.type = 'asset' then coalesce(sum(jl.debit - jl.credit), 0)
      else coalesce(sum(jl.credit - jl.debit), 0)
    end
  from public.accounts a
  join public.journal_lines jl on jl.account_id = a.id
  join public.journal_entries je on je.id = jl.journal_entry_id
  where a.organization_id = p_organization_id
    and public.is_org_member(p_organization_id)
    and a.type in ('asset', 'liability', 'equity')
    and je.status = 'posted'
    and je.entry_date <= p_as_of
  group by a.id, a.type, a.code, a.name
  having case
    when a.type = 'asset' then coalesce(sum(jl.debit - jl.credit), 0)
    else coalesce(sum(jl.credit - jl.debit), 0)
  end <> 0
  order by case a.type when 'asset' then 1 when 'liability' then 2 else 3 end, a.code;
$$;

create or replace function public.get_dashboard_metrics(p_organization_id uuid)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select jsonb_build_object(
    'cash_balance',
      coalesce((
        select sum(jl.debit - jl.credit)
        from public.journal_lines jl
        join public.journal_entries je on je.id = jl.journal_entry_id
        join public.accounts a on a.id = jl.account_id
        where je.organization_id = p_organization_id
          and je.status = 'posted'
          and a.subtype in ('cash', 'bank')
      ), 0),
    'receivables',
      coalesce((
        select sum(balance_due)
        from public.invoices
        where organization_id = p_organization_id
          and status in ('issued', 'partially_paid', 'overdue')
      ), 0),
    'payables',
      coalesce((
        select sum(balance_due)
        from public.bills
        where organization_id = p_organization_id
          and status in ('approved', 'partially_paid', 'overdue')
      ), 0),
    'current_month_profit',
      coalesce((
        select sum(
          case
            when a.type = 'income' then jl.credit - jl.debit
            when a.type = 'expense' then -(jl.debit - jl.credit)
            else 0
          end
        )
        from public.journal_lines jl
        join public.journal_entries je on je.id = jl.journal_entry_id
        join public.accounts a on a.id = jl.account_id
        where je.organization_id = p_organization_id
          and je.status = 'posted'
          and je.entry_date >= date_trunc('month', current_date)::date
          and je.entry_date <= current_date
      ), 0)
  )
  where public.is_org_member(p_organization_id);
$$;

commit;
