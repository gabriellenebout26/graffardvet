-- =====================================================================
-- RÉFÉRENTIEL UNIQUE — le modèle définitif (Gabrielle, 22/09/2026)
--
-- Une seule liste : médicaments, interventions et vaccins ensemble.
-- Chaque entrée porte son délai, son délai d'élimination, et le type
-- d'événement auquel elle se rattache.
--
-- Une ligne de traitement pointe vers une entrée du référentiel.
-- Son délai vient de cette entrée, et d'elle seule.
-- Quand un cheval a plusieurs lignes en cours, la plus longue l'emporte
-- — c'est déjà ce que fait la Vet List.
--
-- La table delais_acte est supprimée : ses valeurs vivent désormais
-- dans le référentiel.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. Le référentiel gagne une colonne : le type d'événement
-- ---------------------------------------------------------------------
alter table medicaments
  add column if not exists evenement_compatible type_evenement;

comment on column medicaments.evenement_compatible is
  'Type d''événement auquel cette entrée se rattache. Filtre la liste déroulante à la saisie.';

-- ---------------------------------------------------------------------
-- 2. Le référentiel, tel que fourni
-- ---------------------------------------------------------------------
insert into medicaments (nom, delai_j, delai_elimination_j, evenement_compatible) values
  ('Antalzen',        12, 3, 'Administration médicament'),
  ('Avemix',          15, 3, 'Administration médicament'),
  ('Azote',           15, 3, 'Administration médicament'),
  ('Baytril',          4, 3, 'Administration médicament'),
  ('Borgal',           3, 0, 'Administration médicament'),
  ('Calmagine',        5, 3, 'Administration médicament'),
  ('Calmivet',        12, 3, 'Administration médicament'),
  ('Carbesia',         8, 3, 'Administration médicament'),
  ('Chorulon',         7, 3, 'Administration médicament'),
  ('Cloxagel',         3, 0, 'Administration médicament'),
  ('Depociline',      30, 0, 'Administration médicament'),
  ('Dermogine',        3, 0, 'Administration médicament'),
  ('Dimazon',          4, 3, 'Administration médicament'),
  ('Diurizone',       12, 3, 'Administration médicament'),
  ('Equibactin',       3, 0, 'Administration médicament'),
  ('G4',               3, 0, 'Administration médicament'),
  ('Gastrogard',       5, 3, 'Administration médicament'),
  ('Glucocorticoïde', 30, 0, 'Administration médicament'),
  ('Histabiosone',    21, 3, 'Administration médicament'),
  ('Iodure',           3, 0, 'Administration médicament'),
  ('Lasilix',          4, 3, 'Administration médicament'),
  ('Lurocaïne',       15, 3, 'Administration médicament'),
  ('Marbocyl',         4, 3, 'Administration médicament'),
  ('Metacam',          5, 3, 'Administration médicament'),
  ('Oxytetracycline',  4, 3, 'Administration médicament'),
  ('Rapidexon',        7, 3, 'Administration médicament'),
  ('Recocam',         30, 0, 'Administration médicament'),
  ('Rehydex',          3, 0, 'Administration médicament'),
  ('Relaquine',       12, 3, 'Administration médicament'),
  ('Ringer lactate',   3, 0, 'Administration médicament'),
  ('Ronaxan',          4, 3, 'Administration médicament'),
  ('Sedomidine',       4, 3, 'Administration médicament'),
  ('Ventipulmin',     30, 0, 'Administration médicament'),
  ('Dos/Méso',        30, 0, 'Infiltration'),
  ('Horstem',         14, 0, 'Infiltration'),
  ('IRAP',            14, 0, 'Infiltration'),
  ('Adequan',          3, 0, 'Vermifuge'),
  ('Grippe',           4, 0, 'Vaccin'),
  ('Rhino',            4, 0, 'Vaccin'),
  ('Ondes de choc',    5, 0, 'Ondes de choc')
on conflict (nom) do update set
  delai_j              = excluded.delai_j,
  delai_elimination_j  = excluded.delai_elimination_j,
  evenement_compatible = excluded.evenement_compatible;

-- ---------------------------------------------------------------------
-- 3. Rattacher les traitements orphelins
--    Les actes importés sans produit (ondes de choc notamment) pointaient
--    dans le vide. On les relie à l'entrée du référentiel qui porte le
--    même nom que leur type.
-- ---------------------------------------------------------------------
update traitements t
   set medicament_id = m.id
  from medicaments m
 where t.medicament_id is null
   and m.nom = t.type::text;

-- ---------------------------------------------------------------------
-- 4. Le calcul, débarrassé de la seconde source
-- ---------------------------------------------------------------------
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

  -- Peut courir = fin de traitement + délai + élimination + 1 (article 85)
  coalesce(
    t.fin_traitement_reelle,
    t.date + ((t.nombre_prises - 1) * t.intervalle_j + 1) - 1
  )
    + coalesce(m.delai_j, 0)
    + coalesce(m.delai_elimination_j, 0)
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
left join medicaments m   on m.id = t.medicament_id;

-- ---------------------------------------------------------------------
-- 5. La table des délais par acte n'a plus de raison d'être
-- ---------------------------------------------------------------------
drop table if exists delais_acte;


-- =====================================================================
-- CONTRÔLES
-- =====================================================================

-- A. Traitements sans entrée de référentiel : délai 0, donc annoncés
--    disponibles immédiatement. À regarder de près.
select
  t.type,
  count(*)                    as traitements_sans_delai,
  min(t.date)                 as depuis,
  max(t.date)                 as jusqu_a
from traitements t
where t.medicament_id is null
group by t.type
order by count(*) desc;

-- B. Entrées présentes dans la base mais absentes de ta liste
select
  m.nom                       as entree_non_listee,
  m.delai_j,
  m.delai_elimination_j,
  count(t.id)                 as traitements_concernes
from medicaments m
left join traitements t on t.medicament_id = m.id
where m.evenement_compatible is null
group by m.nom, m.delai_j, m.delai_elimination_j
order by count(t.id) desc;

-- C. Le référentiel après mise à jour
select evenement_compatible, count(*) as entrees
  from medicaments
 group by evenement_compatible
 order by count(*) desc;

-- D. La Vet List
select cheval, libre_le, jours_restants, motif
  from vet_list(current_date)
 where not peut_courir
 order by libre_le desc;
