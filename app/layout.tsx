import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: { default: "LedgerMY", template: "%s | LedgerMY" },
  description: "Secure multi-company bookkeeping for Malaysian businesses.",
};

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return <html lang="en"><body>{children}</body></html>;
}
