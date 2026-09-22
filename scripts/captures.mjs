import { chromium } from 'playwright';
import { mkdirSync } from 'node:fs';

const BASE = 'http://127.0.0.1:3301';
const SORTIE = process.env.SORTIE ?? '/tmp/captures';
mkdirSync(SORTIE, { recursive: true });

const ecrans = [
  ['01-vet-list', '/', 'Vet List'],
  ['02-vet-list-simulation', '/?date=2026-09-22', 'Vet List — simulation au 22/09'],
  ['03-traitements-du-jour', '/jour', 'Traitements du jour'],
  ['04-nouveau-traitement', '/traitements/nouveau', 'Nouveau traitement'],
  ['05-fiche-cheval', '/chevaux/c1', 'Fiche cheval'],
  ['06-chevaux', '/chevaux', 'Chevaux'],
  ['07-catalogue', '/catalogue', 'Catalogue'],
  ['08-connexion', '/connexion', 'Connexion'],
];

const navigateur = await chromium.launch({
  executablePath: process.env.CHROMIUM ?? '/opt/pw-browsers/chromium-1194/chrome-linux/chrome',
  args: ['--lang=fr-FR'],
});

// Bureau
const bureau = await navigateur.newContext({ viewport: { width: 1440, height: 900 }, deviceScaleFactor: 2, locale: 'fr-FR', timezoneId: 'Europe/Paris' });
for (const [fichier, chemin, titre] of ecrans) {
  const page = await bureau.newPage();
  await page.goto(`${BASE}${chemin}`, { waitUntil: 'networkidle' });
  await page.waitForTimeout(700);
  await page.screenshot({ path: `${SORTIE}/${fichier}.png`, fullPage: true });
  console.log(`✓ ${titre}`);
  await page.close();
}

// Mobile — c'est là que les responsables de cour saisissent
const mobile = await navigateur.newContext({ viewport: { width: 390, height: 844 }, deviceScaleFactor: 3, isMobile: true, hasTouch: true, locale: 'fr-FR', timezoneId: 'Europe/Paris' });
for (const [fichier, chemin, titre] of [ecrans[0], ecrans[2]]) {
  const page = await mobile.newPage();
  await page.goto(`${BASE}${chemin}`, { waitUntil: 'networkidle' });
  await page.waitForTimeout(700);
  await page.screenshot({ path: `${SORTIE}/mobile-${fichier}.png`, fullPage: true });
  console.log(`✓ ${titre} (mobile)`);
  await page.close();
}

await navigateur.close();
