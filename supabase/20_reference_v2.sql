-- =====================================================================
-- DONNÉES DE RÉFÉRENCE — REMISE À PLAT
-- Écurie Graffard, 22 septembre 2026
--
-- Ce script remplace et annule les scripts 07, 12, 13 et 14, qui se
-- corrigeaient les uns les autres. Il définit les deux tables de
-- référence d'un seul tenant. Ne relance pas les précédents.
--
--
-- LE MODÈLE, EN TROIS PHRASES
--
--   1. Une ligne de traitement, c'est un TYPE D'INTERVENTION appliqué à
--      un cheval à une date. Le type est toujours renseigné et ne porte
--      aucun délai : c'est une classification.
--
--   2. La plupart des interventions citent une entrée du CATALOGUE —
--      un produit, une intervention thérapeutique ou un vaccin. C'est
--      cette entrée, et elle seule, qui porte le délai.
--
--   3. Un cheval peut courir à partir de la plus lointaine des dates
--      calculées sur ses lignes en cours.
--
--
-- CE QUI DÉCOULE DU MODÈLE
--
--   · Aucun délai n'est rangé ailleurs que dans le catalogue.
--   · Les 15 jours d'une vulvoplastie viennent de la Lurocaïne, pas de
--     l'acte. Les 30 jours d'une infiltration viennent du Dos/Méso.
--   · Un scope, une radio, un bilan sanguin ne citent aucune entrée :
--     aucun délai, et c'est correct.
--   · Le calcul tient en une ligne :
--       peut courir = fin de traitement + délai + élimination + 1
-- =====================================================================


-- ---------------------------------------------------------------------
-- 1. TYPES D'INTERVENTION
--    Classification. Ne porte aucun délai.
-- ---------------------------------------------------------------------

create table if not exists types_intervention (
  nom             text primary key,
  avec_catalogue  boolean not null,
  commentaire     text,
  ordre           smallint not null default 100
);

comment on table types_intervention is
  'Ce qui peut arriver à un cheval. avec_catalogue : cette intervention cite-t-elle une entrée du catalogue ? Aucun délai ici.';

delete from types_intervention;
insert into types_intervention (nom, avec_catalogue, commentaire, ordre) values
  ('Administration médicament', true,  'Le produit prescrit porte le délai',            10),
  ('Infiltration',              true,  'Dos/Méso, Horstem, IRAP',                       20),
  ('Vulvoplastie',              true,  'Lurocaïne, Sedomidine, Butorgésic',             30),
  ('Ondes de choc',             true,  'Entrée « Ondes de choc » du catalogue',         40),
  ('Vaccin',                    true,  'Grippe, Rhino',                                 50),
  ('Vermifuge',                 true,  'Adequan',                                       60),
  ('Scope',                     false, 'Examen — aucun produit, aucun délai',           70),
  ('Scope Embarqué',            false, 'Examen — aucun produit, aucun délai',           80),
  ('Radio/Imagerie',            false, 'Examen — aucun produit, aucun délai',           90),
  ('Bilan sanguin',             false, 'Examen — aucun produit, aucun délai',          100);


-- ---------------------------------------------------------------------
-- 2. CATALOGUE
--    Tout ce qui porte un délai : médicaments, interventions
--    thérapeutiques et vaccins, dans une seule liste.
-- ---------------------------------------------------------------------

create table if not exists catalogue (
  id                  uuid primary key default gen_random_uuid(),
  nom                 text unique not null,
  type_intervention   text not null references types_intervention(nom),
  delai_j             integer not null default 0 check (delai_j >= 0),
  delai_elimination_j integer not null default 0 check (delai_elimination_j >= 0),
  molecule            text,
  commentaire         text,
  actif               boolean not null default true,
  created_at          timestamptz not null default now()
);

comment on table catalogue is
  'La seule source de délai du système. Une entrée = un produit, une intervention thérapeutique ou un vaccin.';
comment on column catalogue.delai_elimination_j is
  'Jours ajoutés pour la déclaration de partant probable (~3 j avant la course).';

create index if not exists catalogue_type_nom_idx on catalogue (type_intervention, nom);

