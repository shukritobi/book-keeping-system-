# Security Model

## Assets protected

- User sessions and identities
- Organization membership and roles
- Financial journals and reports
- Customer and supplier information
- Invoices, bills, and payments
- Bank transaction data
- Uploaded financial documents
- Audit history

## Primary threats

| Threat | Main control |
|---|---|
| Cross-company data access | PostgreSQL row-level security on every business table |
| Forged or stale sessions | Server-side `getUser()` validation and session refresh proxy |
| Client bypass of bookkeeping rules | Transactional PostgreSQL RPC functions and triggers |
| Editing financial history | Posted-journal immutability and fiscal locks |
| Public document exposure | Private bucket, tenant folder policy, expiring signed links |
| Privilege escalation | Role checks inside security-definer functions and RLS |
| Malicious file uploads | MIME allowlist, 10 MB limit, non-public serving |
| Secret leakage | Publishable key only, no service-role key in the application |
| Missing traceability | Append-only audit table populated by database triggers |
| Duplicate bank imports | Unique external ID and import hash per bank account |

## Authentication

- Supabase Auth manages credentials and email verification.
- Passwords are never stored by the application.
- The Next.js proxy refreshes auth cookies.
- Protected pages and actions call `requireUser()` and `requireOrganization()`.
- Redirect parameters are restricted to local paths.

### Recommended next authentication controls

- TOTP MFA for owner and admin roles
- Reauthentication before membership or fiscal-lock changes
- Login rate limiting and bot protection
- Session/device management
- Optional SSO for larger organizations

## Authorization

Authorization is enforced in two places:

1. Server Actions check an authenticated organization context.
2. PostgreSQL RLS and RPC functions independently validate access.

The database is the final authority. Interface visibility is not considered an access control.

## Database function safety

Accounting RPC functions use `SECURITY DEFINER` with an explicit `search_path = public`. Each user-callable function checks membership and role before writing.

Internal helper functions that could create data are not executable by the public role. Direct authenticated write privileges are intentionally withheld from journal, invoice, bill, payment, and allocation tables. Those records must pass through accounting RPC functions.

## Journal integrity

- A line must contain either a debit or a credit, never both.
- Amounts cannot be negative.
- Journal totals are recalculated by trigger.
- Posting checks that debits equal credits.
- Posted entries reject update and delete operations.
- Journal lines of posted entries reject changes.
- Locked periods reject creation or modification.

A future correction workflow should create linked reversal entries.

## Storage security

The `documents` bucket is private.

Policies check:

- bucket name is `documents`
- first folder is a valid UUID
- current user belongs to that organization
- writes require owner, admin, or bookkeeper

The interface generates signed URLs that expire after 300 seconds. File type and file size are checked both by the application and bucket configuration.

### Recommended production file controls

- Malware scanning after upload
- Quarantine state before a document becomes available
- Content-disposition headers for risky formats
- Image metadata stripping when appropriate
- Retention and legal-hold policies
- Backup validation for stored files

## Audit trail

Triggers write insert, update, and delete events to `audit_logs`. Authenticated users have no direct write privilege on this table. Owners and admins can read company audit records through RLS.

For stronger assurance at scale, stream audit events to an external append-only log or SIEM.

## HTTP controls

The Next.js configuration adds:

- `X-Content-Type-Options: nosniff`
- `X-Frame-Options: DENY`
- strict referrer policy
- restrictive permissions policy
- cross-origin opener and resource policies
- disabled framework-powered header

A deployment-specific Content Security Policy should be added after the exact production domains are known.

## Operational controls required before launch

- HTTPS only
- separate dev, staging, and production environments
- protected production branch
- required CI checks
- daily backups and tested restoration
- point-in-time recovery
- application and database error alerts
- dependency scanning
- regular access review
- incident response procedure
- periodic security testing

## Known gaps in this foundation

- MFA user interface is not yet included.
- Membership invitation and removal flows are not exposed.
- Malware scanning is not included.
- Rate limiting is not included.
- Audit log viewing/export UI is not included.
- Fine-grained approval workflows are not included.
- Data subject export/deletion operations are not included.
