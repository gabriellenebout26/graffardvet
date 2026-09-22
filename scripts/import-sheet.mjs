#!/usr/bin/env node
/**
 * Import des données depuis Suivi_Ecurie_Graffard_v2 (Google Sheets) vers Supabase.
 *
 * 1. Dans le Sheet : Fichier > Télécharger > CSV, pour chacun des 3 onglets.
 *    Les placer dans ./data/ sous les noms chevaux.csv, medicaments.csv, traitements.csv
 * 2. Renseigner .env.local (voir .env.example)
 * 3. node scripts/import-sheet.mjs --dry     (vérification, n'écrit rien)
 *    node scripts/import-sheet.mjs           (import réel)
 *
 * Le script est idempotent : relançable sans créer de doublons.
 */
import { readFileSync, existsSync } from 'node:fs';
import { parse } from 'csv-parse/sync';
import { createClient } from '@supabase/supabase-js';
import 'dotenv/config';

const DRY = process.argv.includes('--dry');
const DIR = process.env.IMPORT_DIR ?? './data';

// --- Correspondance colonnes CSV -> colonnes Supabase -----------------
// Ajuster ici si les en-têtes du Sheet diffèrent. Insensible à la casse
// et aux accents.
const MAP = {
  chevaux: {
    nom: ['nom', 'cheval', 'nom du cheval'],
    sexe: ['sexe'],
    annee_naissance: ['annee de naissance', 'annee naissance', 'ne en'],
    proprietaire: ['proprietaire', 'proprietaires'],
    location: ['location', 'cour', 'emplacement', 'box'],
  },
  medicaments: {
    nom: ['nom', 'medicament', 'produit'],
    delai_j: ['delai indicatif ordonnance', 'delai', 'delai (j)', 'delai j'],
    delai_elimination_j: ['delai elimination', 'delai elimination (j)', 'delai engagement supplementaire'],
    expression_ordonnance: ['expression ordonnance', 'molecule'],
    commentaire: ['comments', 'commentaire', 'commentaires'],
  },
  traitements: {
    cheval: ['cheval', 'nom du cheval'],
    date: ['date', 'date de traitement'],
    type: ["type d'evenement", 'type evenement', 'type'],
    medicament: ['medicament', 'produit'],
    nombre_prises: ['nombre de prise', 'nombre de prises', 'nb prises'],
    intervalle_j: ['intervalle (j)', 'intervalle', 'intervalle j'],
    posologie: ['posologie'],
    ordonnance_numero: ['ordonnance', 'numero ordonnance', "n ordonnance"],
    ordonnance_url: ['ordonnance pdf', 'pdf'],
    fin_traitement_reelle: ['fin de traitement reelle', 'fin reelle'],
    notes: ['notes', 'remarque', 'remarques'],
  },
};

const TYPES_VALIDES = [
  'Administration médicament', 'Infiltration', 'Vaccin', 'Bilan sanguin',
  'Radio/Imagerie', 'Vulvoplastie', 'Ondes de choc', 'Scope',
  'Scope Embarqué', 'Vermifuge',
];

// --- Utilitaires ------------------------------------------------------
const norm = (s) =>
  String(s ?? '').normalize('NFD').replace(/[̀-ͯ]/g, '')
    .toLowerCase().replace(/[^a-z0-9]+/g, ' ').trim();

/** Nom de cheval canonique : "Silent Warning (IRE)" -> "SILENT WARNING IRE" */
const nomCanonique = (s) =>
  String(s ?? '').replace(/[()]/g, ' ').replace(/\s+/g, ' ').trim().toUpperCase();

function pick(row, candidats) {
  const index = Object.fromEntries(Object.keys(row).map((k) => [norm(k), k]));
  for (const c of candidats) {
    const k = index[norm(c)];
    if (k !== undefined && String(row[k]).trim() !== '') return String(row[k]).trim();
  }
  return null;
}

/** Accepte 12/03/2026, 12-03-2026, 2026-03-12 */
function parseDate(v) {
  if (!v) return null;
  const s = String(v).trim();
  let m = s.match(/^(\d{4})-(\d{2})-(\d{2})/);
  if (m) return `${m[1]}-${m[2]}-${m[3]}`;
  m = s.match(/^(\d{1,2})[/\-.](\d{1,2})[/\-.](\d{2,4})/);
  if (m) {
    const [, d, mo, y] = m;
    const yyyy = y.length === 2 ? `20${y}` : y;
    return `${yyyy}-${mo.padStart(2, '0')}-${d.padStart(2, '0')}`;
  }
  return null;
}

const toInt = (v, def = null) => {
  const n = parseInt(String(v ?? '').replace(/[^0-9-]/g, ''), 10);
  return Number.isFinite(n) ? n : def;
};

function lire(fichier) {
  const chemin = `${DIR}/${fichier}`;
  if (!existsSync(chemin)) {
    console.error(`✗ Fichier manquant : ${chemin}`);
    process.exit(1);
  }
  return parse(readFileSync(chemin), { columns: true, skip_empty_lines: true, bom: true, trim: true });
}

// --- Import -----------------------------------------------------------
const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
const key = process.env.SUPABASE_SERVICE_ROLE_KEY;
if (!DRY && (!url || !key)) {
  console.error('✗ NEXT_PUBLIC_SUPABASE_URL et SUPABASE_SERVICE_ROLE_KEY requis dans .env.local');
  process.exit(1);
}
const db = DRY ? null : createClient(url, key, { auth: { persistSession: false } });

const alertes = [];

