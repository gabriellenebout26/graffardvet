-- =====================================================================
-- TYPES D'INTERVENTION (Gabrielle, 22/09/2026)
--
-- Le type d'intervention est le socle d'une ligne de traitement : il est
-- toujours renseigné. La plupart des types sont associés à un traitement
-- du référentiel, qui porte le délai. Certains n'en ont pas — Scope,
-- Radio, Bilan sanguin — et n'entraînent aucun délai.
--
-- Ce script apprend à la base lesquels attendent un traitement, pour
-- qu'une vulvoplastie sans produit remonte comme une anomalie, et qu'un
-- scope sans produit n'en soit pas une.
-- =====================================================================

create table if not exists types_intervention (
  type                 type_evenement primary key,
  necessite_traitement boolean not null default true,
  commentaire          text
);

comment on table types_intervention is
  'Pour chaque type : attend-il une entrée du référentiel ? Ne porte aucun délai.';

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
on conflict (type) do update set
  necessite_traitement = excluded.necessite_traitement,
  commentaire          = excluded.commentaire;

-- ---------------------------------------------------------------------
-- La vue gagne un drapeau : cette ligne attend-elle un traitement
-- qu'elle n'a pas ?
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

  ((t.nombre_prises - 1) * t.intervalle_j + 1)                      as duree_j,

  coalesce(
    t.fin_traitement_reelle,
    t.date + ((t.nombre_prises - 1) * t.intervalle_j + 1) - 1
  )                                                                  as fin_traitement,

  coalesce(m.delai_j, 0)                                             as delai_j,
  coalesce(m.delai_elimination_j, 0)                                 as delai_elimination_j,
  coalesce(m.delai_j, 0) + coalesce(m.delai_elimination_j, 0)        as delai_total,

  -- Le délai vient du traitement associé. Un acte d'examen n'en a pas.
  coalesce(
    t.fin_traitement_reelle,
    t.date + ((t.nombre_prises - 1) * t.intervalle_j + 1) - 1
  )
    + coalesce(m.delai_j, 0)
    + coalesce(m.delai_elimination_j, 0)
    + 1                                                              as peut_courir_le,

  -- Anomalie : un type qui attend un traitement et n'en a pas.
  (coalesce(ti.necessite_traitement, true) and t.medicament_id is null)
                                                                     as traitement_manquant,

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
join chevaux c                 on c.id = t.cheval_id
left join medicaments m        on m.id = t.medicament_id
left join types_intervention ti on ti.type = t.type;

-- ---------------------------------------------------------------------
-- Sécurité : lecture pour tous, écriture pour l'admin
-- ---------------------------------------------------------------------
alter table types_intervention enable row level security;

drop policy if exists lecture on types_intervention;
create policy lecture on types_intervention for select to authenticated
  using (est_connu());

drop policy if exists admin_ecriture on types_intervention;
create policy admin_ecriture on types_intervention for all to authenticated
  using (mon_role() = 'admin') with check (mon_role() = 'admin');


-- =====================================================================
-- CONTRÔLES
-- =====================================================================

-- A. Les vraies anomalies : un type qui attend un traitement, sans traitement
select
  v.type,
  count(*)        as lignes_a_completer,
  min(v.date)     as depuis,
  max(v.date)     as jusqu_a
from v_traitements v
where v.traitement_manquant
group by v.type
order by count(*) desc;

-- Le détail, pour aller les corriger
select v.cheval, v.date, v.type, v.ordonnance_numero, v.notes
  from v_traitements v
 where v.traitement_manquant
 order by v.date desc, v.cheval;

-- B. Les actes d'examen sans traitement : normal, aucun délai.
--    Présenté pour information, pas comme un problème.
select
  v.type,
  count(*)        as lignes,
  'Normal — acte sans délai' as statut
from v_traitements v
join types_intervention ti on ti.type = v.type
where not ti.necessite_traitement and v.medicament_id is null
group by v.type
order by count(*) desc;

-- C. Répartition des types dans l'historique
select
  ti.type,
  ti.necessite_traitement,
  ti.commentaire,
  count(t.id)     as lignes_enregistrees
from types_intervention ti
left join traitements t on t.type = ti.type
group by ti.type, ti.necessite_traitement, ti.commentaire
order by count(t.id) desc;
