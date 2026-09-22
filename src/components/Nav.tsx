'use client';

import Link from 'next/link';
import { usePathname, useRouter } from 'next/navigation';
import { supabaseBrowser } from '@/lib/supabase/client';

const liens = [
  { href: '/', label: 'Vet List', exact: true },
  { href: '/jour', label: 'Traitements du jour' },
  { href: '/chevaux', label: 'Chevaux' },
  { href: '/traitements/nouveau', label: 'Nouveau traitement', saisie: true },
  { href: '/catalogue', label: 'Catalogue', admin: true },
  { href: '/utilisateurs', label: 'Utilisateurs', admin: true },
];

export default function Nav({ nom, role }: { nom: string; role: string }) {
  const chemin = usePathname();
  const router = useRouter();

  async function deconnexion() {
    await supabaseBrowser().auth.signOut();
    router.push('/connexion');
    router.refresh();
  }

  const visibles = liens.filter((l) =>
    (!l.admin || role === 'admin') &&
    (!l.saisie || role === 'saisie' || role === 'admin'));

  return (
    <nav className="nav">
      <div className="marque">Écurie Graffard</div>
      <div className="sous-marque">Suivi des traitements</div>

      {visibles.map((l) => {
        const actif = l.exact ? chemin === l.href : chemin.startsWith(l.href);
        return (
          <Link key={l.href} href={l.href} className={actif ? 'actif' : ''}>
            {l.label}
          </Link>
        );
      })}

      <div className="pied">
        <div style={{ color: '#dce6ee' }}>{nom}</div>
        <div style={{ fontFamily: 'var(--mono)', fontSize: '0.68rem', textTransform: 'uppercase', letterSpacing: '0.1em' }}>
          {role}
        </div>
        <button onClick={deconnexion}
          style={{ background: 'none', border: 0, padding: '0.5rem 0 0', color: '#9fb8cc', cursor: 'pointer', fontSize: '0.75rem', textDecoration: 'underline' }}>
          Se déconnecter
        </button>
      </div>
    </nav>
  );
}
