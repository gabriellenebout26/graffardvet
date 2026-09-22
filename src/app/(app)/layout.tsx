import { redirect } from 'next/navigation';
import Nav from '@/components/Nav';
import { sessionCourante } from '@/lib/session';

export default async function LayoutApp({ children }: { children: React.ReactNode }) {
  const session = await sessionCourante();
  if (!session) redirect('/connexion');

  if (!session.inscrit) {
    return (
      <main style={{ minHeight: '100vh', display: 'grid', placeItems: 'center', padding: '1.5rem' }}>
        <div className="carte" style={{ maxWidth: 440 }}>
          <h2>Accès non ouvert</h2>
          <p style={{ color: 'var(--gris)' }}>
            L&apos;adresse <strong>{session.email}</strong> n&apos;est pas encore
            enregistrée. Demandez à Gabrielle de vous ajouter aux utilisateurs.
          </p>
        </div>
      </main>
    );
  }

  return (
    <div className="app">
      <Nav nom={session.nom} role={session.role} />
      <div className="contenu">{children}</div>
    </div>
  );
}
