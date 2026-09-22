import { redirect } from 'next/navigation';
import { supabaseServer } from '@/lib/supabase/server';
import { sessionCourante } from '@/lib/session';
import { formatCourt } from '@/lib/format';

export const dynamic = 'force-dynamic';

const explications: Record<string, string> = {
  admin: 'Tout, y compris le référentiel des délais et les accès',
  saisie: 'Enregistre les traitements et les administrations',
  consultation: 'Lecture seule : Vet List, chevaux, historiques',
};

export default async function PageUtilisateurs() {
  const session = await sessionCourante();
  if (!session?.estAdmin) redirect('/');

  const supabase = await supabaseServer();
  const { data } = await supabase.from('responsables').select('*').order('nom');

  return (
    <>
      <div className="entete">
        <div>
          <h1>Utilisateurs</h1>
          <p>Seules les adresses listées ici peuvent ouvrir l&apos;application.</p>
        </div>
      </div>

      <div className="carte tableau-defilant">
        <table>
          <thead><tr><th>Nom</th><th>Email</th><th>Rôle</th><th>Droits</th><th>Actif</th><th>Ajouté le</th></tr></thead>
          <tbody>
            {(data ?? []).map((r: { id: string; nom: string; email: string; role: string; actif: boolean; created_at: string }) => (
              <tr key={r.id}>
                <td>{r.nom}</td>
                <td className="num">{r.email}</td>
                <td><span className="badge neutre">{r.role}</span></td>
                <td style={{ color: 'var(--gris)', fontSize: '0.83rem' }}>{explications[r.role]}</td>
                <td>{r.actif ? 'oui' : 'non'}</td>
                <td className="num">{formatCourt(r.created_at)}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      <p style={{ color: 'var(--gris)', fontSize: '0.85rem' }}>
        Pour ajouter quelqu&apos;un : Supabase &gt; Table Editor &gt; responsables,
        une ligne avec son email et son rôle. Il se connecte ensuite avec un lien
        envoyé à cette adresse — aucun mot de passe à créer ni à transmettre.
      </p>
    </>
  );
}
