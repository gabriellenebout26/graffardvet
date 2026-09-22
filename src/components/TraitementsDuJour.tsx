'use client';

import { useState, useTransition } from 'react';
import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { administreAujourdhui, arreterTraitement } from '@/app/actions';
import { formatCourt } from '@/lib/format';
import type { Traitement } from '@/lib/types';

export default function TraitementsDuJour({
  traitements, peutSaisir,
}: {
  traitements: Traitement[];
  peutSaisir: boolean;
}) {
  const router = useRouter();
  const [enCours, demarrer] = useTransition();
  const [message, setMessage] = useState<{ ton: string; texte: string } | null>(null);
  const [actif, setActif] = useState<string | null>(null);

  function lancer(id: string, action: (id: string) => Promise<{ erreur?: string; succes?: string }>) {
    setActif(id);
    demarrer(async () => {
      const r = await action(id);
      setMessage(r.erreur ? { ton: 'erreur', texte: r.erreur } : { ton: 'succes', texte: r.succes ?? 'Fait.' });
      setActif(null);
      router.refresh();
    });
  }

  const aFaire = traitements.filter((t) => t.prise_due_aujourdhui && !t.administre_aujourdhui);
  const faits = traitements.filter((t) => t.administre_aujourdhui);
  const autres = traitements.filter((t) => !t.prise_due_aujourdhui && !t.administre_aujourdhui);

  if (traitements.length === 0) {
    return <div className="carte"><div className="vide">Aucun traitement en cours aujourd&apos;hui.</div></div>;
  }

  const jourDe = (t: Traitement) =>
    Math.max(
      Math.floor(
        (Date.parse(new Date().toISOString().slice(0, 10)) - Date.parse(t.date)) / 86_400_000,
      ) + 1,
      1,
    );

  const Actions = ({ t }: { t: Traitement }) => (
    <div className="barre-outils">
      {!t.administre_aujourdhui && (
        <button className="bouton petit"
          disabled={enCours && actif === t.id}
          onClick={() => lancer(t.id, administreAujourdhui)}>
          Administré
        </button>
      )}
      <button className="bouton petit danger"
        disabled={enCours && actif === t.id}
        onClick={() => {
          if (confirm(`Arrêter le traitement de ${t.cheval} aujourd'hui ?`)) {
            lancer(t.id, arreterTraitement);
          }
        }}>
        Arrêter
      </button>
      <Link className="bouton petit secondaire"
        href={`/traitements/nouveau?cheval=${t.cheval_id}&entree=${t.catalogue_id ?? ''}&type=${encodeURIComponent(t.type_intervention)}`}>
        Dupliquer
      </Link>
    </div>
  );

  const Section = ({ titre, lignes, ton }: { titre: string; lignes: Traitement[]; ton: string }) => {
    if (lignes.length === 0) return null;
    return (
      <div className="carte">
        <div className="barre-outils" style={{ marginBottom: '0.9rem' }}>
          <h3>{titre}</h3>
          <span className={`badge ${ton}`}>{lignes.length}</span>
        </div>

        {/* Téléphone : une fiche par traitement, actions au pouce */}
        <div className="fiches-mobile">
          {lignes.map((t) => (
            <article key={t.id} className="fiche">
              <div className="fiche-tete">
                <Link href={`/chevaux/${t.cheval_id}`}>{t.cheval}</Link>
                <span className="badge neutre">J{jourDe(t)} / {t.duree_j}</span>
              </div>
              <div className="fiche-produit">{t.entree_catalogue ?? t.type_intervention}</div>
              {t.posologie && <div className="fiche-posologie">{t.posologie}</div>}
              <dl className="fiche-infos">
                <div><dt>Emplacement</dt><dd>{t.location ?? '—'}</dd></div>
                <div><dt>Fin prévue</dt><dd>{formatCourt(t.fin_traitement)}</dd></div>
                <div><dt>Peut courir</dt><dd>{formatCourt(t.peut_courir_le)}</dd></div>
              </dl>
              {peutSaisir && <Actions t={t} />}
            </article>
          ))}
        </div>

        {/* Bureau : tableau dense */}
        <div className="tableau-defilant tableau-bureau">
          <table>
            <thead>
              <tr>
                <th>Cheval</th><th>Produit</th><th>Posologie</th>
                <th>Avancement</th><th>Fin prévue</th><th>Peut courir</th>
                {peutSaisir && <th />}
              </tr>
            </thead>
            <tbody>
              {lignes.map((t) => (
                <tr key={t.id}>
                  <td>
                    <Link href={`/chevaux/${t.cheval_id}`}>{t.cheval}</Link>
                    {t.location && <div style={{ color: 'var(--gris)', fontSize: '0.8rem' }}>{t.location}</div>}
                  </td>
                  <td>{t.entree_catalogue ?? t.type_intervention}</td>
                  <td>{t.posologie ?? '—'}</td>
                  <td className="num">J{jourDe(t)} / {t.duree_j}</td>
                  <td className="num">{formatCourt(t.fin_traitement)}</td>
                  <td className="num">{formatCourt(t.peut_courir_le)}</td>
                  {peutSaisir && <td><Actions t={t} /></td>}
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
    );
  };

  return (
    <>
      {message && <div className={`message ${message.ton}`}>{message.texte}</div>}
      <Section titre="À administrer aujourd'hui" lignes={aFaire} ton="attente" />
      <Section titre="Déjà administrés" lignes={faits} ton="libre" />
      <Section titre="En cours, pas de prise aujourd'hui" lignes={autres} ton="neutre" />
    </>
  );
}