insert into catalogue (nom, type_intervention, delai_j, delai_elimination_j, molecule) values
  -- Médicaments
  ('Antalzen',        'Administration médicament', 12, 3, null),
  ('Avemix',          'Administration médicament', 15, 3, null),
  ('Azote',           'Administration médicament', 15, 3, null),
  ('Baytril',         'Administration médicament',  4, 3, null),
  ('Borgal',          'Administration médicament',  3, 0, 'sulfadoxine/triméthoprime'),
  ('Butorgésic',      'Administration médicament',  8, 3, 'butorphanol'),
  ('Calmagine',       'Administration médicament',  5, 3, null),
  ('Calmivet',        'Administration médicament', 12, 3, null),
  ('Carbesia',        'Administration médicament',  8, 3, null),
  ('Chorulon',        'Administration médicament',  7, 3, null),
  ('Cloxagel',        'Administration médicament',  3, 0, null),
  ('Depociline',      'Administration médicament', 30, 0, null),
  ('Dermogine',       'Administration médicament',  3, 0, null),
  ('Dimazon',         'Administration médicament',  4, 3, null),
  ('Diurizone',       'Administration médicament', 12, 3, null),
  ('Equibactin',      'Administration médicament',  3, 0, null),
  ('G4',              'Administration médicament',  3, 0, null),
  ('Gastrogard',      'Administration médicament',  5, 3, 'oméprazole'),
  ('Glucocorticoïde', 'Administration médicament', 30, 0, null),
  ('Histabiosone',    'Administration médicament', 21, 3, null),
  ('Iodure',          'Administration médicament',  3, 0, null),
  ('Lasilix',         'Administration médicament',  4, 3, null),
  ('Lurocaïne',       'Administration médicament', 15, 3, null),
  ('Marbocyl',        'Administration médicament',  4, 3, null),
  ('Metacam',         'Administration médicament',  5, 3, null),
  ('Oxytetracycline', 'Administration médicament',  4, 3, null),
  ('Rapidexon',       'Administration médicament',  7, 3, null),
  ('Recocam',         'Administration médicament', 30, 0, null),
  ('Rehydex',         'Administration médicament',  3, 0, null),
  ('Relaquine',       'Administration médicament', 12, 3, null),
  ('Ringer lactate',  'Administration médicament',  3, 0, null),
  ('Ronaxan',         'Administration médicament',  4, 3, null),
  ('Sedomidine',      'Administration médicament',  4, 3, null),
  ('Ventipulmin',     'Administration médicament', 30, 0, null),
  -- Interventions thérapeutiques
  ('Dos/Méso',        'Infiltration',              30, 0, null),
  ('Horstem',         'Infiltration',              14, 0, null),
  ('IRAP',            'Infiltration',              14, 0, null),
  ('Ondes de choc',   'Ondes de choc',              5, 0, null),
  -- Vermifuge
  ('Adequan',         'Vermifuge',                  3, 0, null),
  -- Vaccins
  ('Grippe',          'Vaccin',                     4, 0, null),
  ('Rhino',           'Vaccin',                     4, 0, null)
on conflict (nom) do update set
  type_intervention   = excluded.type_intervention,
  delai_j             = excluded.delai_j,
  delai_elimination_j = excluded.delai_elimination_j,
  molecule            = coalesce(excluded.molecule, catalogue.molecule);


-- ---------------------------------------------------------------------
-- 3. RACCORDER LES TRAITEMENTS EXISTANTS
--    L'ancienne colonne medicament_id pointait vers la table medicaments.
--    On la remplace par catalogue_id, en faisant correspondre les noms.
-- ---------------------------------------------------------------------

alter table traitements add column if not exists catalogue_id uuid references catalogue(id);

do $$
begin
  if exists (select 1 from information_schema.columns
              where table_name = 'traitements' and column_name = 'medicament_id')
     and to_regclass('public.medicaments') is not null then
    execute $x$
      update traitements t
         set catalogue_id = c.id
        from medicaments m
        join catalogue c on lower(trim(c.nom)) = lower(trim(m.nom))
       where t.medicament_id = m.id
         and t.catalogue_id is null
    $x$;
  end if;
end $$;

-- Les interventions qui portent le nom d'une entrée du catalogue
-- (ondes de choc saisis sans produit) se raccordent d'elles-mêmes.
update traitements t
   set catalogue_id = c.id
  from catalogue c
 where t.catalogue_id is null
   and lower(trim(c.nom)) = lower(trim(t.type::text));


-- ---------------------------------------------------------------------
-- 4. LE CALCUL
-- ---------------------------------------------------------------------

drop view if exists v_comparaison;
drop view if exists v_traitements;

