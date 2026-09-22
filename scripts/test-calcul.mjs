#!/usr/bin/env node
/**
 * Vérifie que l'aperçu affiché dans le formulaire donne exactement les
 * mêmes dates que la vue SQL v_traitements (cas de supabase/03_tests.sql).
 *
 * Modèle : une ligne de traitement pointe vers une entrée du référentiel.
 * Son délai vient de cette entrée, et d'elle seule. Quand un cheval a
 * plusieurs lignes, c'est vet_list qui retient la plus longue — pas ce
 * calcul, qui ne voit qu'une ligne à la fois.
 *
 * Lancer : node scripts/test-calcul.mjs
 */

// Copie fidèle de src/lib/calcul.ts (le script tourne hors bundler TS).
function dateLocale(iso) {
  const [a, m, j] = iso.slice(0, 10).split('-').map(Number);
  return new Date(a, m - 1, j);
}
function isoPlus(iso, jours) {
  const d = dateLocale(iso);
  d.setDate(d.getDate() + jours);
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
}
function calculer(e) {
  const dureeJ = Math.max((e.nombrePrises - 1) * e.intervalleJ + 1, 1);
  const finTraitement = e.finTraitementReelle || isoPlus(e.date, dureeJ - 1);
  const delaiTotal = e.delaiJ + e.delaiEliminationJ;
  return {
    dureeJ, finTraitement, delaiTotal,
    peutCourirLe: isoPlus(finTraitement, delaiTotal + 1),
  };
}

const cas = [
  // --- Durée et fin de traitement ---
  { titre: 'Borgal, 5 prises x 1 j, délai 3',
    e: { date: '2026-09-01', nombrePrises: 5, intervalleJ: 1, delaiJ: 3, delaiEliminationJ: 0 },
    attendu: { dureeJ: 5, finTraitement: '2026-09-05', peutCourirLe: '2026-09-09' } },
  { titre: 'Traitement espacé : 3 prises tous les 7 j = 15 j',
    e: { date: '2026-09-01', nombrePrises: 3, intervalleJ: 7, delaiJ: 3, delaiEliminationJ: 0 },
    attendu: { dureeJ: 15, finTraitement: '2026-09-15', peutCourirLe: '2026-09-19' } },
  { titre: 'Arrêt anticipé : la fin réelle prime',
    e: { date: '2026-09-01', nombrePrises: 5, intervalleJ: 1, delaiJ: 3, delaiEliminationJ: 0,
         finTraitementReelle: '2026-09-03' },
    attendu: { dureeJ: 5, finTraitement: '2026-09-03', peutCourirLe: '2026-09-07' } },

  // --- Le délai vient de l'entrée du référentiel, et d'elle seule ---
  { titre: 'Gastrogard 5 + 3 : total 8',
    e: { date: '2026-09-01', nombrePrises: 1, intervalleJ: 1, delaiJ: 5, delaiEliminationJ: 3 },
    attendu: { delaiTotal: 8, finTraitement: '2026-09-01', peutCourirLe: '2026-09-10' } },
  { titre: 'Dos/Méso 30 : une intervention, entrée comme les autres',
    e: { date: '2026-08-28', nombrePrises: 1, intervalleJ: 1, delaiJ: 30, delaiEliminationJ: 0 },
    attendu: { delaiTotal: 30, peutCourirLe: '2026-09-28' } },
  { titre: 'Ondes de choc 5 : entrée du référentiel, pas un type à part',
    e: { date: '2026-08-28', nombrePrises: 1, intervalleJ: 1, delaiJ: 5, delaiEliminationJ: 0 },
    attendu: { delaiTotal: 5, peutCourirLe: '2026-09-03' } },
  { titre: 'Histabiosone 21 + 3 : le délai le plus long du référentiel',
    e: { date: '2026-09-01', nombrePrises: 1, intervalleJ: 1, delaiJ: 21, delaiEliminationJ: 3 },
    attendu: { delaiTotal: 24, peutCourirLe: '2026-09-26' } },
  { titre: 'Entrée sans délai : le cheval court le lendemain',
    e: { date: '2026-09-01', nombrePrises: 1, intervalleJ: 1, delaiJ: 0, delaiEliminationJ: 0 },
    attendu: { delaiTotal: 0, peutCourirLe: '2026-09-02' } },

  // --- Bords de calendrier ---
  { titre: "Passage d'année (décembre vers janvier)",
    e: { date: '2026-12-28', nombrePrises: 3, intervalleJ: 2, delaiJ: 3, delaiEliminationJ: 0 },
    attendu: { dureeJ: 5, finTraitement: '2027-01-01', peutCourirLe: '2027-01-05' } },
  { titre: 'Année bissextile (février 2028)',
    e: { date: '2028-02-26', nombrePrises: 4, intervalleJ: 1, delaiJ: 0, delaiEliminationJ: 0 },
    attendu: { dureeJ: 4, finTraitement: '2028-02-29', peutCourirLe: '2028-03-01' } },
];

let echecs = 0;
for (const c of cas) {
  const obtenu = calculer(c.e);
  const ok = Object.entries(c.attendu).every(([k, v]) => obtenu[k] === v);
  if (!ok) echecs++;
  console.log(`${ok ? '✓' : '✗'} ${c.titre}`);
  if (!ok) console.log(`   attendu ${JSON.stringify(c.attendu)}\n   obtenu  ${JSON.stringify(obtenu)}`);
}
console.log(echecs === 0 ? `\n${cas.length}/${cas.length} cas conformes.` : `\n${echecs} échec(s).`);
process.exit(echecs === 0 ? 0 : 1);
