-- =====================================================================
-- CORRECTIF — c'est le délai le PLUS LONG qui s'applique.
--
-- Règle correcte (Gabrielle, 22/09/2026) :
--   On compare deux délais et on retient le plus long.
--     · celui du produit        = délai + délai d'élimination
--     · celui du type d'acte    = ex. Infiltration 30 j, Vulvoplastie 15 j
--
-- Pourquoi ça compte : sur une vulvoplastie, les produits sont toujours
-- écrits. Si le produit ne fait que 8 jours et que l'acte en impose 15,
-- l'ancienne règle sortait 8 — le cheval était annoncé disponible une
-- semaine trop tôt.
--
-- Historique des règles sur ce point :
--   v1  produit + acte additionnés  -> double comptage (cas Dos/Méso)
--   v2  produit s'il existe, sinon acte -> trop permissif (cas Vulvoplastie)
--   v3  le plus long des deux       -> celle-ci
--
-- Ne touche à aucune donnée : remplace seulement le calcul.
-- =====================================================================

drop table if exists _avant_v3;
create table _avant_v3 as
select id as traitement_id, cheval, peut_courir_le from v_traitements;

-- La vue gagne des colonnes : il faut la supprimer avant de la recréer.
-- Les données ne sont pas concernées, une vue ne contient rien.
drop view if exists v_comparaison;
drop view if exists v_traitements;

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
  coalesce(da.delai_j, 0)                                            as delai_acte_j,

  -- Le délai du produit, élimination comprise
  coalesce(m.delai_j, 0) + coalesce(m.delai_elimination_j, 0)        as delai_produit_total,

  -- LA RÈGLE : le plus long des deux l'emporte
  greatest(
    coalesce(m.delai_j, 0) + coalesce(m.delai_elimination_j, 0),
    coalesce(da.delai_j, 0)
  )                                                                  as delai_retenu,

  -- D'où vient le délai retenu : utile pour comprendre une date
  case
    when coalesce(m.delai_j, 0) + coalesce(m.delai_elimination_j, 0)
         >= coalesce(da.delai_j, 0)
      then coalesce(m.nom, 'aucun produit')
    else 'acte : ' || t.type::text
  end                                                                as origine_delai,

  coalesce(
    t.fin_traitement_reelle,
    t.date + ((t.nombre_prises - 1) * t.intervalle_j + 1) - 1
  )
    + greatest(
        coalesce(m.delai_j, 0) + coalesce(m.delai_elimination_j, 0),
        coalesce(da.delai_j, 0)
      )
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
-- Ce qui change
-- ---------------------------------------------------------------------
select
  a.cheval,
  v.type,
  v.medicament,
  a.peut_courir_le            as avant,
  v.peut_courir_le            as apres,
  (v.peut_courir_le - a.peut_courir_le) as jours_ajoutes,
  v.delai_produit_total       as delai_produit,
  v.delai_acte_j              as delai_acte,
  v.origine_delai             as delai_retenu_de
from _avant_v3 a
join v_traitements v on v.id = a.traitement_id
where a.peut_courir_le <> v.peut_courir_le
order by (v.peut_courir_le - a.peut_courir_le) desc, a.cheval;

select count(*) as traitements_corriges
  from _avant_v3 a
  join v_traitements v on v.id = a.traitement_id
 where a.peut_courir_le <> v.peut_courir_le;

-- ---------------------------------------------------------------------
-- La Vet List après correction
-- ---------------------------------------------------------------------
select cheval, libre_le, jours_restants, motif
  from vet_list(current_date)
 where not peut_courir
 order by libre_le desc;

-- Ménage :  drop table if exists _avant_v3;
