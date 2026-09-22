export const TYPES_EVENEMENT = [
  'Administration médicament',
  'Infiltration',
  'Vaccin',
  'Bilan sanguin',
  'Radio/Imagerie',
  'Vulvoplastie',
  'Ondes de choc',
  'Scope',
  'Scope Embarqué',
  'Vermifuge',
] as const;

export type TypeEvenement = (typeof TYPES_EVENEMENT)[number];
export type Role = 'admin' | 'saisie' | 'consultation';

/** Un type d'intervention. Ne porte aucun délai. */
export type TypeIntervention = {
  nom: string;
  avec_catalogue: boolean;
  commentaire: string | null;
  ordre: number;
};

export type Cheval = {
  id: string;
  nom: string;
  sexe: string | null;
  annee_naissance: number | null;
  proprietaire: string | null;
  location: string | null;
  actif: boolean;
};

/** Une entrée du catalogue : médicament, intervention thérapeutique ou vaccin.
 *  C'est la seule source de délai du système. */
export type EntreeCatalogue = {
  id: string;
  nom: string;
  type_intervention: string;
  delai_j: number;
  delai_elimination_j: number;
  molecule: string | null;
  commentaire: string | null;
  actif: boolean;
};

export type Traitement = {
  id: string;
  cheval_id: string;
  cheval: string;
  location: string | null;
  date: string;
  type_intervention: string;
  catalogue_id: string | null;
  entree_catalogue: string | null;
  molecule: string | null;
  nombre_prises: number;
  intervalle_j: number;
  posologie: string | null;
  ordonnance_numero: string | null;
  ordonnance_url: string | null;
  fin_traitement_reelle: string | null;
  notes: string | null;
  cree_par: string | null;
  duree_j: number;
  fin_traitement: string;
  delai_j: number;
  delai_elimination_j: number;
  delai_total: number;
  entree_manquante: boolean;
  peut_courir_le: string;
  fin_calendrier: string;
  en_cours: boolean;
  prise_due_aujourdhui: boolean;
  administre_aujourdhui: boolean;
};

export type LigneVetList = {
  cheval_id: string;
  cheval: string;
  location: string | null;
  peut_courir: boolean;
  libre_le: string | null;
  jours_restants: number;
  traitement_bloquant: string | null;
  motif: string | null;
  type_bloquant: string | null;
};
