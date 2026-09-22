-- =====================================================================
-- Écurie Graffard — Suivi des traitements et de l'éligibilité aux courses
-- Schéma Supabase / PostgreSQL
-- À exécuter dans : Supabase > SQL Editor > New query
-- =====================================================================

create extension if not exists "pgcrypto";

-- ---------------------------------------------------------------------
-- 1. RÉFÉRENTIELS
-- ---------------------------------------------------------------------

-- Rôles applicatifs
do $$ begin
  create type role_app as enum ('admin', 'saisie', 'consultation');
exception when duplicate_object then null; end $$;

-- Responsables : qui a accès à quoi. La clé est l'email du compte Supabase.
create table if not exists responsables (
  id          uuid primary key default gen_random_uuid(),
  email       text unique not null,
  nom         text not null,
  role        role_app not null default 'consultation',
  actif       boolean not null default true,
  created_at  timestamptz not null default now()
);

comment on table responsables is
  'Annuaire des utilisateurs. role=saisie pour les responsables de cour, consultation pour Francis et Romain.';

-- Chevaux
create table if not exists chevaux (
  id            uuid primary key default gen_random_uuid(),
  nom           text unique not null,        -- format canonique : "SILENT WARNING IRE"
  sexe          text,
  annee_naissance smallint,
  proprietaire  text,
  location      text,                        -- cour / boxe, repris dans la Vet List
  actif         boolean not null default true,
  created_at    timestamptz not null default now()
);

create index if not exists chevaux_actif_nom_idx on chevaux (actif, nom);

-- Types d'événement : une étiquette de classement, sans effet sur le calcul
do $$ begin
  create type type_evenement as enum (
    'Administration médicament',
    'Infiltration',
    'Vaccin',
    'Bilan sanguin',
    'Radio/Imagerie',
    'Vulvoplastie',
    'Ondes de choc',
    'Scope',
    'Scope Embarqué',
    'Vermifuge'
  );
exception when duplicate_object then null; end $$;

-- Pour chaque type : attend-il un traitement du référentiel ?
-- Les actes d'examen (scope, radio, bilan sanguin) n'en ont pas, et
-- n'entraînent aucun délai. Cette table ne porte aucun délai elle-même.
create table if not exists types_intervention (
  type                 type_evenement primary key,
  necessite_traitement boolean not null default true,
  commentaire          text
);

insert into types_intervention (type, necessite_traitement, commentaire) values
  ('Administration médicament', true,  'Le produit prescrit'),
  ('Infiltration',              true,  'Dos/Méso, Horstem, IRAP'),
  ('Vulvoplastie',              true,  'Les produits sont toujours écrits'),
  ('Ondes de choc',             true,  'Entrée « Ondes de choc » du référentiel'),
  ('Vaccin',                    true,  'Grippe, Rhino'),
  ('Vermifuge',                 true,  'Adequan'),
  ('Scope',                     false, 'Acte d''examen, aucun délai'),
  ('Scope Embarqué',            false, 'Acte d''examen, aucun délai'),
  ('Radio/Imagerie',            false, 'Acte d''examen, aucun délai'),
  ('Bilan sanguin',             false, 'Acte d''examen, aucun délai')
on conflict (type) do nothing;

-- Référentiel : médicaments, interventions et vaccins dans une seule liste.
-- Le délai d'une ligne de traitement vient de son entrée ici, et d'elle seule.
create table if not exists medicaments (
  id                    uuid primary key default gen_random_uuid(),
  nom                   text unique not null,
  delai_j               integer not null default 0,  -- délai indicatif d'attente (ordonnance)
  delai_elimination_j   integer not null default 0,  -- art. 198, souvent +3 j (partant probable)
  evenement_compatible  type_evenement,              -- type d'événement auquel l'entrée se rattache
  expression_ordonnance text,                        -- libellé tel qu'écrit par le vétérinaire
  commentaire           text,
  actif                 boolean not null default true,
  created_at            timestamptz not null default now()
);

comment on column medicaments.delai_elimination_j is
  'Jours ajoutés pour la déclaration de partant probable (~3 j avant la course), où le cheval peut être contrôlé.';

-- ---------------------------------------------------------------------
-- 2. TRAITEMENTS — une ligne par médicament prescrit
-- ---------------------------------------------------------------------

create table if not exists traitements (
  id                    uuid primary key default gen_random_uuid(),
  cheval_id             uuid not null references chevaux(id) on delete restrict,
  date                  date not null,
  type                  type_evenement not null default 'Administration médicament',
  medicament_id         uuid references medicaments(id) on delete restrict,

  nombre_prises         integer not null default 1 check (nombre_prises >= 1),
  intervalle_j          integer not null default 1 check (intervalle_j >= 1),
  posologie             text,

  ordonnance_numero     text,
  ordonnance_url        text,          -- fichier dans le bucket Storage "ordonnances"

  fin_traitement_reelle date,          -- renseignée par l'action « Arrêter le traitement »
  notes                 text,

  cree_par              text,          -- email
  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now()
);

