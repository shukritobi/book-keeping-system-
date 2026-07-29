import Link from "next/link";
import {
  Landmark,
  LayoutDashboard,
  BookOpen,
  Users,
  ReceiptText,
  FileOutput,
  Building2,
  FolderLock,
  ChartNoAxesCombined,
  Settings,
  WalletCards,
} from "lucide-react";
import type { ActiveOrganization } from "@/lib/organization";

const navigation = [
  ["/dashboard", "Dashboard", LayoutDashboard],
  ["/accounts", "Chart of accounts", BookOpen],
  ["/contacts", "Contacts", Users],
  ["/journals", "Journals", ReceiptText],
  ["/invoices", "Invoices", FileOutput],
  ["/bills", "Bills", WalletCards],
  ["/banking", "Banking", Building2],
  ["/documents", "Documents", FolderLock],
  ["/reports", "Reports", ChartNoAxesCombined],
  ["/settings", "Settings", Settings],
] as const;

export function Sidebar({
  organization,
  role,
}: {
  organization: ActiveOrganization;
  role: string;
}) {
  return (
    <aside className="sidebar">
      <Link className="brand-mark" href="/dashboard">
        <span className="brand-dot"><Landmark size={18} /></span>
        LedgerMY
      </Link>

      <div className="organization-chip">
        <strong>{organization.name}</strong>
        <span>{role}</span>
      </div>

      <nav className="nav" aria-label="Primary navigation">
        {navigation.map(([href, label, Icon]) => (
          <Link key={href} href={href}>
            <Icon size={17} />
            {label}
          </Link>
        ))}
      </nav>

      <div className="sidebar-footer">
        MYR base currency<br />
        Double-entry ledger
      </div>
    </aside>
  );
}
