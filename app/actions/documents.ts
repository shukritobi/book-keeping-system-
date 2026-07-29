"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { ALLOWED_DOCUMENT_TYPES, MAX_DOCUMENT_SIZE } from "@/lib/constants";
import { requireOrganization } from "@/lib/organization";

function redirectWith(key: "error" | "message", value: string): never {
  const query = new URLSearchParams({ [key]: value });
  redirect(`/documents?${query.toString()}`);
}

function safeFileName(name: string) {
  return name
    .normalize("NFKD")
    .replace(/[^\w.\-]+/g, "-")
    .replace(/-{2,}/g, "-")
    .slice(0, 120);
}

export async function uploadDocument(formData: FormData) {
  const { supabase, organization, user } = await requireOrganization();
  const file = formData.get("file");

  if (!(file instanceof File) || file.size === 0) redirectWith("error", "Choose a document to upload.");
  if (file.size > MAX_DOCUMENT_SIZE) redirectWith("error", "The maximum file size is 10 MB.");
  if (!ALLOWED_DOCUMENT_TYPES.has(file.type)) {
    redirectWith("error", "Allowed files: PDF, JPG, PNG, WebP, CSV, and XLSX.");
  }

  const fileName = safeFileName(file.name) || "document";
  const storagePath = `${organization.id}/${crypto.randomUUID()}-${fileName}`;
  const { error: uploadError } = await supabase.storage
    .from("documents")
    .upload(storagePath, file, {
      cacheControl: "3600",
      contentType: file.type,
      upsert: false,
    });

  if (uploadError) redirectWith("error", uploadError.message);

  const { error: insertError } = await supabase.from("documents").insert({
    organization_id: organization.id,
    uploaded_by: user.id,
    name: (String(formData.get("name") ?? "").trim() || file.name).slice(0, 180),
    category: String(formData.get("category") ?? "other").slice(0, 40),
    storage_path: storagePath,
    mime_type: file.type,
    size_bytes: file.size,
    linked_entity_type: null,
    linked_entity_id: null,
  });

  if (insertError) {
    await supabase.storage.from("documents").remove([storagePath]);
    redirectWith("error", insertError.message);
  }

  revalidatePath("/documents");
  redirectWith("message", "Document uploaded securely.");
}

export async function deleteDocument(formData: FormData) {
  const { supabase, organization } = await requireOrganization();
  const documentId = String(formData.get("document_id") ?? "");
  const { data, error } = await supabase
    .from("documents")
    .select("storage_path")
    .eq("id", documentId)
    .eq("organization_id", organization.id)
    .maybeSingle();

  if (error || !data) redirectWith("error", "Document not found.");

  const { error: storageError } = await supabase.storage.from("documents").remove([data.storage_path]);
  if (storageError) redirectWith("error", storageError.message);

  const { error: deleteError } = await supabase.from("documents").delete().eq("id", documentId);
  if (deleteError) redirectWith("error", deleteError.message);

  revalidatePath("/documents");
  redirectWith("message", "Document deleted.");
}
