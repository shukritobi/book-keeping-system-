# Testing Strategy

## Required test layers

### Database integrity tests

Test directly against a temporary Supabase database:

- a journal with unequal debit and credit cannot post
- a one-line journal cannot post
- a posted journal cannot be updated or deleted
- posted journal lines cannot be changed
- a locked date rejects a new journal
- accounts from another organization cannot be used
- invoice issue creates the correct journal
- bill approval creates the correct journal
- customer payment reduces receivable
- supplier payment reduces payable
- RLS blocks cross-organization reads and writes
- viewers cannot write
- audit events are created
- document storage policies reject another organization's folder

### Application tests

- signup, confirmation, login, logout
- onboarding
- account and contact creation
- journal draft and post
- invoice issue and payment
- bill approval and payment
- document upload, signed view, and delete
- report date filtering
- protected-route redirects

### Security tests

- open redirect attempts
- tampered organization IDs
- direct table writes to protected accounting tables
- malformed storage folder UUIDs
- oversized and disallowed file types
- expired document links
- privilege escalation attempts
- session expiry and revoked sessions

## CI

The included workflow installs dependencies, runs ESLint, runs TypeScript checking, and builds the Next.js application. Add a Supabase service container or disposable project for database tests before treating CI as a full accounting-integrity gate.
