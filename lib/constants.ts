export const ACCOUNT_TYPES = ["asset", "liability", "equity", "income", "expense"] as const;
export const CONTACT_TYPES = ["customer", "supplier", "both"] as const;

export const MAX_DOCUMENT_SIZE = 10 * 1024 * 1024;
export const ALLOWED_DOCUMENT_TYPES = new Set([
  "application/pdf",
  "image/jpeg",
  "image/png",
  "image/webp",
  "text/csv",
  "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
]);
