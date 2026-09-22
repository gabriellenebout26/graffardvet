'use client';

import { useState } from 'react';
import { supabaseBrowser } from '@/lib/supabase/client';

export default function Connexion() {
  const [email, setEmail] = useState('');
  const [etat, setEtat] = useState<'saisie' | 'envoi' | 'envoye'>('saisie');
  const [erreur, setErreur] = useState<string | null>(null);

  async function envoyer(e: React.FormEvent) {
    e.preventDefault();
    setEtat('envoi');
    setErreur(null);
    const { error } = await supabaseBrowser().auth.signInWithOtp({
      email: email.trim(),
      options: { emailRedirectTo: `${window.location.origin}/auth/retour` },
    });
    if (error) {
      setErreur(error.message);
      setEtat('saisie');
    } else {
      setEtat('envoye');
    }
  }

  return (
    <main style={{
      minHeight: '100vh', display: 'grid', placeItems: 'center',
      background: 'var(--ardoise)', padding: '1.5rem',
    }}>
      <div className="carte" style={{ width: 'min(400px, 100%)', padding: '2rem' }}>
        <div style={{ fontFamily: 'var(--serif)', fontSize: '1.7rem', color: 'var(--ardoise)' }}>
          Écurie Graffard
        </div>
        <div className="etiquette" style={{ marginBottom: '1.75rem' }}>
          Suivi des traitements
        </div>

        {etat === 'envoye' ? (
          <div className="message succes" style={{ marginBottom: 0 }}>
            Lien de connexion envoyé à <strong>{email}</strong>. Ouvrez-le depuis
            cet appareil — il est valable une heure.
          </div>
        ) : (
          <form onSubmit={envoyer}>
            {erreur && <div className="message erreur">{erreur}</div>}
            <label className="champ">
              <span>Adresse email</span>
              <input
                type="email" required autoFocus value={email}
                onChange={(e) => setEmail(e.target.value)}
                placeholder="prenom@ecurie-graffard.com"
              />
            </label>
            <button className="bouton" style={{ width: '100%', justifyContent: 'center' }}
              disabled={etat === 'envoi'}>
              {etat === 'envoi' ? 'Envoi…' : 'Recevoir mon lien de connexion'}
            </button>
            <p style={{ fontSize: '0.8rem', color: 'var(--gris)', marginTop: '1rem', marginBottom: 0 }}>
              Pas de mot de passe : vous recevez un lien à usage unique.
              Seules les adresses enregistrées par l&apos;écurie ont accès.
            </p>
          </form>
        )}
      </div>
    </main>
  );
}
