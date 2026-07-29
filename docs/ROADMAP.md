# Product Roadmap

## Foundation delivered

- Secure authentication and tenant isolation
- Role model
- Chart of accounts and contacts
- Double-entry journals
- Sales invoices and customer receipts
- Supplier bills and payments
- Bank account and transaction schema
- Private documents
- Financial reports
- Fiscal locks
- Audit trail

## Phase 1: Production hardening

- Add automated database integration tests
- Add MFA and privileged-action reauthentication
- Add organization invitation and member management
- Add audit log viewer and CSV export
- Add reversing journals and correction references
- Add draft invoice and bill editing with multiple line items
- Add robust error monitoring
- Add backup and restore runbooks
- Add malware scanning for uploads
- Add rate limiting and abuse protection
- Add idempotency keys to all accounting commands

## Phase 2: Daily bookkeeping workflow

- CSV bank statement importer
- Rules-based bank transaction categorization
- Bank reconciliation workspace
- Receipt-to-transaction attachment
- Payment allocation across multiple invoices or bills
- Credit notes and supplier credits
- Customer statements and aging reports
- Accounts payable aging
- General ledger and account drill-down
- Recurring invoices and recurring bills
- PDF invoice rendering and email delivery
- Document search and tags

## Phase 3: Malaysian business support

- Accountant-reviewed SST configuration
- LHDN e-Invoice integration using the latest official requirements
- TIN and registration validation
- Classification and tax-code management
- e-Invoice submission status and retry queue
- Consolidated e-Invoice workflows where applicable
- Malaysian bank CSV presets
- SST and tax-supporting reports
- English and Bahasa Malaysia interface options

## Phase 4: Advanced accounting

- Opening balance import
- Fixed assets and depreciation schedules
- Inventory and cost of goods sold
- Purchase orders and sales quotations
- Multi-currency transactions and realized/unrealized gains
- Budgeting and cash-flow forecasts
- Department, project, and tracking categories
- Accruals, prepayments, and recurring journals
- Month-end close checklist and approval workflow
- Consolidated multi-entity reporting

## Phase 5: Platform and integrations

- Public API with scoped tokens
- Webhooks and event delivery
- Payment gateway integrations
- Payroll integrations
- E-commerce integrations
- Accountant portal
- Mobile receipt capture
- OCR-assisted extraction with mandatory human review
- Background job queue for imports, reports, and e-Invoice submissions
