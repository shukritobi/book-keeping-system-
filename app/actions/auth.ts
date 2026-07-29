"use server";

import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { loginSchema } from "@/lib/validation";

function message(path: string, key: "error" | "message", value: string) {
  const query = new URLSearchParams({ [key]: value });
  redirect(`${path}?${query.toString()}`);
}

export async function login(formData: FormData) {
  const parsed = loginSchema.safeParse({
    email: formData.get("email"),
    password: formData.get("password"),
  });

  if (!parsed.success) message("/login", "error", "Enter a valid email and password.");

  const supabase = await createClient();
  const { error } = await supabase.auth.signInWithPassword(parsed.data);

  if (error) message("/login", "error", "Email or password is incorrect.");

  const next = String(formData.get("next") ?? "/dashboard");
  redirect(next.startsWith("/") && !next.startsWith("//") ? next : "/dashboard");
}

export async function signup(formData: FormData) {
  const parsed = loginSchema.safeParse({
    email: formData.get("email"),
    password: formData.get("password"),
  });
  const name = String(formData.get("name") ?? "").trim();

  if (!parsed.success || name.length < 2 || name.length > 120) {
    message("/signup", "error", "Enter your name, a valid email, and a password of at least 8 characters.");
  }

  const supabase = await createClient();
  const { data, error } = await supabase.auth.signUp({
    ...parsed.data,
    options: {
      data: { full_name: name },
      emailRedirectTo: `${process.env.NEXT_PUBLIC_APP_URL}/auth/callback`,
    },
  });

  if (error) message("/signup", "error", error.message);

  if (data.session) redirect("/onboarding");
  message("/login", "message", "Check your email to confirm your account, then sign in.");
}

export async function logout() {
  const supabase = await createClient();
  await supabase.auth.signOut();
  redirect("/login");
}
