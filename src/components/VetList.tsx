'use client';

import { useMemo, useState } from 'react';
import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { formatCourt, formatLong, aujourdhui, pluriel } from '@/lib/format';
import type { LigneVetList, Traitement } from '@/lib/types';

type Filtre = 'tous' | 'libres' | 'bloques';

export default function VetList({
  dateRef, lignes, traitements,
}: {
  dateRef: string;
  lignes: LigneVetList[];
  traitements: Traitement[];
}) {
  const router = useRouter();
  const [recherche, setRecherche] = useState('');
  const [filtre, setFiltre] = useState<Filtre>('tous');
  const [selection, setSelection] = useState<string | null>(lignes[0]?.cheval_id ?? null);

  const visibles = useMemo(() => {
    const r = recherche.trim().toLowerCase();
    return lignes.filter((l) =>
      (!r || l.cheval.toLowerCase().includes(r) || (l.location ?? '').toLowerCase().includes(r)) &&
      (filtre === 'tous' || (filtre === 'libres' ? l.peut_courir : !l.peut_courir)));
  }, [lignes, recherche, filtre]);

  const bloques = lignes.filter((l) => !l.peut_courir).length;
  const courant = lignes.find((l) => l.cheval_id === selection) ?? visibles[0] ?? null;
  const historique = traitements.filter((t) => t.cheval_id === courant?.cheval_id);
  const estAujourdhui = dateRef === aujourdhui();

  function changerDate(d: string) {
    router.push(d && d !== aujourdhui() ? `/?date=${d}` : '/');
  }

  return (
    <>
      <div className="entete">
        <div>
          <h1>Vet List</h1>
          <p>
            {estAujourdhui ? "Situation d'aujourd'hui" : `Simulation au ${formatLong(dateRef)}`}
            {' · '}{lignes.length - bloques} sur {lignes.length} chevaux peuvent courir
          </p>
        </div>
        <div className="barre-outils">
          <span className="etiquette">Date de course</span>
          <input type="date" value={dateRef} onChange={(e) => changerDate(e.target.value)}
            style={{ width: 'auto' }} />
          {!estAujourdhui && (
            <button className="bouton secondaire petit" onClick={() => changerDate('')}>
              Aujourd&apos;hui
            </button>
          )}
        </div>
      </div>

      <div className="deux-panneaux">
        <div className="panneau">
          <div style={{ padding: '0.75rem', borderBottom: '1px solid var(--bord)' }}>
            <input type="text" placeholder="Rechercher un cheval…" value={recherche}
              onChange={(e) => setRecherche(e.target.value)} />
            <div className="barre-outils" style={{ marginTop: '0.6rem' }}>
              {([['tous', `Tous (${lignes.length})`],
                 ['libres', `Peuvent courir (${lignes.length - bloques})`],
                 ['bloques', `Sous délai (${bloques})`]] as [Filtre, string][]).map(([v, label]) => (
                <button key={v} onClick={() => setFiltre(v)}
                  className={`bouton petit ${filtre === v ? '' : 'secondaire'}`}>
                  {label}
                </button>
              ))}
            </div>
          </div>

          <div className="liste-chevaux">
            {visibles.length === 0 && <div className="vide">Aucun cheval.</div>}
            {visibles.map((l) => (
              <button key={l.cheval_id}
                className={`ligne-cheval ${l.cheval_id === courant?.cheval_id ? 'selection' : ''}`}
                onClick={() => setSelection(l.cheval_id)}>
                <span className={`pip ${l.peut_courir ? 'libre' : 'bloque'}`} />
                <span className="nom">{l.cheval}</span>
                <span className="info">
                  {l.peut_courir ? (l.location ?? '') : formatCourt(l.libre_le)}
                </span>
              </button>
            ))}
          </div>
        </div>

        <div className="panneau" style={{ padding: '1.25rem' }}>
          {!courant ? (
            <div className="vide">Sélectionnez un cheval.</div>
          ) : (
            <>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', gap: '1rem', flexWrap: 'wrap' }}>
                <div>
                  <h2>{courant.cheval}</h2>
                  {courant.location && <div className="etiquette">{courant.location}</div>}
                </div>
                <span className={`badge ${courant.peut_courir ? 'libre' : 'bloque'}`}>
                  {courant.peut_courir
                    ? 'Peut courir'
                    : `Libre le ${formatCourt(courant.libre_le)}`}
                </span>
              </div>

              {!courant.peut_courir && (
                <div className="message info" style={{ marginTop: '1rem' }}>
                  Encore {pluriel(courant.jours_restants, 'jour')} de délai
                  {courant.motif && <> — {courant.motif}</>}. Engageable à partir
                  du {formatLong(courant.libre_le)}.
                </div>
              )}

              <h3 style={{ margin: '1.5rem 0 0.5rem' }}>Historique</h3>
              {historique.length === 0 ? (
                <div className="vide">Aucun traitement enregistré.</div>
              ) : (
                <div className="tableau-defilant">
                  <table>
                    <thead>
                      <tr>
                        <th>Date</th><th>Type</th><th>Produit</th>
                        <th>Durée</th><th>Fin</th><th>Peut courir</th><th />
                      </tr>
                    </thead>
                    <tbody>
                      {historique.map((t) => (
                        <tr key={t.id}>
                          <td className="num">{formatCourt(t.date)}</td>
                          <td>{t.type_intervention}</td>
                          <td>
                            {t.entree_catalogue ?? '—'}
                            {t.posologie && (
                              <div style={{ color: 'var(--gris)', fontSize: '0.8rem' }}>{t.posologie}</div>
                            )}
                          </td>
                          <td className="num">{t.duree_j} j</td>
                          <td className="num">{formatCourt(t.fin_traitement)}</td>
                          <td className="num">
                            {formatCourt(t.peut_courir_le)}
                            {t.peut_courir_le > dateRef && (
                              <span className="pip bloque" style={{ marginLeft: 6 }} />
                            )}
                          </td>
                          <td>
                            {t.fin_traitement_reelle && (
                              <span className="badge neutre">Arrêté</span>
                            )}
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              )}

              <div style={{ marginTop: '1.25rem' }}>
                <Link href={`/chevaux/${courant.cheval_id}`} className="bouton secondaire petit">
                  Fiche complète
                </Link>
              </div>
            </>
          )}
        </div>
      </div>
    </>
  );
}
