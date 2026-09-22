import Link from 'next/link';
import { notFound } from 'next/navigation';
import { supabaseServer } from '@/lib/supabase/server';
import { sessionCourante } from '@/lib/session';
import { formatCourt, formatLong, aujourdhui, pluriel } from '@/lib/format';
import type { Cheval, LigneVetList, Traitement } from '@/lib/types';

export const dynamic = 'force-dynamic';

export default async function FicheCheval({
  params, searchParams,
}: {
  params: Promise<{ id: string }>;
  searchParams: Promise<{ ok?: string }>;
}) {
  const { id } = await params;
  const { ok } = await searchParams;
  const session = await sessionCourante();
  const supabase = await supabaseServer();

  const [{ data: cheval }, { data: traitements }, { data: vet }] = await Promise.all([
    supabase.from('chevaux').select('*').eq('id', id).maybeSingle(),
    supabase.from('v_traitements').select('*').eq('cheval_id', id).order('date', { ascending: false }),
    supabase.rpc('vet_list', { date_reference: aujourdhui() }),
  ]);

  if (!cheval) notFound();

  const c = cheval as Cheval;
  const histo = (traitements ?? []) as Traitement[];
  const statut = ((vet ?? []) as LigneVetList[]).find((l) => l.cheval_id === id);

  return (
    <>
      <div className="entete">
        <div>
          <h1>{c.nom}</h1>
          <p>
            {[c.location, c.sexe, c.annee_naissance, c.proprietaire].filter(Boolean).join(' · ') || '—'}
          </p>
        </div>
        <div className="barre-outils">
          {statut && (
            <span className={`badge ${statut.peut_courir ? 'libre' : 'bloque'}`}>
              {statut.peut_courir
                ? 'Peut courir'
                : `${pluriel(statut.jours_restants, 'jour')} de délai`}
            </span>
          )}
          {session?.peutSaisir && (
            <Link className="bouton petit" href={`/traitements/nouveau?cheval=${c.id}`}>
              Ajouter un traitement
            </Link>
          )}
        </div>
      </div>

      {ok === '1' && <div className="message succes">Traitement enregistré.</div>}

      {statut && !statut.peut_courir && (
        <div className="carte" style={{ marginBottom: '1rem' }}>
          <div className="etiquette">Engageable à partir du</div>
          <div style={{ fontFamily: 'var(--serif)', fontSize: '1.5rem', color: 'var(--ardoise)' }}>
            {formatLong(statut.libre_le)}
          </div>
          {statut.motif && (
            <p style={{ color: 'var(--gris)', margin: '0.3rem 0 0', fontSize: '0.88rem' }}>
              Traitement bloquant : {statut.motif}
            </p>
          )}
        </div>
      )}

      <div className="carte tableau-defilant">
        <h3 style={{ marginBottom: '0.9rem' }}>Historique des traitements</h3>
        {histo.length === 0 ? (
          <div className="vide">Aucun traitement enregistré.</div>
        ) : (
          <table>
            <thead>
              <tr>
                <th>Date</th><th>Type</th><th>Produit</th><th>Posologie</th>
                <th>Durée</th><th>Fin</th><th>Peut courir</th><th>Ordonnance</th><th>Saisi par</th>
              </tr>
            </thead>
            <tbody>
              {histo.map((t) => (
                <tr key={t.id}>
                  <td className="num">{formatCourt(t.date)}</td>
                  <td>
                    {t.type_intervention}
                    {t.fin_traitement_reelle && (
                      <div><span className="badge neutre">Arrêté le {formatCourt(t.fin_traitement_reelle)}</span></div>
                    )}
                  </td>
                  <td>{t.entree_catalogue ?? '—'}</td>
                  <td>{t.posologie ?? '—'}</td>
                  <td className="num">{t.duree_j} j</td>
                  <td className="num">{formatCourt(t.fin_traitement)}</td>
                  <td className="num">{formatCourt(t.peut_courir_le)}</td>
                  <td className="num">{t.ordonnance_numero ?? '—'}</td>
                  <td style={{ color: 'var(--gris)', fontSize: '0.8rem' }}>{t.cree_par ?? '—'}</td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>
    </>
  );
}