create index if not exists traitements_cheval_date_idx on traitements (cheval_id, date desc);
create index if not exists traitements_date_idx on traitements (date desc);

-- Toute ligne de traitement pointe vers une entrée du référentiel :
-- c'est elle qui porte le délai.
alter table traitements drop constraint if exists traitements_medicament_requis;

-- Journal des administrations (action « Administré aujourd'hui »)
create table if not exists administrations (
  id            uuid primary key default gen_random_uuid(),
  traitement_id uuid not null references traitements(id) on delete cascade,
  date          date not null default current_date,
  par           text,
  created_at    timestamptz not null default now(),
  unique (traitement_id, date)         -- anti double-clic, l'équivalent de la condition AppSheet
);

create or replace function set_updated_at() returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end $$;

drop trigger if exists traitements_updated_at on traitements;
create trigger traitements_updated_at before update on traitements
  for each row execute function set_updated_at();

-- ---------------------------------------------------------------------
-- 3. CALCUL DE L'ÉLIGIBILITÉ
--    Les formules sont centralisées ici : l'app ne recalcule jamais.
--    Peut courir = fin de traitement + délai + élimination + 1 (art. 85).
--    Quand un cheval a plusieurs lignes, vet_list retient la plus longue.
-- ---------------------------------------------------------------------

drop view if exists v_traitements cascade;
create view v_traitements as
select
  t.id,
  t.cheval_id,
  c.nom               as cheval,
  c.location,
  t.date,
  t.type,
  t.medicament_id,
  m.nom               as medicament,
  m.evenement_compatible,
  t.nombre_prises,
  t.intervalle_j,
  t.posologie,
  t.ordonnance_numero,
  t.ordonnance_url,
  t.fin_traitement_reelle,
  t.notes,
  t.cree_par,
  t.created_at,

  -- Durée (j) = (Nombre de prises − 1) × Intervalle (j) + 1
  ((t.nombre_prises - 1) * t.intervalle_j + 1)                      as duree_j,

  -- Fin de traitement = Date + Durée − 1, ou la fin réelle si arrêt anticipé
  coalesce(
    t.fin_traitement_reelle,
    t.date + ((t.nombre_prises - 1) * t.intervalle_j + 1) - 1
  )                                                                  as fin_traitement,

  coalesce(m.delai_j, 0)                                             as delai_j,
  coalesce(m.delai_elimination_j, 0)                                 as delai_elimination_j,
  coalesce(m.delai_j, 0) + coalesce(m.delai_elimination_j, 0)        as delai_total,

  -- Anomalie : un type qui attend un traitement et n'en a pas.
  (coalesce(ti.necessite_traitement, true) and t.medicament_id is null)
                                                                     as traitement_manquant,

  -- Peut courir à partir du = Fin de traitement + Délai + Délai élimination + Délai acte + 1
  -- Le +1 vient de l'article 85 (délai exclusif) : le cheval court à J+1.
  coalesce(
    t.fin_traitement_reelle,
    t.date + ((t.nombre_prises - 1) * t.intervalle_j + 1) - 1
  )
    + coalesce(m.delai_j, 0)
    + coalesce(m.delai_elimination_j, 0)
    + 1                                                              as peut_courir_le,

  -- Fin calendrier : borne exclusive, pour l'affichage en calendrier
  coalesce(
    t.fin_traitement_reelle,
    t.date + ((t.nombre_prises - 1) * t.intervalle_j + 1) - 1
  ) + 1                                                              as fin_calendrier,

  -- Traitement en cours aujourd'hui ?
  (current_date between t.date and coalesce(
      t.fin_traitement_reelle,
      t.date + ((t.nombre_prises - 1) * t.intervalle_j + 1) - 1))    as en_cours,

  -- Une prise est-elle due aujourd'hui, compte tenu de l'intervalle ?
  (current_date between t.date and coalesce(
      t.fin_traitement_reelle,
      t.date + ((t.nombre_prises - 1) * t.intervalle_j + 1) - 1)
   and mod((current_date - t.date), t.intervalle_j) = 0)             as prise_due_aujourdhui,

  exists (select 1 from administrations a
          where a.traitement_id = t.id and a.date = current_date)    as administre_aujourdhui

from traitements t
join chevaux c            on c.id = t.cheval_id
left join medicaments m        on m.id = t.medicament_id
left join types_intervention ti on ti.type = t.type;

comment on view v_traitements is
  'Traitements enrichis des colonnes calculées. Source unique de vérité pour les délais.';

-- Vet List : une ligne par cheval, à une date de référence donnée.
-- La date permet le simulateur d'engagement (« et si la course est le 12/10 ? »).
create or replace function vet_list(date_reference date default current_date)
returns table (
  cheval_id           uuid,
  cheval              text,
  location            text,
  peut_courir         boolean,
  libre_le            date,
  jours_restants      integer,
  traitement_bloquant uuid,
  motif               text,
  type_bloquant       type_evenement
)
language sql stable as $$
  select
    c.id,
    c.nom,
    c.location,
    coalesce(max(v.peut_courir_le), date_reference) <= date_reference   as peut_courir,
    max(v.peut_courir_le)                                              as libre_le,
    greatest(max(v.peut_courir_le) - date_reference, 0)::integer        as jours_restants,
    (array_agg(v.id order by v.peut_courir_le desc))[1]                 as traitement_bloquant,
    (array_agg(coalesce(v.medicament, v.type::text) order by v.peut_courir_le desc))[1] as motif,
    (array_agg(v.type order by v.peut_courir_le desc))[1]               as type_bloquant
  from chevaux c
  left join v_traitements v
    on v.cheval_id = c.id
   and v.peut_courir_le > date_reference     -- ne garde que ce qui bloque encore
  where c.actif
  group by c.id, c.nom, c.location
  order by c.nom;
$$;

comment on function vet_list is
  'Liste des chevaux avec leur éligibilité à une date donnée. peut_courir=false => encore sous délai.';

-- ---------------------------------------------------------------------
-- 4. SÉCURITÉ (RLS)
--    Tout le monde lit ; seuls saisie/admin écrivent.
-- ---------------------------------------------------------------------

create or replace function mon_role() returns role_app
language sql stable security definer set search_path = public as $$
  select coalesce(
    (select r.role from responsables r
      where lower(r.email) = lower(auth.jwt() ->> 'email') and r.actif),
    'consultation'::role_app
  );
$$;

create or replace function est_connu() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from responsables r
     where lower(r.email) = lower(auth.jwt() ->> 'email') and r.actif
  );
