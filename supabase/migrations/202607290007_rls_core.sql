-- LedgerMY migration segment
begin;

-- Row-level security.
alter table public.profiles enable row level security;
alter table public.organizations enable row level security;
alter table public.organization_members enable row level security;
alter table public.accounts enable row level security;
alter table public.contacts enable row level security;
alter table public.document_sequences enable row level security;
alter table public.journal_entries enable row level security;
alter table public.journal_lines enable row level security;
alter table public.invoices enable row level security;
alter table public.invoice_items enable row level security;
alter table public.bills enable row level security;
alter table public.bill_items enable row level security;
alter table public.bank_accounts enable row level security;
alter table public.payments enable row level security;
alter table public.payment_allocations enable row level security;
alter table public.bank_transactions enable row level security;
alter table public.reconciliation_matches enable row level security;
alter table public.documents enable row level security;
alter table public.fiscal_locks enable row level security;
alter table public.audit_logs enable row level security;

create policy "profiles_select_self" on public.profiles
for select using (id = auth.uid());
create policy "profiles_update_self" on public.profiles
for update using (id = auth.uid()) with check (id = auth.uid());

create policy "organizations_select_members" on public.organizations
for select using (public.is_org_member(id));
create policy "organizations_update_admins" on public.organizations
for update using (
  public.has_org_role(id, array['owner', 'admin']::public.organization_role[])
) with check (
  public.has_org_role(id, array['owner', 'admin']::public.organization_role[])
);

create policy "members_select_org" on public.organization_members
for select using (public.is_org_member(organization_id));
create policy "members_insert_owner" on public.organization_members
for insert with check (
  public.has_org_role(organization_id, array['owner']::public.organization_role[])
);
create policy "members_update_owner" on public.organization_members
for update using (
  public.has_org_role(organization_id, array['owner']::public.organization_role[])
) with check (
  public.has_org_role(organization_id, array['owner']::public.organization_role[])
);
create policy "members_delete_owner" on public.organization_members
for delete using (
  public.has_org_role(organization_id, array['owner']::public.organization_role[])
  and role <> 'owner'
);

create policy "accounts_select_members" on public.accounts
for select using (public.is_org_member(organization_id));
create policy "accounts_insert_bookkeepers" on public.accounts
for insert with check (
  public.has_org_role(organization_id, array['owner', 'admin', 'bookkeeper']::public.organization_role[])
);
create policy "accounts_update_bookkeepers" on public.accounts
for update using (
  public.has_org_role(organization_id, array['owner', 'admin', 'bookkeeper']::public.organization_role[])
) with check (
  public.has_org_role(organization_id, array['owner', 'admin', 'bookkeeper']::public.organization_role[])
);

create policy "contacts_select_members" on public.contacts
for select using (public.is_org_member(organization_id));
create policy "contacts_insert_bookkeepers" on public.contacts
for insert with check (
  public.has_org_role(organization_id, array['owner', 'admin', 'bookkeeper']::public.organization_role[])
);
create policy "contacts_update_bookkeepers" on public.contacts
for update using (
  public.has_org_role(organization_id, array['owner', 'admin', 'bookkeeper']::public.organization_role[])
) with check (
  public.has_org_role(organization_id, array['owner', 'admin', 'bookkeeper']::public.organization_role[])
);
create policy "contacts_delete_admins" on public.contacts
for delete using (
  public.has_org_role(organization_id, array['owner', 'admin']::public.organization_role[])
);

create policy "sequences_select_members" on public.document_sequences
for select using (public.is_org_member(organization_id));

create policy "journals_select_members" on public.journal_entries
for select using (public.is_org_member(organization_id));
create policy "journals_insert_bookkeepers" on public.journal_entries
for insert with check (
  public.has_org_role(organization_id, array['owner', 'admin', 'bookkeeper']::public.organization_role[])
);
create policy "journals_update_bookkeepers" on public.journal_entries
for update using (
  public.has_org_role(organization_id, array['owner', 'admin', 'bookkeeper']::public.organization_role[])
) with check (
  public.has_org_role(organization_id, array['owner', 'admin', 'bookkeeper']::public.organization_role[])
);
create policy "journals_delete_bookkeepers" on public.journal_entries
for delete using (
  public.has_org_role(organization_id, array['owner', 'admin', 'bookkeeper']::public.organization_role[])
);

create policy "journal_lines_select_members" on public.journal_lines
for select using (
  exists (
    select 1 from public.journal_entries je
    where je.id = journal_entry_id
      and public.is_org_member(je.organization_id)
  )
);
create policy "journal_lines_insert_bookkeepers" on public.journal_lines
for insert with check (
  exists (
    select 1 from public.journal_entries je
    where je.id = journal_entry_id
      and public.has_org_role(
        je.organization_id,
        array['owner', 'admin', 'bookkeeper']::public.organization_role[]
      )
  )
);
create policy "journal_lines_update_bookkeepers" on public.journal_lines
for update using (
  exists (
    select 1 from public.journal_entries je
    where je.id = journal_entry_id
      and public.has_org_role(
        je.organization_id,
        array['owner', 'admin', 'bookkeeper']::public.organization_role[]
      )
  )
) with check (
  exists (
    select 1 from public.journal_entries je
    where je.id = journal_entry_id
      and public.has_org_role(
        je.organization_id,
        array['owner', 'admin', 'bookkeeper']::public.organization_role[]
      )
  )
);
create policy "journal_lines_delete_bookkeepers" on public.journal_lines
for delete using (
  exists (
    select 1 from public.journal_entries je
    where je.id = journal_entry_id
      and public.has_org_role(
        je.organization_id,
        array['owner', 'admin', 'bookkeeper']::public.organization_role[]
      )
  )
);

commit;
