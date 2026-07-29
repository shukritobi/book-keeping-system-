"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { requireOrganization } from "@/lib/organization";
import { ACCOUNT_TYPES, CONTACT_TYPES } from "@/lib/constants";
import { positiveMoney } from "@/lib/validation";

function redirectWith(path: string, key: "error" | "message", value: string): never {
  const query = new URLSearchParams({ [key]: value });
  redirect(`${path}?${query.toString()}`);
}

function text(formData: FormData, key: string, max = 255) {
  return String(formData.get(key) ?? "").trim().slice(0, max);
}

function optionalText(formData: FormData, key: string, max = 255) {
  const value = text(formData, key, max);
  return value || null;
}

function dateValue(formData: FormData, key: string) {
  const value = text(formData, key, 10);
  return /^\d{4}-\d{2}-\d{2}$/.test(value) ? value : null;
}

export async function createAccount(formData: FormData) {
  const { supabase, organization } = await requireOrganization();
  const code = text(formData, "code", 20);
  const name = text(formData, "name", 120);
  const type = text(formData, "type", 20);

  if (!code || !name || !ACCOUNT_TYPES.includes(type as (typeof ACCOUNT_TYPES)[number])) {
    redirectWith("/accounts", "error", "Enter a valid account code, name, and type.");
  }

  const { error } = await supabase.from("accounts").insert({
    organization_id: organization.id,
    code,
    name,
    type,
    subtype: optionalText(formData, "subtype", 60),
    description: optionalText(formData, "description", 500),
  });

  if (error) redirectWith("/accounts", "error", error.message);
  revalidatePath("/accounts");
  redirectWith("/accounts", "message", "Account created.");
}

export async function createContact(formData: FormData) {
  const { supabase, organization } = await requireOrganization();
  const name = text(formData, "name", 160);
  const contactType = text(formData, "contact_type", 20);

  if (!name || !CONTACT_TYPES.includes(contactType as (typeof CONTACT_TYPES)[number])) {
    redirectWith("/contacts", "error", "Enter a contact name and valid contact type.");
  }

  const { error } = await supabase.from("contacts").insert({
    organization_id: organization.id,
    name,
    contact_type: contactType,
    email: optionalText(formData, "email", 254),
    phone: optionalText(formData, "phone", 40),
    registration_number: optionalText(formData, "registration_number", 80),
    tax_number: optionalText(formData, "tax_number", 80),
    address: optionalText(formData, "address", 500),
  });

  if (error) redirectWith("/contacts", "error", error.message);
  revalidatePath("/contacts");
  redirectWith("/contacts", "message", "Contact created.");
}

export async function createManualJournal(formData: FormData) {
  const { supabase, organization } = await requireOrganization();
  const amountResult = positiveMoney.safeParse(formData.get("amount"));
  const entryDate = dateValue(formData, "entry_date");
  const debitAccount = text(formData, "debit_account_id", 36);
  const creditAccount = text(formData, "credit_account_id", 36);
  const description = text(formData, "description", 500);

  if (
    !amountResult.success ||
    !entryDate ||
    !debitAccount ||
    !creditAccount ||
    debitAccount === creditAccount ||
    !description
  ) {
    redirectWith("/journals", "error", "Complete the journal with two different accounts and a positive amount.");
  }

  const { data, error } = await supabase.rpc("create_manual_journal", {
    p_organization_id: organization.id,
    p_entry_date: entryDate,
    p_reference: optionalText(formData, "reference", 80),
    p_description: description,
    p_debit_account_id: debitAccount,
    p_credit_account_id: creditAccount,
    p_amount: amountResult.data,
  });

  if (error) redirectWith("/journals", "error", error.message);

  if (formData.get("post_now") === "on") {
    const { error: postError } = await supabase.rpc("post_journal_entry", {
      p_journal_entry_id: data,
    });
    if (postError) redirectWith("/journals", "error", `Draft saved, but posting failed: ${postError.message}`);
  }

  revalidatePath("/journals");
  revalidatePath("/dashboard");
  redirectWith("/journals", "message", "Journal entry created.");
}

export async function postJournal(formData: FormData) {
  const { supabase } = await requireOrganization();
  const id = text(formData, "journal_entry_id", 36);
  const { error } = await supabase.rpc("post_journal_entry", { p_journal_entry_id: id });
  if (error) redirectWith("/journals", "error", error.message);
  revalidatePath("/journals");
  revalidatePath("/dashboard");
  redirectWith("/journals", "message", "Journal posted.");
}

export async function createInvoice(formData: FormData) {
  const { supabase, organization } = await requireOrganization();
  const amountResult = positiveMoney.safeParse(formData.get("unit_price"));
  const quantityResult = positiveMoney.safeParse(formData.get("quantity"));
  const issueDate = dateValue(formData, "issue_date");
  const dueDate = dateValue(formData, "due_date");

  if (!amountResult.success || !quantityResult.success || !issueDate || !dueDate) {
    redirectWith("/invoices", "error", "Enter valid dates, quantity, and price.");
  }

  const { error } = await supabase.rpc("create_simple_invoice", {
    p_organization_id: organization.id,
    p_contact_id: text(formData, "contact_id", 36),
    p_issue_date: issueDate,
    p_due_date: dueDate,
    p_description: text(formData, "description", 300),
    p_quantity: quantityResult.data,
    p_unit_price: amountResult.data,
    p_tax_rate: Number(formData.get("tax_rate") ?? 0),
    p_revenue_account_id: text(formData, "revenue_account_id", 36),
    p_notes: optionalText(formData, "notes", 1000),
  });

  if (error) redirectWith("/invoices", "error", error.message);
  revalidatePath("/invoices");
  redirectWith("/invoices", "message", "Draft invoice created.");
}

