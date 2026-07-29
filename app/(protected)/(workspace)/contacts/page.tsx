import { createContact } from "@/app/actions/accounting";
import { EmptyState } from "@/components/empty-state";
import { PageHeader } from "@/components/page-header";
import { CONTACT_TYPES } from "@/lib/constants";
import { requireOrganization } from "@/lib/organization";

export const metadata = { title: "Contacts" };

export default async function ContactsPage({
  searchParams,
}: {
  searchParams: Promise<{ error?: string; message?: string }>;
}) {
  const { supabase, organization } = await requireOrganization();
  const params = await searchParams;
  const { data: contacts } = await supabase
    .from("contacts")
    .select("id, name, contact_type, email, phone, registration_number")
    .eq("organization_id", organization.id)
    .order("name");

  return (
    <>
      <PageHeader title="Contacts" description="Customers and suppliers used across invoices, bills, and reports." />
      <div className="two-column">
        <section className="card">
          <div className="card-header"><h2>Directory</h2></div>
          {contacts?.length ? (
            <div className="table-wrap">
              <table>
                <thead><tr><th>Name</th><th>Type</th><th>Email</th><th>Phone</th><th>Registration</th></tr></thead>
                <tbody>
                  {contacts.map((contact) => (
                    <tr key={contact.id}>
                      <td>{contact.name}</td>
                      <td><span className="badge">{contact.contact_type}</span></td>
                      <td>{contact.email ?? "—"}</td>
                      <td>{contact.phone ?? "—"}</td>
                      <td>{contact.registration_number ?? "—"}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          ) : <EmptyState title="No contacts yet" description="Add a customer or supplier to begin." />}
        </section>

        <aside className="card">
          <div className="card-header"><h2>Add contact</h2></div>
          <form action={createContact} className="form-stack">
            {params.error ? <div className="alert error">{params.error}</div> : null}
            {params.message ? <div className="alert success">{params.message}</div> : null}
            <div className="field">
              <label htmlFor="name">Name</label>
              <input id="name" name="name" required />
            </div>
            <div className="field">
              <label htmlFor="contact_type">Contact type</label>
              <select id="contact_type" name="contact_type">
                {CONTACT_TYPES.map((type) => <option key={type} value={type}>{type}</option>)}
              </select>
            </div>
            <div className="form-grid">
              <div className="field"><label htmlFor="email">Email</label><input id="email" name="email" type="email" /></div>
              <div className="field"><label htmlFor="phone">Phone</label><input id="phone" name="phone" /></div>
            </div>
            <div className="form-grid">
              <div className="field"><label htmlFor="registration_number">Registration no.</label><input id="registration_number" name="registration_number" /></div>
              <div className="field"><label htmlFor="tax_number">Tax no.</label><input id="tax_number" name="tax_number" /></div>
            </div>
            <div className="field"><label htmlFor="address">Address</label><textarea id="address" name="address" /></div>
            <button className="button" type="submit">Create contact</button>
          </form>
        </aside>
      </div>
    </>
  );
}
