import { redirect } from 'next/navigation';
import { supabaseServer } from '@/lib/supabase/server';
import { sessionCourante } from '@/lib/session';
import type { EntreeCatalogue } from '@/lib/types';

export const dynamic = 'force-dynamic';

export default async function PageCatalogue() {
  const session = await sessionCourante();
  if (!session?.estAdmin) redirect('/');

  const supabase = await supabaseServer();
  const { data: meds } = await supabase
    .from('catalogue').select('*').order('type_intervention').order('nom');

  return (
    <>
      <div className="entete">
        <div>
          <h1>Catalogue</h1>
          <p>Toute modification recalcule immédiatement les éligibilités de tous les chevaux.</p>
        </div>
      </div>

      <div className="message info">
        La seule source de délai du système. Médicaments, interventions
        thérapeutiques et vaccins dans une seule liste : le délai d&apos;une ligne
        de traitement vient de son entrée ici, et d&apos;elle seule.
      </div>

      <div className="carte tableau-defilant">
        
        <table>
          <thead>
            <tr>
              <th>Nom</th><th>Type d&apos;intervention</th><th>Molécule</th>
              <th>Délai</th><th>Élimination</th><th>Total</th>
            </tr>
          </thead>
          <tbody>
            {((meds ?? []) as EntreeCatalogue[]).map((m) => (
              <tr key={m.id}>
                <td>{m.nom}</td>
                <td>
                  <span className="badge neutre">{m.type_intervention}</span>
                </td>
                <td style={{ color: 'var(--gris)' }}>{m.molecule ?? '—'}</td>
                <td className="num">{m.delai_j} j</td>
                <td className="num">{m.delai_elimination_j} j</td>
                <td className="num"><strong>{m.delai_j + m.delai_elimination_j + 1} j</strong></td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>



      <p style={{ color: 'var(--gris)', fontSize: '0.85rem' }}>
        Édition depuis Supabase &gt; Table Editor pour l&apos;instant. Une interface
        d&apos;édition ici est une évolution simple si le besoin se confirme.
      </p>
    </>
  );
}
