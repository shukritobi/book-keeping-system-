import { deleteDocument, uploadDocument } from "@/app/actions/documents";
import { EmptyState } from "@/components/empty-state";
import { PageHeader } from "@/components/page-header";
import { requireOrganization } from "@/lib/organization";

export const metadata = { title: "Documents" };

function formatBytes(bytes: number) {
  if (bytes < 1024) return `${bytes} B`;
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
  return `${(bytes / 1024 / 1024).toFixed(1)} MB`;
}

export default async function DocumentsPage({
  searchParams,
}: {
  searchParams: Promise<{ error?: string; message?: string }>;
}) {
  const { supabase, organization } = await requireOrganization();
  const params = await searchParams;
  const { data: documents } = await supabase
    .from("documents")
    .select("id, name, category, storage_path, mime_type, size_bytes, created_at")
    .eq("organization_id", organization.id)
    .order("created_at", { ascending: false });

  const withUrls = await Promise.all(
    (documents ?? []).map(async (document) => {
      const { data } = await supabase.storage
        .from("documents")
        .createSignedUrl(document.storage_path, 300);
      return { ...document, signedUrl: data?.signedUrl ?? null };
    }),
  );

  return (
    <>
      <PageHeader
        title="Secure documents"
        description="Private receipts, invoices, statements, and supporting files. Links expire after five minutes."
      />
      <div className="two-column">
        <section className="card">
          <div className="card-header"><h2>Document vault</h2></div>
          {withUrls.length ? (
            <div className="table-wrap">
              <table>
                <thead><tr><th>Name</th><th>Category</th><th>Type</th><th>Size</th><th>Uploaded</th><th /></tr></thead>
                <tbody>
                  {withUrls.map((document) => (
                    <tr key={document.id}>
                      <td>
                        {document.signedUrl ? (
                          <a className="link" href={document.signedUrl} target="_blank" rel="noreferrer">{document.name}</a>
                        ) : document.name}
                      </td>
                      <td><span className="badge">{document.category}</span></td>
                      <td>{document.mime_type}</td>
                      <td>{formatBytes(document.size_bytes)}</td>
                      <td>{new Date(document.created_at).toLocaleDateString("en-MY")}</td>
                      <td>
                        <form action={deleteDocument}>
                          <input type="hidden" name="document_id" value={document.id} />
                          <button className="button danger small" type="submit">Delete</button>
                        </form>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          ) : <EmptyState title="Your vault is empty" description="Upload a receipt, statement, invoice, or spreadsheet." />}
        </section>

        <aside className="card">
          <div className="card-header"><h2>Upload document</h2></div>
          <form action={uploadDocument} className="form-stack">
            {params.error ? <div className="alert error">{params.error}</div> : null}
            {params.message ? <div className="alert success">{params.message}</div> : null}
            <div className="field"><label htmlFor="name">Document title</label><input id="name" name="name" placeholder="Maybank statement July 2026" /></div>
            <div className="field">
              <label htmlFor="category">Category</label>
              <select id="category" name="category">
                <option value="receipt">Receipt</option>
                <option value="invoice">Sales invoice</option>
                <option value="bill">Supplier bill</option>
                <option value="bank_statement">Bank statement</option>
                <option value="tax">Tax</option>
                <option value="contract">Contract</option>
                <option value="other">Other</option>
              </select>
            </div>
            <div className="field">
              <label htmlFor="file">File</label>
              <input id="file" name="file" type="file" accept=".pdf,.jpg,.jpeg,.png,.webp,.csv,.xlsx" required />
            </div>
            <p className="muted caption">PDF, JPG, PNG, WebP, CSV, or XLSX. Maximum 10 MB.</p>
            <button className="button" type="submit">Upload to private vault</button>
          </form>
        </aside>
      </div>
    </>
  );
}
