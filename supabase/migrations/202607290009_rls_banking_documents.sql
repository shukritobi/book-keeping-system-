-- LedgerMY migration segment
begin;

create policy "bank_accounts_select_members" on public.bank_accounts
for select using (public.is_org_member(organization_id));
create policy "bank_accounts_insert_bookkeepers" on public.bank_accounts
for insert with check (
  public.has_org_role(organization_id, array['owner', 'admin', 'bookkeeper']::public.organization_role[])
);
create policy "bank_accounts_update_bookkeepers" on public.bank_accounts
for update using (
  public.has_org_role(organization_id, array['owner', 'admin', 'bookkeeper']::public.organization_role[])
) with check (
  public.has_org_role(organization_id, array['owner', 'admin', 'bookkeeper']::public.organization_role[])
);


create policy "payments_select_members" on public.payments
for select using (public.is_org_member(organization_id));

create policy "payment_allocations_select_members" on public.payment_allocations
for select using (
  exists (
    select 1 from public.payments p
    where p.id = payment_id and public.is_org_member(p.organization_id)
  )
);

create policy "bank_transactions_select_members" on public.bank_transactions
for select using (public.is_org_member(organization_id));
create policy "bank_transactions_insert_bookkeepers" on public.bank_transactions
for insert with check (
  public.has_org_role(organization_id, array['owner', 'admin', 'bookkeeper']::public.organization_role[])
);
create policy "bank_transactions_update_bookkeepers" on public.bank_transactions
for update using (
  public.has_org_role(organization_id, array['owner', 'admin', 'bookkeeper']::public.organization_role[])
) with check (
  public.has_org_role(organization_id, array['owner', 'admin', 'bookkeeper']::public.organization_role[])
);

create policy "matches_select_members" on public.reconciliation_matches
for select using (public.is_org_member(organization_id));
create policy "matches_insert_bookkeepers" on public.reconciliation_matches
for insert with check (
  public.has_org_role(organization_id, array['owner', 'admin', 'bookkeeper']::public.organization_role[])
);
create policy "matches_delete_bookkeepers" on public.reconciliation_matches
for delete using (
  public.has_org_role(organization_id, array['owner', 'admin', 'bookkeeper']::public.organization_role[])
);

create policy "documents_select_members" on public.documents
for select using (public.is_org_member(organization_id));
create policy "documents_insert_bookkeepers" on public.documents
for insert with check (
  uploaded_by = auth.uid()
  and public.has_org_role(
    organization_id,
    array['owner', 'admin', 'bookkeeper']::public.organization_role[]
  )
);
create policy "documents_delete_bookkeepers" on public.documents
for delete using (
  public.has_org_role(
    organization_id,
    array['owner', 'admin', 'bookkeeper']::public.organization_role[]
  )
);

create policy "fiscal_locks_select_members" on public.fiscal_locks
for select using (public.is_org_member(organization_id));
create policy "fiscal_locks_insert_admins" on public.fiscal_locks
for insert with check (
  public.has_org_role(organization_id, array['owner', 'admin']::public.organization_role[])
);
create policy "fiscal_locks_delete_owner" on public.fiscal_locks
for delete using (
  public.has_org_role(organization_id, array['owner']::public.organization_role[])
);

create policy "audit_logs_select_admins" on public.audit_logs
for select using (
  public.has_org_role(organization_id, array['owner', 'admin']::public.organization_role[])
);

commit;
