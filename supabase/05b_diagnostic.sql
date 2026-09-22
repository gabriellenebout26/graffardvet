-- =====================================================================
-- DIAGNOSTIC — à lancer entre 05 et 06. N'écrit rien.
-- Répond à deux questions : les lignes sans date sont-elles des lignes
-- vides, et les chevaux inconnus sont-ils des partants ou des oublis ?
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. Les lignes « date illisible » sont-elles simplement vides ?
-- ---------------------------------------------------------------------
select
  ligne,
  case
    when coalesce(cheval, '') = '' and coalesce(medicament, '') = ''
     and coalesce(posologie, '') = '' and coalesce(ordonnance_numero, '') = ''
    then 'Ligne vide — sans conséquence, ignore-la'
    else 'Ligne avec du contenu — la date est à corriger dans le Sheet'
  end as verdict,
  cheval, medicament, posologie, ordonnance_numero
from prep_traitements
where date is null
order by ligne;

-- ---------------------------------------------------------------------
-- 2. Les chevaux absents de l'onglet Chevaux
--
--    Regarde la colonne « dernier_traitement » :
--    - une date ancienne  -> cheval parti de l'écurie, son historique seul
--                            est concerné
--    - une date récente   -> ATTENTION : cheval probablement encore chez
--                            vous et absent de ton onglet Chevaux. Il n'est
--                            donc suivi nulle part aujourd'hui.
-- ---------------------------------------------------------------------
select
  p.cheval,
  count(*)                                      as nb_traitements,
  min(p.date)                                   as premier_traitement,
  max(p.date)                                   as dernier_traitement,
  (current_date - max(p.date))                  as jours_depuis,
  case
    when max(p.date) > current_date - interval '120 days'
    then '⚠️  Traitement récent — vérifie s''il est encore à l''écurie'
    else 'Ancien — probablement parti'
  end                                           as a_verifier
from prep_traitements p
where p.date is not null
  and not exists (select 1 from prep_chevaux c where c.nom = p.cheval)
group by p.cheval
order by max(p.date) desc;

-- ---------------------------------------------------------------------
-- 3. Combien de traitements sont concernés au total ?
-- ---------------------------------------------------------------------
select
  (select count(*) from prep_traitements where date is null)           as lignes_sans_date,
  (select count(distinct p.cheval) from prep_traitements p
     where p.date is not null
       and not exists (select 1 from prep_chevaux c where c.nom = p.cheval)) as chevaux_inconnus,
  (select count(*) from prep_traitements p
     where p.date is not null
       and not exists (select 1 from prep_chevaux c where c.nom = p.cheval)) as traitements_concernes;
