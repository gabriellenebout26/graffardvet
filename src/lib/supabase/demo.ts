/**
 * MODE DÉMO — actif uniquement si DEMO_GRAFFARD=1.
 * Sert à visualiser l'application sans base de données (captures, présentation
 * à Francis). N'a aucun effet en production : la variable n'est pas définie
 * sur Vercel. À supprimer une fois la vraie base branchée si tu préfères.
 */
import { calculer } from '@/lib/calcul';

export const MODE_DEMO = process.env.DEMO_GRAFFARD === '1';

const J = (decalage: number) => {
  const d = new Date(2026, 8, 15);
  d.setDate(d.getDate() + decalage);
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
};

const CATALOGUE = [
  { id: 'm1', nom: 'Gastrogard', delai_j: 5, delai_elimination_j: 3, type_intervention: 'Administration médicament', molecule: 'oméprazole', commentaire: null, actif: true },
  { id: 'm2', nom: 'Borgal', delai_j: 3, delai_elimination_j: 0, type_intervention: 'Administration médicament', molecule: 'sulfadoxine/triméthoprime', commentaire: null, actif: true },
  { id: 'm3', nom: 'Metacam', delai_j: 5, delai_elimination_j: 3, type_intervention: 'Administration médicament', molecule: null, commentaire: null, actif: true },
  { id: 'm4', nom: 'Histabiosone', delai_j: 21, delai_elimination_j: 3, type_intervention: 'Administration médicament', molecule: null, commentaire: null, actif: true },
  { id: 'm5', nom: 'Dos/Méso', delai_j: 30, delai_elimination_j: 0, type_intervention: 'Infiltration', molecule: null, commentaire: null, actif: true },
  { id: 'm6', nom: 'IRAP', delai_j: 14, delai_elimination_j: 0, type_intervention: 'Infiltration', molecule: null, commentaire: null, actif: true },
  { id: 'm7', nom: 'Ondes de choc', delai_j: 5, delai_elimination_j: 0, type_intervention: 'Ondes de choc', molecule: null, commentaire: null, actif: true },
  { id: 'm8', nom: 'Grippe', delai_j: 4, delai_elimination_j: 0, type_intervention: 'Vaccin', molecule: null, commentaire: null, actif: true },
];

const NOMS = [
  'ALIZE DU MATIN', 'BRUYERE SAUVAGE', 'CAP HORNIER FR', 'DAME DE CARREAU',
  'ECLAT DE CHANTILLY', 'FLEUVE TRANQUILLE', 'GRAND LARGE IRE', 'HAUTE FUTAIE',
  'IVOIRE DES SABLES', 'JOUR DE FETE FR', 'KERMESSE ROYALE', 'LUMIERE RASANTE',
  'MAREE BASSE GB', 'NUIT DE VELOURS', 'ORAGE PASSAGER', 'PLEINE LUNE FR',
  'QUART DE TOUR', 'RIVAGE NORD IRE', 'SILENCE RADIO', 'TEMPS COUVERT',
];

const COURS = ['Cour A', 'Cour A', 'Cour B', 'Cour B', 'Cour C', 'Les Aigles'];

export const CHEVAUX = NOMS.map((nom, i) => ({
  id: `c${i + 1}`,
  nom,
  sexe: i % 3 === 0 ? 'Femelle' : 'Mâle',
  annee_naissance: 2019 + (i % 4),
  proprietaire: ['Écurie Jean-Louis Bouchard', 'Godolphin', 'Wertheimer & Frère', 'Al Shaqab Racing'][i % 4],
  location: COURS[i % COURS.length],
  actif: true,
}));

type Brut = {
  id: string; cheval: number; date: string; type: string;
  med?: string; prises?: number; intervalle?: number; posologie?: string;
  finReelle?: string | null; ordonnance?: string;
};