export async function issueInvoice(formData: FormData) {
  const { supabase } = await requireOrganization();
  const { error } = await supabase.rpc("issue_invoice", {
    p_invoice_id: text(formData, "invoice_id", 36),
  });
  if (error) redirectWith("/invoices", "error", error.message);
  revalidatePath("/invoices");
  revalidatePath("/dashboard");
  redirectWith("/invoices", "message", "Invoice issued and posted to the ledger.");
}

export async function createBill(formData: FormData) {
  const { supabase, organization } = await requireOrganization();
  const amountResult = positiveMoney.safeParse(formData.get("unit_price"));
  const quantityResult = positiveMoney.safeParse(formData.get("quantity"));
  const billDate = dateValue(formData, "bill_date");
  const dueDate = dateValue(formData, "due_date");

  if (!amountResult.success || !quantityResult.success || !billDate || !dueDate) {
    redirectWith("/bills", "error", "Enter valid dates, quantity, and price.");
  }

  const { error } = await supabase.rpc("create_simple_bill", {
    p_organization_id: organization.id,
    p_contact_id: text(formData, "contact_id", 36),
    p_bill_date: billDate,
    p_due_date: dueDate,
    p_supplier_reference: optionalText(formData, "supplier_reference", 100),
    p_description: text(formData, "description", 300),
    p_quantity: quantityResult.data,
    p_unit_price: amountResult.data,
    p_tax_rate: Number(formData.get("tax_rate") ?? 0),
    p_expense_account_id: text(formData, "expense_account_id", 36),
    p_notes: optionalText(formData, "notes", 1000),
  });

  if (error) redirectWith("/bills", "error", error.message);
  revalidatePath("/bills");
  redirectWith("/bills", "message", "Draft bill created.");
}

export async function approveBill(formData: FormData) {
  const { supabase } = await requireOrganization();
  const { error } = await supabase.rpc("approve_bill", {
    p_bill_id: text(formData, "bill_id", 36),
  });
  if (error) redirectWith("/bills", "error", error.message);
  revalidatePath("/bills");
  revalidatePath("/dashboard");
  redirectWith("/bills", "message", "Bill approved and posted to the ledger.");
}


export async function recordInvoicePayment(formData: FormData) {
  const { supabase } = await requireOrganization();
  const amountResult = positiveMoney.safeParse(formData.get("amount"));
  const paymentDate = dateValue(formData, "payment_date");

  if (!amountResult.success || !paymentDate) {
    redirectWith("/invoices", "error", "Enter a valid payment date and amount.");
  }

  const { error } = await supabase.rpc("record_invoice_payment", {
    p_invoice_id: text(formData, "invoice_id", 36),
    p_bank_account_id: text(formData, "bank_account_id", 36),
    p_payment_date: paymentDate,
    p_amount: amountResult.data,
    p_reference: optionalText(formData, "reference", 100),
  });

  if (error) redirectWith("/invoices", "error", error.message);
  revalidatePath("/invoices");
  revalidatePath("/banking");
  revalidatePath("/dashboard");
  redirectWith("/invoices", "message", "Customer payment recorded.");
}

export async function recordBillPayment(formData: FormData) {
  const { supabase } = await requireOrganization();
  const amountResult = positiveMoney.safeParse(formData.get("amount"));
  const paymentDate = dateValue(formData, "payment_date");

  if (!amountResult.success || !paymentDate) {
    redirectWith("/bills", "error", "Enter a valid payment date and amount.");
  }

  const { error } = await supabase.rpc("record_bill_payment", {
    p_bill_id: text(formData, "bill_id", 36),
    p_bank_account_id: text(formData, "bank_account_id", 36),
    p_payment_date: paymentDate,
    p_amount: amountResult.data,
    p_reference: optionalText(formData, "reference", 100),
  });

  if (error) redirectWith("/bills", "error", error.message);
  revalidatePath("/bills");
  revalidatePath("/banking");
  revalidatePath("/dashboard");
  redirectWith("/bills", "message", "Supplier payment recorded.");
}

export async function createBankAccount(formData: FormData) {
  const { supabase, organization } = await requireOrganization();
  const name = text(formData, "name", 120);
  const accountId = text(formData, "account_id", 36);

  if (!name || !accountId) redirectWith("/banking", "error", "Choose a ledger account and enter a bank account name.");

  const { error } = await supabase.from("bank_accounts").insert({
    organization_id: organization.id,
    account_id: accountId,
    name,
    bank_name: optionalText(formData, "bank_name", 120),
    masked_number: optionalText(formData, "masked_number", 30),
    currency: organization.base_currency,
    opening_balance: Number(formData.get("opening_balance") ?? 0),
  });

  if (error) redirectWith("/banking", "error", error.message);
  revalidatePath("/banking");
  redirectWith("/banking", "message", "Bank account connected to the ledger.");
}

export async function createFiscalLock(formData: FormData) {
  const { supabase, organization } = await requireOrganization();
  const lockDate = dateValue(formData, "lock_date");
  if (!lockDate) redirectWith("/settings", "error", "Enter a valid lock date.");

  const { error } = await supabase.from("fiscal_locks").insert({
    organization_id: organization.id,
    lock_date: lockDate,
    reason: optionalText(formData, "reason", 300),
  });

  if (error) redirectWith("/settings", "error", error.message);
  revalidatePath("/settings");
  redirectWith("/settings", "message", `Books locked through ${lockDate}.`);
}
