import { redirect } from 'next/navigation';
import { supabaseServer } from '@/lib/supabase/server';
import { sessionCourante } from '@/lib/session';
import FormulaireTraitement from '@/components/FormulaireTraitement';
import type { Cheval, EntreeCatalogue, TypeEvenement, TypeIntervention } from '@/lib/types';

export const dynamic = 'force-dynamic';

export default async function PageNouveauTraitement({
  searchParams,
}: {
  searchParams: Promise<{ cheval?: string; entree?: string; type?: string; date?: string; ok?: string }>;
}) {
  const session = await sessionCourante();
  if (!session?.peutSaisir) redirect('/');

  const params = await searchParams;
  const supabase = await supabaseServer();

  const [{ data: chevaux }, { data: entrees }, { data: types }] = await Promise.all([
    supabase.from('chevaux').select('*').eq('actif', true).order('nom'),
    supabase.from('catalogue').select('*').eq('actif', true).order('nom'),
    supabase.from('types_intervention').select('*'),
  ]);

  return (
    <>
      <div className="entete">
        <div>
          <h1>Nouvelle intervention</h1>
          <p>Le type d&apos;intervention d&apos;abord ; le traitement associé s&apos;il y en a un.</p>
        </div>
      </div>

      {params.ok === '1' && (
        <div className="message succes">Traitement enregistré.</div>
      )}

      <FormulaireTraitement
        chevaux={(chevaux ?? []) as Cheval[]}
        catalogue={(entrees ?? []) as EntreeCatalogue[]}
        typesIntervention={(types ?? []) as TypeIntervention[]}
        prerempli={{
          cheval_id: params.cheval ?? '',
          catalogue_id: params.entree ?? '',
          type: (params.type as TypeEvenement) ?? 'Administration médicament',
          date: params.date ?? '',
        }}
      />
    </>
  );
}
