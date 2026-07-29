import { redirect } from "next/navigation";
import { requireUser } from "@/lib/auth";

export type ActiveOrganization = {
  id: string;
  name: string;
  slug: string;
  base_currency: string;
  fiscal_year_start: number;
};

export async function requireOrganization() {
  const { supabase, user } = await requireUser();
  const { data, error } = await supabase
    .from("organization_members")
    .select("organization_id, role, organizations!inner(id, name, slug, base_currency, fiscal_year_start)")
    .eq("user_id", user.id)
    .order("created_at", { ascending: true })
    .limit(1)
    .maybeSingle();

  if (error) throw new Error(`Unable to load organization: ${error.message}`);
  if (!data) redirect("/onboarding");

  const relation = data.organizations as unknown;
  const organization = (Array.isArray(relation) ? relation[0] : relation) as ActiveOrganization;
  if (!organization) redirect("/onboarding");

  return {
    supabase,
    user,
    organization,
    role: data.role as "owner" | "admin" | "bookkeeper" | "viewer",
  };
}
