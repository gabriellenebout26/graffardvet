/**
 * Miroir en TypeScript des formules de la vue SQL `v_traitements`.
 *
 * Modèle : une ligne de traitement pointe vers une entrée du référentiel
 * (médicament, intervention ou vaccin). Le délai vient de cette entrée.
 * Quand un cheval a plusieurs lignes, la plus longue l'emporte — c'est la
 * fonction vet_list qui s'en charge, pas ce calcul.
 * Sert uniquement à l'aperçu en direct dans le formulaire de saisie :
 * la valeur enregistrée reste toujours celle calculée par la base.
 * Toute modification ici doit être répercutée dans supabase/01_schema.sql.
 */
import { dateLocale } from './format';

export function isoPlus(iso: string, jours: number): string {
  const d = dateLocale(iso);
  if (!d) return '';
  d.setDate(d.getDate() + jours);
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
}

export type EntreeCalcul = {
  date: string;
  nombrePrises: number;
  intervalleJ: number;
  /** Délai de l'entrée du référentiel choisie. */
  delaiJ: number;
  /** Délai d'élimination de cette même entrée (+3 j partant probable). */
  delaiEliminationJ: number;
  finTraitementReelle?: string | null;
};

export type Calcul = {
  dureeJ: number;
  finTraitement: string;
  peutCourirLe: string;
  /** Délai total appliqué : délai + élimination. */
  delaiTotal: number;
  finCalendrier: string;
};

export function calculer(e: EntreeCalcul): Calcul {
  // Durée (j) = (Nombre de prises − 1) × Intervalle (j) + 1
  const dureeJ = Math.max((e.nombrePrises - 1) * e.intervalleJ + 1, 1);

  // Fin de traitement = Date + Durée − 1, ou la fin réelle si arrêt anticipé
  const finTraitement = e.finTraitementReelle || isoPlus(e.date, dureeJ - 1);

  // Le délai vient de l'entrée du référentiel, et d'elle seule.
  const delaiTotal = e.delaiJ + e.delaiEliminationJ;

  // + 1 jour (article 85 : le délai est exclusif)
  const peutCourirLe = isoPlus(finTraitement, delaiTotal + 1);

  return {
    dureeJ, finTraitement, peutCourirLe, delaiTotal,
    finCalendrier: isoPlus(finTraitement, 1),
  };
}
