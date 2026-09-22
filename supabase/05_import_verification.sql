-- =====================================================================
-- IMPORT SANS TERMINAL — ÉTAPE 2 sur 3 : vérification
--
-- N'ÉCRIT RIEN. C'est l'équivalent de l'essai à blanc : ce script te dit
-- ce qui poserait problème, pour que tu corriges ton Sheet AVANT d'importer.
--
-- Lis les deux tableaux de résultats de haut en bas.
-- =====================================================================

-- ---------------------------------------------------------------------
-- TABLEAU 1 — Résumé
-- ---------------------------------------------------------------------
select
  'Chevaux à créer'                                                as element,
  (select count(*) from prep_chevaux)::text                        as nombre
union all select 'Médicaments à créer',
  (select count(*) from prep_medicaments)::text
union all select 'Traitements lus dans le CSV',
  (select count(*) from prep_traitements)::text
union all select '→ dont importables',
  (select count(*) from prep_traitements p
    where p.date is not null
      and exists (select 1 from prep_chevaux c where c.nom = p.cheval)
      and (p.type <> 'Administration médicament'
           or exists (select 1 from prep_medicaments m
                       where import_norm(m.nom) = import_norm(p.medicament))))::text
union all select '→ dont ignorés (voir tableau 2)',
  (select count(*) from prep_traitements p
    where p.date is null
       or not exists (select 1 from prep_chevaux c where c.nom = p.cheval)
       or (p.type = 'Administration médicament'
           and not exists (select 1 from prep_medicaments m
                            where import_norm(m.nom) = import_norm(p.medicament))))::text;

-- ---------------------------------------------------------------------
-- TABLEAU 2 — Alertes, les plus graves d'abord
--
--   BLOQUANT  le traitement ne sera pas importé, corrige le Sheet
--   À VÉRIFIER l'import se fera, mais le résultat est peut-être faux
-- ---------------------------------------------------------------------
with alertes as (

  -- Dates illisibles
  select 1 as rang, 'BLOQUANT' as gravite, p.ligne,
    'Date illisible « ' || coalesce(p.cheval, '?') || ' » — vérifie le format de la colonne date' as probleme
  from prep_traitements p where p.date is null

  union all
  -- Chevaux absents du référentiel
  select 2, 'BLOQUANT', p.ligne,
    'Cheval inconnu : « ' || p.cheval || ' » — absent de l''onglet Chevaux'
  from prep_traitements p
  where p.date is not null
    and not exists (select 1 from prep_chevaux c where c.nom = p.cheval)

  union all
  -- Médicament introuvable sur une administration
  select 3, 'BLOQUANT', p.ligne,
    'Médicament « ' || coalesce(p.medicament, '(vide)') || ' » absent du référentiel — ' || p.cheval
  from prep_traitements p
  where p.date is not null
    and p.type = 'Administration médicament'
    and not exists (select 1 from prep_medicaments m
                     where import_norm(m.nom) = import_norm(p.medicament))

  union all
  -- Délai à zéro : le cheval serait déclaré courable immédiatement
  select 4, 'À VÉRIFIER', null::bigint,
    'Médicament « ' || m.nom ||
    ' » : délai à 0 j. À confirmer avec Chris — sinon le cheval sera annoncé disponible à tort.'
  from prep_medicaments m where m.delai_j = 0

  union all
  -- Type d'événement non reconnu, remplacé par défaut
  select 5, 'À VÉRIFIER', p.ligne,
    'Type « ' || p.type_brut || ' » non reconnu, traité comme Administration médicament — ' || p.cheval
  from prep_traitements p
  where p.type_brut is not null
    and not exists (select 1 from delais_acte d
                     where import_norm(d.type::text) = import_norm(p.type_brut))

  union all
  -- Traitement dans le futur
  select 6, 'À VÉRIFIER', p.ligne,
    'Date dans le futur (' || p.date || ') — ' || p.cheval
  from prep_traitements p where p.date > current_date

  union all
  -- Fin réelle antérieure au début
  select 7, 'À VÉRIFIER', p.ligne,
    'Date d''arrêt antérieure au début du traitement — ' || p.cheval
  from prep_traitements p
  where p.fin_traitement_reelle is not null and p.fin_traitement_reelle < p.date

  union all
  -- Doublons de chevaux après normalisation du nom
  select 8, 'À VÉRIFIER', null::bigint,
    'Nom de cheval en double dans l''onglet Chevaux : « ' || nom || ' » — une seule fiche sera créée'
  from (select nom from prep_chevaux group by nom having count(*) > 1) d
)
select gravite, ligne as ligne_csv, probleme
  from alertes
 order by rang, ligne nulls first;

-- ---------------------------------------------------------------------
-- Si le tableau 2 est vide, ou ne contient que des « À VÉRIFIER » que tu
-- assumes : passe à 06_import_execution.sql.
-- Sinon : corrige le Sheet, réimporte les CSV, relance 04 puis 05.
-- ---------------------------------------------------------------------
