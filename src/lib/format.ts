const jours = ['dimanche', 'lundi', 'mardi', 'mercredi', 'jeudi', 'vendredi', 'samedi'];
const mois = ['janvier', 'février', 'mars', 'avril', 'mai', 'juin',
  'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'];

/** Une date ISO (AAAA-MM-JJ) sans décalage de fuseau. */
export function dateLocale(iso: string | null | undefined): Date | null {
  if (!iso) return null;
  const [a, m, j] = iso.slice(0, 10).split('-').map(Number);
  if (!a || !m || !j) return null;
  return new Date(a, m - 1, j);
}

export function formatCourt(iso: string | null | undefined): string {
  const d = dateLocale(iso);
  if (!d) return '—';
  return `${String(d.getDate()).padStart(2, '0')}/${String(d.getMonth() + 1).padStart(2, '0')}/${d.getFullYear()}`;
}

export function formatLong(iso: string | null | undefined): string {
  const d = dateLocale(iso);
  if (!d) return '—';
  return `${jours[d.getDay()]} ${d.getDate()} ${mois[d.getMonth()]}`;
}

/** Date du jour au format AAAA-MM-JJ, dans le fuseau du navigateur/serveur. */
export function aujourdhui(): string {
  const d = new Date();
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
}

export function joursEntre(debut: string, fin: string): number {
  const a = dateLocale(debut), b = dateLocale(fin);
  if (!a || !b) return 0;
  return Math.round((b.getTime() - a.getTime()) / 86_400_000);
}

export function pluriel(n: number, singulier: string, pluriel_?: string): string {
  return `${n} ${n > 1 ? (pluriel_ ?? singulier + 's') : singulier}`;
}
