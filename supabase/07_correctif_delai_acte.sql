-- =====================================================================
-- CORRECTIF — double comptage du délai
--
-- Problème : quand une ligne portait à la fois un produit du référentiel
-- (ex. « Dos/Méso », 30 j) et un type d'événement ayant lui-même un délai
-- d'acte (ex. Infiltration, 30 j), les deux s'additionnaient.
--
-- Règle corrigée, alignée sur la formule AppSheet : le délai d'acte ne
-- s'applique QUE s'il n'y a pas de produit renseigné. Dès qu'un produit
-- est choisi, c'est lui qui fait foi, et lui seul.
--
-- Ne touche à aucune donnée : remplace seulement le calcul.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. AVANT — garde une trace de l'état actuel pour pouvoir comparer
-- ---------------------------------------------------------------------
drop table if exists _avant_correctif;
create table _avant_correctif as
select cheval_id, cheval, id as traitement_id, peut_courir_le
  from v_traitements;

-- ---------------------------------------------------------------------
-- 2. La vue corrigée
-- ---------------------------------------------------------------------
create or replace view v_traitements as
select
  t.id,
  t.cheval_id,
  c.nom               as cheval,
  c.location,
  t.date,
  t.type,
  t.medicament_id,
  m.nom               as medicament,
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

  -- CORRECTIF : le délai d'acte ne s'applique qu'en l'absence de produit.
  case when t.medicament_id is null then coalesce(da.delai_j, 0) else 0 end
                                                                     as delai_acte_j,

  coalesce(
    t.fin_traitement_reelle,
    t.date + ((t.nombre_prises - 1) * t.intervalle_j + 1) - 1
  )
    + coalesce(m.delai_j, 0)
    + coalesce(m.delai_elimination_j, 0)
    + case when t.medicament_id is null then coalesce(da.delai_j, 0) else 0 end
    + 1                                                              as peut_courir_le,

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
join chevaux c            on c.id = t.cheval_id
left join medicaments m   on m.id = t.medicament_id
left join delais_acte da  on da.type = t.type;

-- ---------------------------------------------------------------------
-- 3. APRÈS — ce qui a changé
-- ---------------------------------------------------------------------
select
  a.cheval,
  a.peut_courir_le            as avant,
  v.peut_courir_le            as apres,
  (a.peut_courir_le - v.peut_courir_le) as jours_retires,
  v.type,
  v.medicament
from _avant_correctif a
join v_traitements v on v.id = a.traitement_id
where a.peut_courir_le <> v.peut_courir_le
order by (a.peut_courir_le - v.peut_courir_le) desc, a.cheval;

select count(*) as traitements_corriges
  from _avant_correctif a
  join v_traitements v on v.id = a.traitement_id
 where a.peut_courir_le <> v.peut_courir_le;

-- ---------------------------------------------------------------------
-- 4. La Vet List après correction
-- ---------------------------------------------------------------------
select cheval, libre_le, jours_restants, motif
  from vet_list(current_date)
 where not peut_courir
 order by libre_le desc;

-- Ménage une fois la comparaison faite :
--   drop table if exists _avant_correctif;
