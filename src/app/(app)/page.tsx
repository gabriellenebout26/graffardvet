import { supabaseServer } from '@/lib/supabase/server';
import VetList from '@/components/VetList';
import { aujourdhui } from '@/lib/format';
import type { LigneVetList, Traitement } from '@/lib/types';

export const dynamic = 'force-dynamic';

export default async function PageVetList({
  searchParams,
}: {
  searchParams: Promise<{ date?: string }>;
}) {
  const params = await searchParams;
  const dateRef = /^\d{4}-\d{2}-\d{2}$/.test(params.date ?? '') ? params.date! : aujourdhui();

  const supabase = await supabaseServer();
  const [{ data: lignes, error }, { data: traitements }] = await Promise.all([
    supabase.rpc('vet_list', { date_reference: dateRef }),
    supabase.from('v_traitements').select('*').order('date', { ascending: false }),
  ]);

  if (error) {
    return (
      <>
        <h1>Vet List</h1>
        <div className="message erreur">Lecture impossible : {error.message}</div>
      </>
    );
  }

  return (
    <VetList
      dateRef={dateRef}
      lignes={(lignes ?? []) as LigneVetList[]}
      traitements={(traitements ?? []) as Traitement[]}
    />
  );
}