create view v_traitements as
select
  t.id,
  t.cheval_id,
  ch.nom              as cheval,
  ch.location,
  t.date,
  t.type::text        as type_intervention,
  t.catalogue_id,
  c.nom               as entree_catalogue,
  c.molecule,
  t.nombre_prises,
  t.intervalle_j,
  t.posologie,
  t.ordonnance_numero,
  t.ordonnance_url,
  t.fin_traitement_reelle,
  t.notes,
  t.cree_par,
  t.created_at,

  -- Durée = (prises − 1) × intervalle + 1
  ((t.nombre_prises - 1) * t.intervalle_j + 1)                      as duree_j,

  -- Fin de traitement, ou la fin réelle en cas d'arrêt anticipé
  coalesce(
    t.fin_traitement_reelle,
    t.date + ((t.nombre_prises - 1) * t.intervalle_j + 1) - 1
  )                                                                  as fin_traitement,

  coalesce(c.delai_j, 0)                                             as delai_j,
  coalesce(c.delai_elimination_j, 0)                                 as delai_elimination_j,
  coalesce(c.delai_j, 0) + coalesce(c.delai_elimination_j, 0)        as delai_total,

  -- peut courir = fin + délai + élimination + 1 (art. 85, délai exclusif)
  coalesce(
    t.fin_traitement_reelle,
    t.date + ((t.nombre_prises - 1) * t.intervalle_j + 1) - 1
  )
    + coalesce(c.delai_j, 0)
    + coalesce(c.delai_elimination_j, 0)
    + 1                                                              as peut_courir_le,

  -- Saisie incomplète : un type qui cite normalement le catalogue,
  -- mais dont la ligne ne cite rien.
  (ti.avec_catalogue and t.catalogue_id is null)                     as entree_manquante,

  coalesce(
    t.fin_traitement_reelle,
    t.date + ((t.nombre_prises - 1) * t.intervalle_j + 1) - 1
  ) + 1                                                              as fin_calendrier,

  (current_date between t.date and coalesce(
      t.fin_traitement_reelle,
      t.date + ((t.nombre_prises - 1) * t.intervalle_j + 1) - 1))    as en_cours,

  (current_date between t.date and coalesce(
      t.fin_traitement_reelle,
      t.date + ((t.nombre_prises - 1) * t.intervalle_j + 1) - 1)
   and mod((current_date - t.date), t.intervalle_j) = 0)             as prise_due_aujourdhui,

  exists (select 1 from administrations a
          where a.traitement_id = t.id and a.date = current_date)    as administre_aujourdhui

from traitements t
join chevaux ch                 on ch.id = t.cheval_id
left join catalogue c           on c.id = t.catalogue_id
left join types_intervention ti on ti.nom = t.type::text;


-- La Vet List : pour chaque cheval, la plus lointaine de ses dates.
-- La colonne type_bloquant change de type (enum -> text), donc PostgreSQL
-- refuse un simple « create or replace » : il faut supprimer d'abord.
drop function if exists vet_list(date);

create function vet_list(date_reference date default current_date)
returns table (
  cheval_id           uuid,
  cheval              text,
  location            text,
  peut_courir         boolean,
  libre_le            date,
  jours_restants      integer,
  traitement_bloquant uuid,
  motif               text,
  type_bloquant       text
)
language sql stable as $$
  select
    ch.id,
    ch.nom,
    ch.location,
    max(v.peut_courir_le) is null                                      as peut_courir,
    max(v.peut_courir_le)                                              as libre_le,
    greatest(coalesce(max(v.peut_courir_le) - date_reference, 0), 0)::integer,
    (array_agg(v.id order by v.peut_courir_le desc))[1],
    (array_agg(coalesce(v.entree_catalogue, v.type_intervention)
               order by v.peut_courir_le desc))[1],
    (array_agg(v.type_intervention order by v.peut_courir_le desc))[1]
  from chevaux ch
  left join v_traitements v
    on v.cheval_id = ch.id
   and v.peut_courir_le > date_reference
  where ch.actif
  group by ch.id, ch.nom, ch.location
  order by ch.nom;
$$;


-- ---------------------------------------------------------------------
-- 5. SÉCURITÉ
-- ---------------------------------------------------------------------

alter table catalogue          enable row level security;
alter table types_intervention enable row level security;

do $$
declare t text;
begin
  foreach t in array array['catalogue','types_intervention'] loop
    execute format('drop policy if exists lecture on %I', t);
    execute format('create policy lecture on %I for select to authenticated using (est_connu())', t);
    execute format('drop policy if exists admin_ecriture on %I', t);
    execute format($f$create policy admin_ecriture on %I for all to authenticated
      using (mon_role() = 'admin') with check (mon_role() = 'admin')$f$, t);
  end loop;
end $$;


-- =====================================================================
-- CONTRÔLES
-- =====================================================================

-- A. Le catalogue, par type d'intervention
select type_intervention, count(*) as entrees,
       min(delai_j) as delai_min, max(delai_j + delai_elimination_j) as delai_max
  from catalogue
 group by type_intervention
 order by count(*) desc;

-- B. Saisies incomplètes : à compléter
select v.type_intervention, count(*) as lignes, min(v.date) as depuis, max(v.date) as jusqu_a
  from v_traitements v
 where v.entree_manquante
 group by v.type_intervention
 order by count(*) desc;

select v.cheval, v.date, v.type_intervention, v.ordonnance_numero
  from v_traitements v
 where v.entree_manquante
 order by v.date desc;

-- C. Examens sans entrée de catalogue : normal, aucun délai
select v.type_intervention, count(*) as lignes, 'Normal — examen sans délai' as statut
  from v_traitements v
  join types_intervention ti on ti.nom = v.type_intervention
 where not ti.avec_catalogue
 group by v.type_intervention
 order by count(*) desc;

-- D. La Vet List
select cheval, libre_le, jours_restants, motif
  from vet_list(current_date)
 where not peut_courir
 order by libre_le desc;
