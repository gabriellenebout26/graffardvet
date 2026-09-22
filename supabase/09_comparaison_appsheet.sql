-- =====================================================================
-- COMPARAISON AVEC APPSHEET — le test qui décide de la bascule.
-- N'écrit rien dans les tables définitives.
--
-- PRÉPARATION
-- 1. Dans AppSheet (ou dans le Sheet qui l'alimente), exporte ta Vet List
--    du jour en CSV : une ligne par cheval, avec au minimum le nom du
--    cheval et la date « peut courir à partir du ».
-- 2. Renomme le fichier import_vetlist.csv
-- 3. Supabase > Table Editor > New table > Import data from CSV
--    La table doit s'appeler import_vetlist.
-- 4. Exécute ce script.
--
-- Les colonnes sont retrouvées automatiquement, quels que soient leurs
-- intitulés (le script réutilise les fonctions posées par le script 04).
-- =====================================================================

create or replace procedure comparer_appsheet()
language plpgsql as $$
declare
  c_nom text; c_date text;
begin
  if to_regclass('public.import_vetlist') is null then
    raise exception 'Table import_vetlist introuvable. Importe d''abord ton export AppSheet sous ce nom exact.';
  end if;

  c_nom  := import_colonne('import_vetlist', array[
    'cheval','nom du cheval','nom','horse']);
  c_date := import_colonne('import_vetlist', array[
    'peut courir a partir du','peut courir','jour j','date','libre le',
    'peut courir jour j course','engageable']);

  if c_nom is null then
    raise exception 'Colonne du nom de cheval introuvable dans import_vetlist.';
  end if;
  if c_date is null then
    raise exception 'Colonne de la date « peut courir » introuvable dans import_vetlist.';
  end if;

  drop table if exists prep_vetlist;
  execute format($f$
    create table prep_vetlist as
    select import_nom_cheval(%1$I::text) as cheval,
           import_date(%2$I::text)       as peut_courir_le
      from import_vetlist
     where import_nom_cheval(%1$I::text) <> ''
  $f$, c_nom, c_date);

  raise notice 'Export AppSheet lu : % lignes.', (select count(*) from prep_vetlist);
end $$;

call comparer_appsheet();

-- ---------------------------------------------------------------------
-- Vue de travail commune aux trois tableaux
-- ---------------------------------------------------------------------
create or replace view v_comparaison as
with nouveau as (
  select cheval, libre_le, peut_courir from vet_list(current_date)
)
select
  coalesce(a.cheval, n.cheval)          as cheval,
  (a.cheval is not null)                as dans_appsheet,
  (n.cheval is not null)                as dans_base,
  a.peut_courir_le                      as appsheet,
  n.libre_le                            as nouvelle_app,
  case
    when n.cheval is null then 'ABSENT DE LA BASE'
    when a.cheval is null then 'ABSENT DE L''EXPORT APPSHEET'
    when a.peut_courir_le is null and n.libre_le is null then 'IDENTIQUE'
    -- libre chez nous, bloque chez AppSheet : le cas a risque
    when n.libre_le is null and a.peut_courir_le is not null then 'PLUS PERMISSIF'
    when a.peut_courir_le is null and n.libre_le is not null then 'PLUS RESTRICTIF'
    when n.libre_le < a.peut_courir_le then 'PLUS PERMISSIF'
    when n.libre_le > a.peut_courir_le then 'PLUS RESTRICTIF'
    else 'IDENTIQUE'
  end                                   as nature,
  (n.libre_le - a.peut_courir_le)       as ecart_jours
from prep_vetlist a
full outer join nouveau n on n.cheval = a.cheval;

-- ---------------------------------------------------------------------
-- TABLEAU 1 — Le verdict
-- ---------------------------------------------------------------------
select
  count(*)                                            as chevaux_compares,
  count(*) filter (where nature = 'IDENTIQUE')        as identiques,
  count(*) filter (where nature = 'PLUS PERMISSIF')   as plus_permissif_A_EXAMINER,
  count(*) filter (where nature = 'PLUS RESTRICTIF')  as plus_restrictif,
  count(*) filter (where nature like 'ABSENT%')       as absents
from v_comparaison;

-- ---------------------------------------------------------------------
-- TABLEAU 2 — Les ecarts, du plus grave au plus anodin
--
--   PLUS PERMISSIF   la nouvelle app libere le cheval AVANT AppSheet.
--                    A EXAMINER EN PRIORITE : risque reglementaire.
--   ABSENT ...       le cheval manque d'un cote ou de l'autre.
--   PLUS RESTRICTIF  la nouvelle app libere APRES AppSheet. Pas de
--                    risque de controle, mais une course manquee.
-- ---------------------------------------------------------------------
select nature, cheval, appsheet, nouvelle_app, ecart_jours
  from v_comparaison
 where nature <> 'IDENTIQUE'
 order by
   case nature
     when 'PLUS PERMISSIF'              then 1
     when 'ABSENT DE LA BASE'           then 2
     when 'ABSENT DE L''EXPORT APPSHEET' then 3
     else 4
   end,
   abs(coalesce(ecart_jours, 9999)) desc,
   cheval;

-- ---------------------------------------------------------------------
-- TABLEAU 3 — Le detail du calcul pour les chevaux en ecart
-- ---------------------------------------------------------------------
select v.cheval, v.date, v.type, v.medicament,
       v.nombre_prises, v.intervalle_j, v.duree_j, v.fin_traitement,
       v.delai_j, v.delai_elimination_j, v.delai_acte_j, v.peut_courir_le
  from v_traitements v
  join v_comparaison c on c.cheval = v.cheval
 where c.nature <> 'IDENTIQUE'
   and v.peut_courir_le > current_date - 30
 order by v.cheval, v.date desc;

-- Menage une fois la comparaison terminee :
--   drop view if exists v_comparaison;
--   drop table if exists prep_vetlist, import_vetlist;
