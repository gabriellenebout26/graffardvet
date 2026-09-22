-- =====================================================================
-- CORRECTIF (optionnel) — crée les chevaux cités dans les traitements
-- mais absents de l'onglet Chevaux.
--
-- À n'exécuter que si le diagnostic (05b) montre qu'il s'agit de chevaux
-- partis de l'écurie dont tu veux conserver l'historique.
--
-- Ils sont créés avec actif = false : leur historique est préservé et
-- consultable, mais ils n'apparaissent ni dans la Vet List ni dans le
-- menu déroulant de saisie. Tu peux en réactiver un à tout moment depuis
-- le Table Editor (colonne actif -> true).
--
-- À lancer APRÈS 04 et AVANT 06. Relançable sans effet de bord.
-- =====================================================================

-- La colonne actif n'existe pas dans prep_chevaux à la sortie de 04 :
-- on l'ajoute, en marquant actif tous les chevaux venus de l'onglet.
alter table prep_chevaux add column if not exists actif boolean not null default true;

-- Les chevaux manquants, créés inactifs
insert into prep_chevaux (nom, sexe, annee_naissance, proprietaire, location, actif)
select distinct p.cheval, null::text, null::smallint, null::text, null::text, false
  from prep_traitements p
 where p.date is not null
   and coalesce(p.cheval, '') <> ''
   and not exists (select 1 from prep_chevaux c where c.nom = p.cheval);

-- Récapitulatif : voilà ce qui sera créé en inactif
select nom as cheval_ajoute_inactif
  from prep_chevaux
 where actif = false
 order by nom;

select
  count(*) filter (where actif)        as chevaux_actifs,
  count(*) filter (where not actif)    as chevaux_inactifs_ajoutes,
  count(*)                             as total
from prep_chevaux;
