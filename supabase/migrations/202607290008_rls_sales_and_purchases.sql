-- LedgerMY migration segment
begin;

create policy "invoices_select_members" on public.invoices
for select using (public.is_org_member(organization_id));
create policy "invoices_insert_bookkeepers" on public.invoices
for insert with check (
  public.has_org_role(organization_id, array['owner', 'admin', 'bookkeeper']::public.organization_role[])
);
create policy "invoices_update_bookkeepers" on public.invoices
for update using (
  public.has_org_role(organization_id, array['owner', 'admin', 'bookkeeper']::public.organization_role[])
) with check (
  public.has_org_role(organization_id, array['owner', 'admin', 'bookkeeper']::public.organization_role[])
);
create policy "invoices_delete_admins" on public.invoices
for delete using (
  status = 'draft'
  and public.has_org_role(organization_id, array['owner', 'admin']::public.organization_role[])
);

create policy "invoice_items_select_members" on public.invoice_items
for select using (
  exists (
    select 1 from public.invoices i
    where i.id = invoice_id and public.is_org_member(i.organization_id)
  )
);
create policy "invoice_items_insert_bookkeepers" on public.invoice_items
for insert with check (
  exists (
    select 1 from public.invoices i
    where i.id = invoice_id
      and i.status = 'draft'
      and public.has_org_role(
        i.organization_id,
        array['owner', 'admin', 'bookkeeper']::public.organization_role[]
      )
  )
);
create policy "invoice_items_update_bookkeepers" on public.invoice_items
for update using (
  exists (
    select 1 from public.invoices i
    where i.id = invoice_id
      and i.status = 'draft'
      and public.has_org_role(
        i.organization_id,
        array['owner', 'admin', 'bookkeeper']::public.organization_role[]
      )
  )
) with check (
  exists (
    select 1 from public.invoices i
    where i.id = invoice_id
      and i.status = 'draft'
      and public.has_org_role(
        i.organization_id,
        array['owner', 'admin', 'bookkeeper']::public.organization_role[]
      )
  )
);
create policy "invoice_items_delete_bookkeepers" on public.invoice_items
for delete using (
  exists (
    select 1 from public.invoices i
    where i.id = invoice_id
      and i.status = 'draft'
      and public.has_org_role(
        i.organization_id,
        array['owner', 'admin', 'bookkeeper']::public.organization_role[]
      )
  )
);

create policy "bills_select_members" on public.bills
for select using (public.is_org_member(organization_id));
create policy "bills_insert_bookkeepers" on public.bills
for insert with check (
  public.has_org_role(organization_id, array['owner', 'admin', 'bookkeeper']::public.organization_role[])
);
create policy "bills_update_bookkeepers" on public.bills
for update using (
  public.has_org_role(organization_id, array['owner', 'admin', 'bookkeeper']::public.organization_role[])
) with check (
  public.has_org_role(organization_id, array['owner', 'admin', 'bookkeeper']::public.organization_role[])
);
create policy "bills_delete_admins" on public.bills
for delete using (
  status = 'draft'
  and public.has_org_role(organization_id, array['owner', 'admin']::public.organization_role[])
);

create policy "bill_items_select_members" on public.bill_items
for select using (
  exists (
    select 1 from public.bills b
    where b.id = bill_id and public.is_org_member(b.organization_id)
  )
);
create policy "bill_items_insert_bookkeepers" on public.bill_items
for insert with check (
  exists (
    select 1 from public.bills b
    where b.id = bill_id
      and b.status = 'draft'
      and public.has_org_role(
        b.organization_id,
        array['owner', 'admin', 'bookkeeper']::public.organization_role[]
      )
  )
);
create policy "bill_items_update_bookkeepers" on public.bill_items
for update using (
  exists (
    select 1 from public.bills b
    where b.id = bill_id
      and b.status = 'draft'
      and public.has_org_role(
        b.organization_id,
        array['owner', 'admin', 'bookkeeper']::public.organization_role[]
      )
  )
) with check (
  exists (
    select 1 from public.bills b
    where b.id = bill_id
      and b.status = 'draft'
      and public.has_org_role(
        b.organization_id,
        array['owner', 'admin', 'bookkeeper']::public.organization_role[]
      )
  )
);
create policy "bill_items_delete_bookkeepers" on public.bill_items
for delete using (
  exists (
    select 1 from public.bills b
    where b.id = bill_id
      and b.status = 'draft'
      and public.has_org_role(
        b.organization_id,
        array['owner', 'admin', 'bookkeeper']::public.organization_role[]
      )
  )
);

commit;
