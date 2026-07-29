"use server";

import { redirect } from "next/navigation";
import { requireUser } from "@/lib/auth";
import { organizationSchema } from "@/lib/validation";

export async function createOrganization(formData: FormData) {
  const parsed = organizationSchema.safeParse({
    name: formData.get("name"),
    slug: formData.get("slug"),
  });

  if (!parsed.success) {
    redirect(`/onboarding?error=${encodeURIComponent("Use a valid company name and URL slug.")}`);
  }

  const { supabase } = await requireUser();
  const { error } = await supabase.rpc("create_organization", {
    p_name: parsed.data.name,
    p_slug: parsed.data.slug,
  });

  if (error) redirect(`/onboarding?error=${encodeURIComponent(error.message)}`);
  redirect("/dashboard");
}
