-- =====================================================================
-- IMPORT SANS TERMINAL — ÉTAPE 3 sur 3 : chargement
--
-- À exécuter seulement après avoir lu le rapport de 05_import_verification.sql.
-- Tout se fait dans une transaction : en cas d'erreur, rien n'est écrit.
-- Relançable sans créer de doublons de chevaux ni de médicaments.
-- =====================================================================

begin;

-- 1. Chevaux
--    La colonne actif n'existe que si 05c a été exécuté ; sinon tous actifs.
alter table prep_chevaux add column if not exists actif boolean not null default true;

insert into chevaux (nom, sexe, annee_naissance, proprietaire, location, actif)
select nom, sexe, annee_naissance, proprietaire, location, actif
  from prep_chevaux
on conflict (nom) do update set
  sexe            = coalesce(excluded.sexe, chevaux.sexe),
  annee_naissance = coalesce(excluded.annee_naissance, chevaux.annee_naissance),
  proprietaire    = coalesce(excluded.proprietaire, chevaux.proprietaire),
  location        = coalesce(excluded.location, chevaux.location);
  -- actif n'est volontairement pas écrasé : une réactivation faite à la
  -- main dans le Table Editor survit à un réimport.

-- 2. Médicaments
insert into medicaments (nom, delai_j, delai_elimination_j, expression_ordonnance, commentaire)
select nom, delai_j, delai_elimination_j, expression_ordonnance, commentaire
  from prep_medicaments
on conflict (nom) do update set
  delai_j               = excluded.delai_j,
  delai_elimination_j   = excluded.delai_elimination_j,
  expression_ordonnance = coalesce(excluded.expression_ordonnance, medicaments.expression_ordonnance),
  commentaire           = coalesce(excluded.commentaire, medicaments.commentaire);

-- 3. Traitements
--    Les lignes signalées BLOQUANT en étape 2 sont écartées ici.
--    Le garde-fou « not exists » évite les doublons si tu relances le script.
insert into traitements (
  cheval_id, date, type, medicament_id, nombre_prises, intervalle_j,
  posologie, ordonnance_numero, fin_traitement_reelle, notes, cree_par)
select
  c.id,
  p.date,
  p.type,
  m.id,
  p.nombre_prises,
  p.intervalle_j,
  p.posologie,
  p.ordonnance_numero,
  p.fin_traitement_reelle,
  p.notes,
  'import'
from prep_traitements p
join chevaux c on c.nom = p.cheval
left join medicaments m on import_norm(m.nom) = import_norm(p.medicament)
where p.date is not null
  and (p.type <> 'Administration médicament' or m.id is not null)
  and not exists (
    select 1 from traitements t
     where t.cheval_id = c.id
       and t.date = p.date
       and t.type = p.type
       and t.medicament_id is not distinct from m.id
       and t.nombre_prises = p.nombre_prises
  );

commit;

-- ---------------------------------------------------------------------
-- Contrôle du résultat
-- ---------------------------------------------------------------------
select 'chevaux' as table_, count(*) from chevaux
union all select 'medicaments', count(*) from medicaments
union all select 'traitements', count(*) from traitements;

-- Les chevaux actuellement sous délai, du plus long au plus court.
-- Compare ce tableau à ta Vet List AppSheet d'aujourd'hui : c'est le
-- test qui compte vraiment.
select cheval, libre_le, jours_restants, motif
  from vet_list(current_date)
 where not peut_courir
 order by libre_le desc;

-- ---------------------------------------------------------------------
-- Une fois le résultat validé, tu peux faire le ménage :
--
--   drop table if exists prep_chevaux, prep_medicaments, prep_traitements;
--   drop table if exists import_chevaux, import_medicaments, import_traitements;
--
-- Garde-les tant que tu n'as pas comparé avec AppSheet.
-- ---------------------------------------------------------------------
