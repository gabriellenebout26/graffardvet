'use client';

import { useActionState, useMemo, useState } from 'react';
import { creerTraitement, type Resultat } from '@/app/actions';
import { aujourdhui, formatLong } from '@/lib/format';
import { calculer } from '@/lib/calcul';
import { TYPES_EVENEMENT, type Cheval, type EntreeCatalogue, type TypeEvenement,
  type TypeIntervention } from '@/lib/types';

export default function FormulaireTraitement({
  chevaux, catalogue, typesIntervention, prerempli,
}: {
  chevaux: Cheval[];
  catalogue: EntreeCatalogue[];
  typesIntervention: TypeIntervention[];
  prerempli: { cheval_id: string; catalogue_id: string; type: TypeEvenement; date: string };
}) {
  const [etat, envoyer, enCours] = useActionState<Resultat | null, FormData>(creerTraitement, null);

  const [type, setType] = useState<TypeEvenement>(prerempli.type);
  const [date, setDate] = useState(prerempli.date || aujourdhui());
  const [entreeId, setEntreeId] = useState(prerempli.catalogue_id);
  const [prises, setPrises] = useState(1);
  const [intervalle, setIntervalle] = useState(1);
  const [tousLesProduits, setTousLesProduits] = useState(false);

  // Le référentiel filtré par type d'événement : une infiltration ne
  // propose que Dos/Méso, Horstem et IRAP.
  const proposes = useMemo(() => {
    const compatibles = catalogue.filter((m) => m.type_intervention === type);
    return tousLesProduits || compatibles.length === 0 ? catalogue : compatibles;
  }, [catalogue, type, tousLesProduits]);

  const entree = catalogue.find((m) => m.id === entreeId);
  const aucunCompatible = catalogue.every((m) => m.type_intervention !== type);

  // Scope, radio, bilan sanguin : un acte d'examen, sans traitement ni délai.
  const attendTraitement =
    typesIntervention.find((t) => t.nom === type)?.avec_catalogue ?? true;

  const apercu = useMemo(() => {
    const c = calculer({
      date,
      nombrePrises: prises,
      intervalleJ: intervalle,
      delaiJ: entree?.delai_j ?? 0,
      delaiEliminationJ: entree?.delai_elimination_j ?? 0,
    });
    return {
      duree: c.dureeJ, fin: c.finTraitement, peutCourir: c.peutCourirLe,
      delai: entree?.delai_j ?? 0,
      elimination: entree?.delai_elimination_j ?? 0,
      total: c.delaiTotal,
    };
  }, [date, prises, intervalle, entree]);

  return (
    <div style={{ display: 'grid', gridTemplateColumns: 'minmax(0, 1fr) 300px', gap: '1rem', alignItems: 'start' }}>
      <form action={envoyer} className="carte">
        {etat?.erreur && <div className="message erreur">{etat.erreur}</div>}

        <label className="champ">
          <span>Cheval</span>
          <select name="cheval_id" required defaultValue={prerempli.cheval_id}>
            <option value="">— Sélectionner —</option>
            {chevaux.map((c) => (
              <option key={c.id} value={c.id}>
                {c.nom}{c.location ? ` · ${c.location}` : ''}
              </option>
            ))}
          </select>
        </label>

        <div className="grille-2">
          <label className="champ">
            <span>Date du traitement</span>
            <input type="date" name="date" required value={date}
              onChange={(e) => setDate(e.target.value)} />
          </label>
          <label className="champ">
            <span>Type d&apos;intervention</span>
            <select name="type" value={type}
              onChange={(e) => { setType(e.target.value as TypeEvenement); setEntreeId(''); }}>
              {TYPES_EVENEMENT.map((t) => <option key={t} value={t}>{t}</option>)}
            </select>
          </label>
        </div>

        {!attendTraitement && (
          <div className="message info">
            <strong>{type}</strong> est un acte d&apos;examen : aucun traitement
            associé, et aucun délai avant de courir.
          </div>
        )}

        {attendTraitement && (
        <label className="champ">
          <span>Traitement associé</span>
          <select name="catalogue_id" required value={entreeId}
            onChange={(e) => setEntreeId(e.target.value)}>
            <option value="">— Sélectionner —</option>
            {proposes.map((m) => (
              <option key={m.id} value={m.id}>
                {m.nom} — {m.delai_j + m.delai_elimination_j} j
              </option>
            ))}
          </select>
        </label>
        )}

        {attendTraitement && !aucunCompatible && (
          <label style={{ display: 'flex', alignItems: 'center', gap: '0.4rem', marginTop: '-0.6rem', marginBottom: '1rem', fontSize: '0.82rem', color: 'var(--gris)' }}>
            <input type="checkbox" style={{ width: 'auto' }}
              checked={tousLesProduits}
              onChange={(e) => setTousLesProduits(e.target.checked)} />
            Afficher tout le catalogue, pas seulement les entrées de ce type
          </label>
        )}
        {attendTraitement && aucunCompatible && (
          <div className="message info" style={{ fontSize: '0.82rem' }}>
            Aucune entrée du catalogue n&apos;est rattachée à « {type} ».
            La liste montre tout le catalogue.
          </div>
        )}

        {attendTraitement && (
        <div className="grille-3">
          <label className="champ">
            <span>Nombre de prises</span>
            <input type="number" name="nombre_prises" min={1} value={prises}
              onChange={(e) => setPrises(Math.max(parseInt(e.target.value) || 1, 1))} />
          </label>
          <label className="champ">
            <span>Intervalle (jours)</span>
            <input type="number" name="intervalle_j" min={1} value={intervalle}
              onChange={(e) => setIntervalle(Math.max(parseInt(e.target.value) || 1, 1))} />
          </label>
          <label className="champ">
            <span>Durée calculée</span>
            <input type="text" value={`${apercu.duree} jour${apercu.duree > 1 ? 's' : ''}`} readOnly
              style={{ background: 'var(--gris-pale)', fontFamily: 'var(--mono)' }} />
          </label>
        </div>
        )}

        {attendTraitement && (
        <label className="champ">
          <span>Posologie</span>
          <input type="text" name="posologie" placeholder="ex. 2 sachets matin et soir" />
        </label>
        )}

        <div className="grille-2">
          <label className="champ">
            <span>N° d&apos;ordonnance</span>
            <input type="text" name="ordonnance_numero" placeholder="ex. 2026-0453" />
          </label>
        </div>

        <label className="champ">
          <span>Notes</span>
          <textarea name="notes" rows={2} />
        </label>

        <div className="barre-outils">
          <button className="bouton" disabled={enCours}>
            {enCours ? 'Enregistrement…' : 'Enregistrer'}
          </button>
          <button className="bouton secondaire" name="encore" value="1" disabled={enCours}>
            Enregistrer et ajouter une autre ligne
          </button>
        </div>
        <p style={{ fontSize: '0.8rem', color: 'var(--gris)', marginBottom: 0 }}>
          Une ligne par produit ou intervention. Pour une ordonnance à
          plusieurs lignes, « ajouter une autre ligne » garde le cheval et la date.
        </p>
      </form>

      <aside className="carte" style={{ position: 'sticky', top: '1rem' }}>
        <div className="etiquette">Aperçu du calcul</div>
        <div style={{ fontFamily: 'var(--mono)', fontSize: '0.82rem', marginTop: '0.9rem', lineHeight: 1.9 }}>
          <div>{attendTraitement ? 'Fin de traitement' : 'Date de l\'acte'}<br />
            <strong>{formatLong(apercu.fin)}</strong></div>
          {attendTraitement && (
            <div style={{ marginTop: '0.7rem', color: 'var(--gris)' }}>
              + délai : {apercu.delai} j<br />
              + élimination : {apercu.elimination} j<br />
              + article 85 : 1 j
            </div>
          )}
        </div>
        <hr style={{ border: 0, borderTop: '1px solid var(--bord)', margin: '1rem 0' }} />
        {attendTraitement ? (
          <>
            <div className="etiquette">Peut courir à partir du</div>
            <div style={{ fontFamily: 'var(--serif)', fontSize: '1.35rem', color: 'var(--ardoise)', marginTop: '0.3rem' }}>
              {formatLong(apercu.peutCourir)}
            </div>
            <p style={{ fontSize: '0.78rem', color: 'var(--gris)', marginTop: '0.6rem', marginBottom: 0 }}>
              Si ce cheval a d&apos;autres traitements en cours, c&apos;est la
              date la plus lointaine qui s&apos;appliquera.
            </p>
          </>
        ) : (
          <>
            <div className="etiquette">Éligibilité</div>
            <div style={{ fontFamily: 'var(--serif)', fontSize: '1.2rem', color: 'var(--libre)', marginTop: '0.3rem' }}>
              Aucun délai
            </div>
            <p style={{ fontSize: '0.78rem', color: 'var(--gris)', marginTop: '0.6rem', marginBottom: 0 }}>
              Cet acte n&apos;empêche pas le cheval de courir.
            </p>
          </>
        )}
      </aside>
    </div>
  );
}
