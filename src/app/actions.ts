'use server';

import { revalidatePath } from 'next/cache';
import { redirect } from 'next/navigation';
import { supabaseServer } from '@/lib/supabase/server';
import { sessionCourante } from '@/lib/session';
import { TYPES_EVENEMENT, type TypeEvenement } from '@/lib/types';

export type Resultat = { erreur?: string; succes?: string };

async function exigeSaisie() {
  const session = await sessionCourante();
  if (!session?.peutSaisir) throw new Error('Droits insuffisants.');
  return session;
}

/** Action « Administré aujourd'hui » — anti double-clic géré par la contrainte unique. */
export async function administreAujourdhui(traitementId: string): Promise<Resultat> {
  const session = await exigeSaisie();
  const supabase = await supabaseServer();

  const { error } = await supabase.from('administrations').insert({
    traitement_id: traitementId,
    par: session.email,
  });

  if (error) {
    if (error.code === '23505') return { succes: 'Déjà enregistré pour aujourd\'hui.' };
    return { erreur: error.message };
  }
  revalidatePath('/jour');
  revalidatePath('/');
  return { succes: 'Administration enregistrée.' };
}

/** Action « Arrêter le traitement » — écrit la date du jour en fin réelle. */
export async function arreterTraitement(traitementId: string): Promise<Resultat> {
  await exigeSaisie();
  const supabase = await supabaseServer();

  const { error } = await supabase
    .from('traitements')
    .update({ fin_traitement_reelle: new Date().toISOString().slice(0, 10) })
    .eq('id', traitementId);

  if (error) return { erreur: error.message };
  revalidatePath('/jour');
  revalidatePath('/');
  return { succes: 'Traitement arrêté. Les délais sont recalculés.' };
}

export async function annulerArret(traitementId: string): Promise<Resultat> {
  await exigeSaisie();
  const supabase = await supabaseServer();
  const { error } = await supabase
    .from('traitements')
    .update({ fin_traitement_reelle: null })
    .eq('id', traitementId);
  if (error) return { erreur: error.message };
  revalidatePath('/jour');
  revalidatePath('/');
  return { succes: 'Arrêt annulé.' };
}

/** Création d'un traitement. Utilisée aussi par « Dupliquer » (formulaire prérempli). */
export async function creerTraitement(
  _etat: Resultat | null,
  data: FormData,
): Promise<Resultat> {
  const session = await exigeSaisie();
  const supabase = await supabaseServer();

  const texte = (k: string) => {
    const v = data.get(k);
    return typeof v === 'string' && v.trim() !== '' ? v.trim() : null;
  };
  const entier = (k: string, def: number) => {
    const n = parseInt(String(data.get(k) ?? ''), 10);
    return Number.isFinite(n) && n > 0 ? n : def;
  };

  const type = texte('type') as TypeEvenement | null;
  const cheval_id = texte('cheval_id');
  const date = texte('date');
  const catalogue_id = texte('catalogue_id');

  if (!cheval_id) return { erreur: 'Sélectionnez un cheval.' };
  if (!date) return { erreur: 'La date est obligatoire.' };
  if (!type || !TYPES_EVENEMENT.includes(type)) return { erreur: "Type d'intervention invalide." };

  // Certains types attendent un traitement du référentiel, d'autres non
  // (scope, radio, bilan sanguin). C'est la base qui le dit.
  const { data: typeInfo } = await supabase
    .from('types_intervention')
    .select('avec_catalogue')
    .eq('type', type)
    .maybeSingle();

  if ((typeInfo?.avec_catalogue ?? true) && !catalogue_id) {
    return { erreur: `Un traitement du référentiel est attendu pour « ${type} ».` };
  }

  const { error } = await supabase.from('traitements').insert({
    cheval_id,
    date,
    type,
    catalogue_id: catalogue_id,
    nombre_prises: entier('nombre_prises', 1),
    intervalle_j: entier('intervalle_j', 1),
    posologie: texte('posologie'),
    ordonnance_numero: texte('ordonnance_numero'),
    notes: texte('notes'),
    cree_par: session.email,
  });

  if (error) return { erreur: error.message };

  revalidatePath('/');
  revalidatePath('/jour');
  if (data.get('encore') === '1') {
    redirect(`/traitements/nouveau?cheval=${cheval_id}&date=${date}&ok=1`);
  }
  redirect(`/chevaux/${cheval_id}?ok=1`);
}

export async function supprimerTraitement(traitementId: string): Promise<Resultat> {
  await exigeSaisie();
  const supabase = await supabaseServer();
  const { error } = await supabase.from('traitements').delete().eq('id', traitementId);
  if (error) return { erreur: error.message };
  revalidatePath('/');
  revalidatePath('/jour');
  return { succes: 'Traitement supprimé.' };
}
