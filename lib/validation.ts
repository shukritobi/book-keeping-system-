import { z } from "zod";

export const loginSchema = z.object({
  email: z.email().max(254),
  password: z.string().min(8).max(128),
});

export const organizationSchema = z.object({
  name: z.string().trim().min(2).max(120),
  slug: z.string().trim().toLowerCase().min(2).max(60)
    .regex(/^[a-z0-9]+(?:-[a-z0-9]+)*$/),
});

export const positiveMoney = z.coerce.number().positive().max(999_999_999.99);
