-- LedgerMY migration segment
begin;

create or replace function public.create_simple_invoice(
  p_organization_id uuid,
  p_contact_id uuid,
  p_issue_date date,
  p_due_date date,
  p_description text,
  p_quantity numeric,
  p_unit_price numeric,
  p_tax_rate numeric,
  p_revenue_account_id uuid,
  p_notes text
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_invoice_id uuid;
  v_subtotal numeric(18,2);
  v_tax numeric(18,2);
  v_total numeric(18,2);
  v_currency char(3);
begin
  if not public.has_org_role(
    p_organization_id,
    array['owner', 'admin', 'bookkeeper']::public.organization_role[]
  ) then raise exception 'Insufficient permission.'; end if;

  if p_due_date < p_issue_date then raise exception 'Due date cannot be before issue date.'; end if;
  if p_quantity <= 0 or p_unit_price < 0 or p_tax_rate < 0 or p_tax_rate > 100 then
    raise exception 'Invalid invoice amounts.';
  end if;
  if not exists (
    select 1 from public.contacts
    where id = p_contact_id
      and organization_id = p_organization_id
      and contact_type in ('customer', 'both')
  ) then raise exception 'Invalid customer.'; end if;
  if not exists (
    select 1 from public.accounts
    where id = p_revenue_account_id
      and organization_id = p_organization_id
      and type = 'income'
      and is_active
  ) then raise exception 'Invalid revenue account.'; end if;

  select base_currency into v_currency
  from public.organizations where id = p_organization_id;

  v_subtotal := round(p_quantity * p_unit_price, 2);
  v_tax := round(v_subtotal * p_tax_rate / 100, 2);
  v_total := v_subtotal + v_tax;

  insert into public.invoices (
    organization_id, contact_id, invoice_number, issue_date, due_date,
    currency, subtotal, tax_total, total, notes
  )
  values (
    p_organization_id, p_contact_id,
    public.next_document_number(p_organization_id, 'invoice', p_issue_date),
    p_issue_date, p_due_date, v_currency, v_subtotal, v_tax, v_total, nullif(trim(p_notes), '')
  )
  returning id into v_invoice_id;

  insert into public.invoice_items (
    invoice_id, description, quantity, unit_price, tax_rate,
    subtotal, tax_amount, total, revenue_account_id
  )
  values (
    v_invoice_id, trim(p_description), p_quantity, p_unit_price, p_tax_rate,
    v_subtotal, v_tax, v_total, p_revenue_account_id
  );

  return v_invoice_id;
end;
$$;

create or replace function public.issue_invoice(p_invoice_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_invoice public.invoices%rowtype;
  v_ar_account uuid;
  v_tax_account uuid;
  v_journal uuid;
  v_item record;
begin
  select * into v_invoice from public.invoices where id = p_invoice_id for update;
  if not found then raise exception 'Invoice not found.'; end if;
  if not public.has_org_role(
    v_invoice.organization_id,
    array['owner', 'admin', 'bookkeeper']::public.organization_role[]
  ) then raise exception 'Insufficient permission.'; end if;
  if v_invoice.status <> 'draft' then raise exception 'Only draft invoices can be issued.'; end if;
  if v_invoice.total <= 0 then raise exception 'Invoice total must be greater than zero.'; end if;

  perform public.assert_period_open(v_invoice.organization_id, v_invoice.issue_date);

  select id into v_ar_account from public.accounts
  where organization_id = v_invoice.organization_id and code = '1100';

  select id into v_tax_account from public.accounts
  where organization_id = v_invoice.organization_id and code = '2200';

  if v_ar_account is null then raise exception 'Accounts Receivable account 1100 is missing.'; end if;
  if v_invoice.tax_total > 0 and v_tax_account is null then
    raise exception 'Output Tax Payable account 2200 is missing.';
  end if;

  insert into public.journal_entries (
    organization_id, entry_number, entry_date, reference, description, source_type, source_id
  )
  values (
    v_invoice.organization_id,
    public.next_document_number(v_invoice.organization_id, 'journal', v_invoice.issue_date),
    v_invoice.issue_date,
    v_invoice.invoice_number,
    'Invoice ' || v_invoice.invoice_number,
    'invoice',
    v_invoice.id
  )
  returning id into v_journal;

  insert into public.journal_lines
    (journal_entry_id, account_id, contact_id, description, debit, credit)
  values
    (v_journal, v_ar_account, v_invoice.contact_id, 'Accounts receivable', v_invoice.total, 0);

  for v_item in
    select revenue_account_id, sum(subtotal) as amount
    from public.invoice_items
    where invoice_id = v_invoice.id
    group by revenue_account_id
  loop
    insert into public.journal_lines
      (journal_entry_id, account_id, contact_id, description, debit, credit)
    values
      (v_journal, v_item.revenue_account_id, v_invoice.contact_id, 'Revenue', 0, v_item.amount);
  end loop;

  if v_invoice.tax_total > 0 then
    insert into public.journal_lines
      (journal_entry_id, account_id, contact_id, description, debit, credit)
    values
      (v_journal, v_tax_account, v_invoice.contact_id, 'Output tax', 0, v_invoice.tax_total);
  end if;

  perform public.post_journal_entry(v_journal);

  update public.invoices
  set status = 'issued', journal_entry_id = v_journal, updated_at = now()
  where id = v_invoice.id;
end;
$$;

create or replace function public.create_simple_bill(
  p_organization_id uuid,
  p_contact_id uuid,
  p_bill_date date,
  p_due_date date,
  p_supplier_reference text,
  p_description text,
  p_quantity numeric,
  p_unit_price numeric,
  p_tax_rate numeric,
  p_expense_account_id uuid,
  p_notes text
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_bill_id uuid;
  v_subtotal numeric(18,2);
  v_tax numeric(18,2);
  v_total numeric(18,2);
  v_currency char(3);
begin
  if not public.has_org_role(
    p_organization_id,
    array['owner', 'admin', 'bookkeeper']::public.organization_role[]
  ) then raise exception 'Insufficient permission.'; end if;

  if p_due_date < p_bill_date then raise exception 'Due date cannot be before bill date.'; end if;
  if p_quantity <= 0 or p_unit_price < 0 or p_tax_rate < 0 or p_tax_rate > 100 then
    raise exception 'Invalid bill amounts.';
  end if;
  if not exists (
    select 1 from public.contacts
    where id = p_contact_id
      and organization_id = p_organization_id
      and contact_type in ('supplier', 'both')
  ) then raise exception 'Invalid supplier.'; end if;
  if not exists (
    select 1 from public.accounts
    where id = p_expense_account_id
      and organization_id = p_organization_id
      and type = 'expense'
      and is_active
  ) then raise exception 'Invalid expense account.'; end if;

  select base_currency into v_currency
  from public.organizations where id = p_organization_id;

  v_subtotal := round(p_quantity * p_unit_price, 2);
  v_tax := round(v_subtotal * p_tax_rate / 100, 2);
  v_total := v_subtotal + v_tax;

  insert into public.bills (
    organization_id, contact_id, bill_number, supplier_reference,
    bill_date, due_date, currency, subtotal, tax_total, total, notes
  )
  values (
    p_organization_id, p_contact_id,
    public.next_document_number(p_organization_id, 'bill', p_bill_date),
    nullif(trim(p_supplier_reference), ''),
    p_bill_date, p_due_date, v_currency, v_subtotal, v_tax, v_total, nullif(trim(p_notes), '')
  )
  returning id into v_bill_id;

  insert into public.bill_items (
    bill_id, description, quantity, unit_price, tax_rate,
    subtotal, tax_amount, total, expense_account_id
  )
  values (
    v_bill_id, trim(p_description), p_quantity, p_unit_price, p_tax_rate,
    v_subtotal, v_tax, v_total, p_expense_account_id
  );

  return v_bill_id;
end;
$$;

create or replace function public.approve_bill(p_bill_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_bill public.bills%rowtype;
  v_ap_account uuid;
  v_tax_account uuid;
  v_journal uuid;
  v_item record;
begin
  select * into v_bill from public.bills where id = p_bill_id for update;
  if not found then raise exception 'Bill not found.'; end if;
  if not public.has_org_role(
    v_bill.organization_id,
    array['owner', 'admin', 'bookkeeper']::public.organization_role[]
  ) then raise exception 'Insufficient permission.'; end if;
  if v_bill.status <> 'draft' then raise exception 'Only draft bills can be approved.'; end if;
  if v_bill.total <= 0 then raise exception 'Bill total must be greater than zero.'; end if;

  perform public.assert_period_open(v_bill.organization_id, v_bill.bill_date);

  select id into v_ap_account from public.accounts
  where organization_id = v_bill.organization_id and code = '2100';

  select id into v_tax_account from public.accounts
  where organization_id = v_bill.organization_id and code = '1300';

  if v_ap_account is null then raise exception 'Accounts Payable account 2100 is missing.'; end if;
  if v_bill.tax_total > 0 and v_tax_account is null then
    raise exception 'Input Tax account 1300 is missing.';
  end if;

  insert into public.journal_entries (
    organization_id, entry_number, entry_date, reference, description, source_type, source_id
  )
  values (
    v_bill.organization_id,
    public.next_document_number(v_bill.organization_id, 'journal', v_bill.bill_date),
    v_bill.bill_date,
    coalesce(v_bill.supplier_reference, v_bill.bill_number),
    'Bill ' || v_bill.bill_number,
    'bill',
    v_bill.id
  )
  returning id into v_journal;

  for v_item in
    select expense_account_id, sum(subtotal) as amount
    from public.bill_items
    where bill_id = v_bill.id
    group by expense_account_id
  loop
    insert into public.journal_lines
      (journal_entry_id, account_id, contact_id, description, debit, credit)
    values
      (v_journal, v_item.expense_account_id, v_bill.contact_id, 'Expense', v_item.amount, 0);
  end loop;

  if v_bill.tax_total > 0 then
    insert into public.journal_lines
      (journal_entry_id, account_id, contact_id, description, debit, credit)
    values
      (v_journal, v_tax_account, v_bill.contact_id, 'Input tax', v_bill.tax_total, 0);
  end if;

  insert into public.journal_lines
    (journal_entry_id, account_id, contact_id, description, debit, credit)
  values
    (v_journal, v_ap_account, v_bill.contact_id, 'Accounts payable', 0, v_bill.total);

  perform public.post_journal_entry(v_journal);

  update public.bills
  set status = 'approved', journal_entry_id = v_journal, updated_at = now()
  where id = v_bill.id;
end;
$$;

commit;
