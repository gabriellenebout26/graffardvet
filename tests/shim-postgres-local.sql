-- =====================================================================
-- ⚠️  NE JAMAIS EXÉCUTER CE FICHIER SUR SUPABASE.
--
-- Il ne sert qu'à vérifier supabase/01_schema.sql sur un PostgreSQL nu
-- (machine de développement, intégration continue), en recréant les objets
-- que Supabase fournit nativement : le schéma auth, le schéma storage, le
-- rôle authenticated.
--
-- Sur Supabase ces objets existent déjà ; les recréer casserait
-- l'authentification et le stockage du projet.
--
-- Utilisation : voir tests/README.md
-- =====================================================================

create schema if not exists auth;
create schema if not exists storage;

do $$ begin
  create role authenticated;
exception when duplicate_object then null; end $$;

-- Faux jeton : simule un utilisateur connecté pour tester les politiques RLS.
create or replace function auth.jwt() returns jsonb language sql stable as
  $$ select '{"email":"test@ecurie-graffard.com"}'::jsonb $$;

create table if not exists storage.buckets (id text primary key, name text, public boolean);
create table if not exists storage.objects (id bigserial primary key, bucket_id text);
alter table storage.objects enable row level security;
