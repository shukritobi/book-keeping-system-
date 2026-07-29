import { logout } from "@/app/actions/auth";
import { Sidebar } from "@/components/sidebar";
import { requireOrganization } from "@/lib/organization";

export default async function WorkspaceLayout({ children }: { children: React.ReactNode }) {
  const { user, organization, role } = await requireOrganization();
  const initial = (user.email?.[0] ?? "U").toUpperCase();

  return (
    <div className="app-shell">
      <Sidebar organization={organization} role={role} />
      <div className="main">
        <header className="topbar">
          <div>
            <strong>{organization.name}</strong>
            <div className="muted caption">Financial workspace</div>
          </div>
          <div className="topbar-user">
            <span className="avatar">{initial}</span>
            <div>
              <strong className="caption">{user.email}</strong>
              <form action={logout}>
                <button className="link" style={{ border: 0, background: "transparent", padding: 0 }} type="submit">
                  Sign out
                </button>
              </form>
            </div>
          </div>
        </header>
        <main className="page">{children}</main>
      </div>
    </div>
  );
}
