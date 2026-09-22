import { supabaseServer } from '@/lib/supabase/server';
import { sessionCourante } from '@/lib/session';
import TraitementsDuJour from '@/components/TraitementsDuJour';
import { formatLong, aujourdhui } from '@/lib/format';
import type { Traitement } from '@/lib/types';

export const dynamic = 'force-dynamic';

export default async function PageJour() {
  const session = await sessionCourante();
  const supabase = await supabaseServer();

  const { data, error } = await supabase
    .from('v_traitements')
    .select('*')
    .eq('en_cours', true)
    .order('cheval');

  return (
    <>
      <div className="entete">
        <div>
          <h1>Traitements du jour</h1>
          <p>{formatLong(aujourdhui())} — traitements en cours à administrer</p>
        </div>
      </div>

      {error ? (
        <div className="message erreur">Lecture impossible : {error.message}</div>
      ) : (
        <TraitementsDuJour
          traitements={(data ?? []) as Traitement[]}
          peutSaisir={Boolean(session?.peutSaisir)}
        />
      )}
    </>
  );
}