const BRUTS: Brut[] = [
  { id: 't1', cheval: 0, date: J(-2), type: 'Administration médicament', med: 'm2', prises: 5, intervalle: 1, posologie: '2 sachets matin et soir', ordonnance: '2026-0411' },
  { id: 't2', cheval: 2, date: J(-1), type: 'Administration médicament', med: 'm1', prises: 10, intervalle: 1, posologie: '1 seringue le matin', ordonnance: '2026-0413' },
  { id: 't3', cheval: 4, date: J(-12), type: 'Infiltration', med: 'm5', ordonnance: '2026-0398' },
  { id: 't4', cheval: 6, date: J(0), type: 'Administration médicament', med: 'm5', prises: 3, intervalle: 1, posologie: '10 ml IV', ordonnance: '2026-0418' },
  { id: 't5', cheval: 8, date: J(-4), type: 'Ondes de choc', med: 'm7', ordonnance: '2026-0405' },
  { id: 't6', cheval: 9, date: J(-6), type: 'Administration médicament', med: 'm4', prises: 4, intervalle: 2, posologie: '1 sachet / jour', ordonnance: '2026-0402' },
  { id: 't7', cheval: 11, date: J(-30), type: 'Vaccin', med: 'm8', ordonnance: '2026-0350' },
  { id: 't8', cheval: 12, date: J(-3), type: 'Administration médicament', med: 'm3', prises: 3, intervalle: 1, posologie: '5 ml IM', finReelle: J(-2), ordonnance: '2026-0409' },
  { id: 't9', cheval: 14, date: J(-1), type: 'Administration médicament', med: 'm6', prises: 4, intervalle: 1, posologie: '0,3 ml', ordonnance: '2026-0414' },
  { id: 't10', cheval: 15, date: J(-45), type: 'Vulvoplastie', med: 'm2', ordonnance: '2026-0301' },
  { id: 't11', cheval: 17, date: J(-8), type: 'Administration médicament', med: 'm2', prises: 5, intervalle: 1, posologie: '2 sachets matin et soir', ordonnance: '2026-0399' },
  { id: 't12', cheval: 0, date: J(-60), type: 'Administration médicament', med: 'm4', ordonnance: '2026-0280' },
  { id: 't13', cheval: 0, date: J(-90), type: 'Administration médicament', med: 'm5', prises: 2, intervalle: 1, posologie: '10 ml IV', ordonnance: '2026-0210' },
  { id: 't14', cheval: 19, date: J(-2), type: 'Administration médicament', med: 'm3', ordonnance: '2026-0412' },
  { id: 't15', cheval: 3, date: J(-15), type: 'Administration médicament', med: 'm1', prises: 14, intervalle: 1, posologie: '1 seringue le matin', ordonnance: '2026-0388' },
];

const AUJOURDHUI = J(0);

export const TRAITEMENTS = BRUTS.map((b) => {
  const cheval = CHEVAUX[b.cheval];
  const med = b.med ? CATALOGUE.find((m) => m.id === b.med)! : null;
  const prises = b.prises ?? 1;
  const intervalle = b.intervalle ?? 1;
  const c = calculer({
    date: b.date,
    nombrePrises: prises,
    intervalleJ: intervalle,
    delaiJ: med?.delai_j ?? 0,
    delaiEliminationJ: med?.delai_elimination_j ?? 0,
    finTraitementReelle: b.finReelle ?? null,
  });
  const enCours = b.date <= AUJOURDHUI && AUJOURDHUI <= c.finTraitement;
  const ecart = Math.round(
    (Date.parse(AUJOURDHUI) - Date.parse(b.date)) / 86_400_000,
  );
  return {
    id: b.id,
    cheval_id: cheval.id,
    cheval: cheval.nom,
    location: cheval.location,
    date: b.date,
    type_intervention: b.type,
    catalogue_id: b.med ?? null,
    entree_catalogue: med?.nom ?? null,
    molecule: null,

    nombre_prises: prises,
    intervalle_j: intervalle,
    posologie: b.posologie ?? null,
    ordonnance_numero: b.ordonnance ?? null,
    ordonnance_url: null,
    fin_traitement_reelle: b.finReelle ?? null,
    notes: null,
    cree_par: 'responsable@ecurie-graffard.com',
    created_at: b.date,
    duree_j: c.dureeJ,
    fin_traitement: c.finTraitement,
    delai_j: med?.delai_j ?? 0,
    delai_elimination_j: med?.delai_elimination_j ?? 0,
    delai_total: c.delaiTotal,
    entree_manquante: false,
    peut_courir_le: c.peutCourirLe,
    fin_calendrier: c.finCalendrier,
    en_cours: enCours,
    prise_due_aujourdhui: enCours && ecart % intervalle === 0,
    administre_aujourdhui: b.id === 't2' || b.id === 't15',
  };
});

export function vetListDemo(dateRef: string) {
  return CHEVAUX.map((c) => {
    const bloquants = TRAITEMENTS
      .filter((t) => t.cheval_id === c.id && t.peut_courir_le > dateRef)
      .sort((a, b) => (a.peut_courir_le < b.peut_courir_le ? 1 : -1));
    const pire = bloquants[0];
    return {
      cheval_id: c.id,
      cheval: c.nom,
      location: c.location,
      peut_courir: !pire,
      libre_le: pire?.peut_courir_le ?? null,
      jours_restants: pire
        ? Math.round((Date.parse(pire.peut_courir_le) - Date.parse(dateRef)) / 86_400_000)
        : 0,
      traitement_bloquant: pire?.id ?? null,
      motif: pire ? (pire.entree_catalogue ?? pire.type_intervention) : null,
      type_bloquant: pire?.type_intervention ?? null,
    };
  }).sort((a, b) => a.cheval.localeCompare(b.cheval));
}