$$;

alter table chevaux        enable row level security;
alter table medicaments    enable row level security;
alter table traitements    enable row level security;
alter table administrations enable row level security;
alter table responsables   enable row level security;
alter table types_intervention enable row level security;

-- Lecture : tout utilisateur inscrit dans responsables
do $$
declare t text;
begin
  foreach t in array array['chevaux','medicaments','traitements','administrations','types_intervention'] loop
    execute format('drop policy if exists lecture on %I', t);
    execute format('create policy lecture on %I for select to authenticated using (est_connu())', t);
  end loop;
end $$;

-- Écriture des traitements et administrations : rôles saisie et admin
do $$
declare t text;
begin
  foreach t in array array['traitements','administrations'] loop
    execute format('drop policy if exists ecriture on %I', t);
    execute format($f$create policy ecriture on %I for all to authenticated
      using (mon_role() in ('saisie','admin')) with check (mon_role() in ('saisie','admin'))$f$, t);
  end loop;
end $$;

-- Référentiels (chevaux, médicaments, délais) : admin uniquement
do $$
declare t text;
begin
  foreach t in array array['chevaux','medicaments','types_intervention'] loop
    execute format('drop policy if exists admin_ecriture on %I', t);
    execute format($f$create policy admin_ecriture on %I for all to authenticated
      using (mon_role() = 'admin') with check (mon_role() = 'admin')$f$, t);
  end loop;
end $$;

-- Annuaire : chacun se voit, l'admin voit et gère tout le monde
drop policy if exists responsables_lecture on responsables;
create policy responsables_lecture on responsables for select to authenticated
  using (lower(email) = lower(auth.jwt() ->> 'email') or mon_role() = 'admin');

drop policy if exists responsables_admin on responsables;
create policy responsables_admin on responsables for all to authenticated
  using (mon_role() = 'admin') with check (mon_role() = 'admin');

-- ---------------------------------------------------------------------
-- 5. STOCKAGE DES ORDONNANCES
-- ---------------------------------------------------------------------

insert into storage.buckets (id, name, public)
values ('ordonnances', 'ordonnances', false)
on conflict (id) do nothing;

drop policy if exists ordonnances_lecture on storage.objects;
create policy ordonnances_lecture on storage.objects for select to authenticated
  using (bucket_id = 'ordonnances' and est_connu());

drop policy if exists ordonnances_depot on storage.objects;
create policy ordonnances_depot on storage.objects for insert to authenticated
  with check (bucket_id = 'ordonnances' and mon_role() in ('saisie','admin'));
