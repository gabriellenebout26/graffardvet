import { createServerClient, type CookieOptions } from '@supabase/ssr';
import { cookies } from 'next/headers';
import { MODE_DEMO, clientDemo } from './demo';

type CookieAPoser = { name: string; value: string; options?: CookieOptions };

/* eslint-disable @typescript-eslint/no-explicit-any */
export async function supabaseServer(): Promise<any> {
  if (MODE_DEMO) return clientDemo();

  const cookieStore = await cookies();
  return createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        getAll: () => cookieStore.getAll(),
        setAll: (toSet: CookieAPoser[]) => {
          try {
            toSet.forEach(({ name, value, options }) =>
              cookieStore.set(name, value, options),
            );
          } catch {
            // appelé depuis un Server Component : le middleware rafraîchit la session
          }
        },
      },
    },
  );
}