// 1. Chevaux
const chevauxCsv = lire('chevaux.csv');
const chevaux = chevauxCsv
  .map((r) => ({
    nom: nomCanonique(pick(r, MAP.chevaux.nom)),
    sexe: pick(r, MAP.chevaux.sexe),
    annee_naissance: toInt(pick(r, MAP.chevaux.annee_naissance)),
    proprietaire: pick(r, MAP.chevaux.proprietaire),
    location: pick(r, MAP.chevaux.location),
  }))
  .filter((c) => c.nom);

// 2. Médicaments
const medicamentsCsv = lire('medicaments.csv');
const medicaments = medicamentsCsv
  .map((r) => ({
    nom: (pick(r, MAP.medicaments.nom) ?? '').trim(),
    delai_j: toInt(pick(r, MAP.medicaments.delai_j), 0),
    delai_elimination_j: toInt(pick(r, MAP.medicaments.delai_elimination_j), 0),
    expression_ordonnance: pick(r, MAP.medicaments.expression_ordonnance),
    commentaire: pick(r, MAP.medicaments.commentaire),
  }))
  .filter((m) => m.nom);

for (const m of medicaments) {
  if (m.delai_j === 0) alertes.push(`Médicament « ${m.nom} » : délai à 0 j — à vérifier avec Chris.`);
}

console.log(`Chevaux     : ${chevaux.length}`);
console.log(`Médicaments : ${medicaments.length}`);

if (!DRY) {
  for (const lot of [['chevaux', chevaux], ['medicaments', medicaments]]) {
    const { error } = await db.from(lot[0]).upsert(lot[1], { onConflict: 'nom' });
    if (error) { console.error(`✗ ${lot[0]} :`, error.message); process.exit(1); }
  }
}

// 3. Traitements — nécessite les ids des chevaux et médicaments
let idsChevaux = new Map(), idsMedicaments = new Map();
if (!DRY) {
  const { data: cs } = await db.from('chevaux').select('id, nom');
  const { data: ms } = await db.from('medicaments').select('id, nom');
  idsChevaux = new Map((cs ?? []).map((c) => [norm(c.nom), c.id]));
  idsMedicaments = new Map((ms ?? []).map((m) => [norm(m.nom), m.id]));
} else {
  idsChevaux = new Map(chevaux.map((c) => [norm(c.nom), 'dry']));
  idsMedicaments = new Map(medicaments.map((m) => [norm(m.nom), 'dry']));
}

const traitementsCsv = lire('traitements.csv');
const traitements = [];

traitementsCsv.forEach((r, i) => {
  const ligne = i + 2; // +1 en-tête, +1 base 1
  const chevalNom = nomCanonique(pick(r, MAP.traitements.cheval));
  const cheval_id = idsChevaux.get(norm(chevalNom));
  if (!cheval_id) { alertes.push(`Ligne ${ligne} : cheval inconnu « ${chevalNom} » — traitement ignoré.`); return; }

  const date = parseDate(pick(r, MAP.traitements.date));
  if (!date) { alertes.push(`Ligne ${ligne} (${chevalNom}) : date illisible — traitement ignoré.`); return; }

  let type = pick(r, MAP.traitements.type) ?? 'Administration médicament';
  const match = TYPES_VALIDES.find((t) => norm(t) === norm(type));
  if (!match) { alertes.push(`Ligne ${ligne} (${chevalNom}) : type « ${type} » inconnu, remplacé par Administration médicament.`); }
  type = match ?? 'Administration médicament';

  const medNom = pick(r, MAP.traitements.medicament);
  const medicament_id = medNom ? idsMedicaments.get(norm(medNom)) ?? null : null;
  if (medNom && !medicament_id) alertes.push(`Ligne ${ligne} (${chevalNom}) : médicament « ${medNom} » absent du référentiel.`);
  if (type === 'Administration médicament' && !medicament_id) {
    alertes.push(`Ligne ${ligne} (${chevalNom}) : administration sans médicament valide — traitement ignoré.`);
    return;
  }

  traitements.push({
    cheval_id, date, type, medicament_id,
    nombre_prises: Math.max(toInt(pick(r, MAP.traitements.nombre_prises), 1) ?? 1, 1),
    intervalle_j: Math.max(toInt(pick(r, MAP.traitements.intervalle_j), 1) ?? 1, 1),
    posologie: pick(r, MAP.traitements.posologie),
    ordonnance_numero: pick(r, MAP.traitements.ordonnance_numero),
    ordonnance_url: pick(r, MAP.traitements.ordonnance_url),
    fin_traitement_reelle: parseDate(pick(r, MAP.traitements.fin_traitement_reelle)),
    notes: pick(r, MAP.traitements.notes),
    cree_par: 'import',
  });
});

console.log(`Traitements : ${traitements.length} retenus sur ${traitementsCsv.length} lignes`);

if (!DRY && traitements.length) {
  for (let i = 0; i < traitements.length; i += 500) {
    const { error } = await db.from('traitements').insert(traitements.slice(i, i + 500));
    if (error) { console.error('✗ traitements :', error.message); process.exit(1); }
  }
}

// --- Rapport ----------------------------------------------------------
if (alertes.length) {
  console.log(`\n⚠️  ${alertes.length} alerte(s) :`);
  alertes.forEach((a) => console.log('   ' + a));
} else {
  console.log('\n✓ Aucune alerte.');
}
console.log(DRY ? '\n(mode --dry : rien n\'a été écrit)' : '\n✓ Import terminé.');
