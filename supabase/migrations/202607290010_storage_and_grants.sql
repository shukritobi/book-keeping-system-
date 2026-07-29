-- LedgerMY migration segment
begin;

-- Private Supabase Storage bucket with tenant path isolation.
insert into storage.buckets (
  id, name, public, file_size_limit, allowed_mime_types
)
values (
  'documents',
  'documents',
  false,
  10485760,
  array[
    'application/pdf',
    'image/jpeg',
    'image/png',
    'image/webp',
    'text/csv',
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
  ]
)
on conflict (id) do update set
  public = false,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

create policy "storage_documents_select_members"
on storage.objects for select
using (
  bucket_id = 'documents'
  and public.is_org_member(public.safe_uuid((storage.foldername(name))[1]))
);

create policy "storage_documents_insert_bookkeepers"
on storage.objects for insert
with check (
  bucket_id = 'documents'
  and public.has_org_role(
    public.safe_uuid((storage.foldername(name))[1]),
    array['owner', 'admin', 'bookkeeper']::public.organization_role[]
  )
);

create policy "storage_documents_update_bookkeepers"
on storage.objects for update
using (
  bucket_id = 'documents'
  and public.has_org_role(
    public.safe_uuid((storage.foldername(name))[1]),
    array['owner', 'admin', 'bookkeeper']::public.organization_role[]
  )
)
with check (
  bucket_id = 'documents'
  and public.has_org_role(
    public.safe_uuid((storage.foldername(name))[1]),
    array['owner', 'admin', 'bookkeeper']::public.organization_role[]
  )
);

create policy "storage_documents_delete_bookkeepers"
on storage.objects for delete
using (
  bucket_id = 'documents'
  and public.has_org_role(
    public.safe_uuid((storage.foldername(name))[1]),
    array['owner', 'admin', 'bookkeeper']::public.organization_role[]
  )
);

-- Least-privilege grants.
revoke all on public.audit_logs from anon, authenticated;
grant select on public.audit_logs to authenticated;

revoke execute on function public.create_organization(text, text) from public;
revoke execute on function public.create_manual_journal(uuid, date, text, text, uuid, uuid, numeric) from public;
revoke execute on function public.post_journal_entry(uuid) from public;
revoke execute on function public.create_simple_invoice(uuid, uuid, date, date, text, numeric, numeric, numeric, uuid, text) from public;
revoke execute on function public.issue_invoice(uuid) from public;
revoke execute on function public.create_simple_bill(uuid, uuid, date, date, text, text, numeric, numeric, numeric, uuid, text) from public;
revoke execute on function public.approve_bill(uuid) from public;
revoke execute on function public.record_invoice_payment(uuid, uuid, date, numeric, text) from public;
revoke execute on function public.record_bill_payment(uuid, uuid, date, numeric, text) from public;
revoke execute on function public.trial_balance(uuid, date, date) from public;
revoke execute on function public.profit_and_loss(uuid, date, date) from public;
revoke execute on function public.balance_sheet(uuid, date) from public;
revoke execute on function public.get_dashboard_metrics(uuid) from public;

grant execute on function public.create_organization(text, text) to authenticated;
grant execute on function public.create_manual_journal(uuid, date, text, text, uuid, uuid, numeric) to authenticated;
grant execute on function public.post_journal_entry(uuid) to authenticated;
grant execute on function public.create_simple_invoice(uuid, uuid, date, date, text, numeric, numeric, numeric, uuid, text) to authenticated;
grant execute on function public.issue_invoice(uuid) to authenticated;
grant execute on function public.create_simple_bill(uuid, uuid, date, date, text, text, numeric, numeric, numeric, uuid, text) to authenticated;
grant execute on function public.approve_bill(uuid) to authenticated;
grant execute on function public.record_invoice_payment(uuid, uuid, date, numeric, text) to authenticated;
grant execute on function public.record_bill_payment(uuid, uuid, date, numeric, text) to authenticated;
grant execute on function public.trial_balance(uuid, date, date) to authenticated;
grant execute on function public.profit_and_loss(uuid, date, date) to authenticated;
grant execute on function public.balance_sheet(uuid, date) to authenticated;
grant execute on function public.get_dashboard_metrics(uuid) to authenticated;

revoke execute on function public.seed_default_accounts(uuid) from public;
revoke execute on function public.handle_new_user() from public;
revoke execute on function public.audit_row_change() from public;
revoke execute on function public.protect_journal_entry() from public;
revoke execute on function public.protect_journal_line() from public;
revoke execute on function public.recalculate_journal_totals() from public;

grant usage on schema public to authenticated;
grant select, update on public.profiles to authenticated;
grant select on public.organizations to authenticated;
grant select on public.organization_members to authenticated;
grant select, insert on public.accounts to authenticated;
grant select, insert on public.contacts to authenticated;
grant select on public.document_sequences to authenticated;
grant select on public.journal_entries, public.journal_lines to authenticated;
grant select on public.invoices, public.invoice_items, public.bills, public.bill_items to authenticated;
grant select on public.payments, public.payment_allocations to authenticated;
grant select, insert on public.bank_accounts to authenticated;
grant select, insert, update on public.bank_transactions to authenticated;
grant select, insert, delete on public.reconciliation_matches to authenticated;
grant select, insert, delete on public.documents to authenticated;
grant select, insert, delete on public.fiscal_locks to authenticated;
grant usage, select on all sequences in schema public to authenticated;

commit;