export const TYPES_INTERVENTION = [
  { nom: 'Administration médicament', avec_catalogue: true,  commentaire: 'Le produit prescrit' },
  { nom: 'Infiltration',              avec_catalogue: true,  commentaire: 'Dos/Méso, Horstem, IRAP' },
  { nom: 'Vulvoplastie',              avec_catalogue: true,  commentaire: 'Les produits sont toujours écrits' },
  { nom: 'Ondes de choc',             avec_catalogue: true,  commentaire: null },
  { nom: 'Vaccin',                    avec_catalogue: true,  commentaire: 'Grippe, Rhino' },
  { nom: 'Vermifuge',                 avec_catalogue: true,  commentaire: 'Adequan' },
  { nom: 'Scope',                     avec_catalogue: false, commentaire: "Acte d'examen, aucun délai" },
  { nom: 'Scope Embarqué',            avec_catalogue: false, commentaire: "Acte d'examen, aucun délai" },
  { nom: 'Radio/Imagerie',            avec_catalogue: false, commentaire: "Acte d'examen, aucun délai" },
  { nom: 'Bilan sanguin',             avec_catalogue: false, commentaire: "Acte d'examen, aucun délai" },
];

export const RESPONSABLES = [
  { id: 'r1', nom: 'Gabrielle', email: 'gabrielle@ecurie-graffard.com', role: 'admin', actif: true, created_at: J(-120) },
  { id: 'r2', nom: 'Francis Graffard', email: 'francis@ecurie-graffard.com', role: 'consultation', actif: true, created_at: J(-120) },
  { id: 'r3', nom: 'Romain', email: 'romain@ecurie-graffard.com', role: 'consultation', actif: true, created_at: J(-120) },
  { id: 'r4', nom: 'Responsable cour A', email: 'courA@ecurie-graffard.com', role: 'saisie', actif: true, created_at: J(-90) },
  { id: 'r5', nom: 'Responsable cour B', email: 'courB@ecurie-graffard.com', role: 'saisie', actif: true, created_at: J(-90) },
];

export { CATALOGUE };

/* ------------------------------------------------------------------ */
/* Client minimal imitant l'API Supabase utilisée par les pages.       */
/* ------------------------------------------------------------------ */

type Ligne = Record<string, unknown>;

class Requete implements PromiseLike<{ data: unknown; error: null }> {
  constructor(private lignes: Ligne[]) {}
  select() { return this; }
  eq(col: string, val: unknown) {
    this.lignes = this.lignes.filter((l) => l[col] === val);
    return this;
  }
  ilike() { return this; }
  order(col: string, opts?: { ascending?: boolean }) {
    const sens = opts?.ascending === false ? -1 : 1;
    this.lignes = [...this.lignes].sort((a, b) =>
      String(a[col] ?? '') < String(b[col] ?? '') ? -sens : sens);
    return this;
  }
  maybeSingle() {
    return Promise.resolve({ data: this.lignes[0] ?? null, error: null });
  }
  insert() { return Promise.resolve({ data: null, error: null }); }
  update() { return this; }
  delete() { return this; }
  then<R1 = { data: unknown; error: null }, R2 = never>(
    ok?: ((v: { data: unknown; error: null }) => R1 | PromiseLike<R1>) | null,
    ko?: ((r: unknown) => R2 | PromiseLike<R2>) | null,
  ): PromiseLike<R1 | R2> {
    return Promise.resolve({ data: this.lignes, error: null }).then(ok, ko);
  }
}

const TABLES: Record<string, Ligne[]> = {
  chevaux: CHEVAUX,
  catalogue: CATALOGUE,
  v_traitements: TRAITEMENTS,
  responsables: RESPONSABLES,
  types_intervention: TYPES_INTERVENTION,
  traitements: [],
  administrations: [],
};

export function clientDemo() {
  return {
    auth: {
      getUser: async () => ({
        data: { user: { email: 'gabrielle@ecurie-graffard.com' } },
        error: null,
      }),
      signOut: async () => ({ error: null }),
    },
    from: (table: string) => new Requete(TABLES[table] ?? []),
    rpc: async (nom: string, args: { date_reference?: string }) =>
      nom === 'vet_list'
        ? { data: vetListDemo(args?.date_reference ?? AUJOURDHUI), error: null }
        : { data: [], error: null },
  };
}
