import { supabaseServer } from '@/lib/supabase/server';
import type { Role } from '@/lib/types';

export type Session = {
  email: string;
  nom: string;
  role: Role;
  peutSaisir: boolean;
  estAdmin: boolean;
  inscrit: boolean;
};

export async function sessionCourante(): Promise<Session | null> {
  const supabase = await supabaseServer();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user?.email) return null;

  const { data } = await supabase
    .from('responsables')
    .select('nom, role')
    .ilike('email', user.email)
    .maybeSingle();

  const role = (data?.role ?? 'consultation') as Role;
  return {
    email: user.email,
    nom: data?.nom ?? user.email,
    role,
    peutSaisir: role === 'saisie' || role === 'admin',
    estAdmin: role === 'admin',
    inscrit: Boolean(data),
  };
}
