import Link from 'next/link';
import { supabaseServer } from '@/lib/supabase/server';
import { formatCourt, aujourdhui } from '@/lib/format';
import type { LigneVetList } from '@/lib/types';

export const dynamic = 'force-dynamic';

export default async function PageChevaux() {
  const supabase = await supabaseServer();
  const { data, error } = await supabase.rpc('vet_list', { date_reference: aujourdhui() });
  const lignes = (data ?? []) as LigneVetList[];

  return (
    <>
      <div className="entete">
        <div>
          <h1>Chevaux</h1>
          <p>{lignes.length} chevaux à l&apos;effectif</p>
        </div>
      </div>

      {error ? (
        <div className="message erreur">{error.message}</div>
      ) : (
        <div className="carte tableau-defilant">
          <table>
            <thead>
              <tr><th /><th>Cheval</th><th>Emplacement</th><th>Statut</th><th>Libre le</th></tr>
            </thead>
            <tbody>
              {lignes.map((l) => (
                <tr key={l.cheval_id}>
                  <td><span className={`pip ${l.peut_courir ? 'libre' : 'bloque'}`} /></td>
                  <td><Link href={`/chevaux/${l.cheval_id}`}>{l.cheval}</Link></td>
                  <td>{l.location ?? '—'}</td>
                  <td>{l.peut_courir ? 'Peut courir' : `Sous délai — ${l.motif ?? ''}`}</td>
                  <td className="num">{l.peut_courir ? '—' : formatCourt(l.libre_le)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </>
  );
}
