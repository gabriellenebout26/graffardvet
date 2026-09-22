-- =====================================================================
-- APPLIQUER LES CORRECTIONS DE CHRIS
--
-- Pour quelques lignes, l'édition directe dans Table Editor > medicaments
-- est plus rapide. Ce script sert quand Chris te renvoie un tableau
-- corrigé et qu'il y a beaucoup de lignes à reprendre.
--
-- PRÉPARATION
-- 1. Le fichier renvoyé par Chris doit contenir au minimum :
--    le nom du produit, et le délai corrigé.
--    Une colonne de délai d'élimination corrigé est facultative.
-- 2. Renomme-le import_corrections.csv
-- 3. Table Editor > New table > Import data from CSV (table : import_corrections)
-- 4. Exécute ce script. Il montre d'abord, applique ensuite.
-- =====================================================================

create or replace procedure preparer_corrections()
language plpgsql as $$
declare c_nom text; c_delai text; c_elim text;
begin
  if to_regclass('public.import_corrections') is null then
    raise exception 'Table import_corrections introuvable.';
  end if;

  c_nom   := import_colonne('import_corrections', array[
    'produit ou acte','produit','nom','medicament','nom du medicament']);
  c_delai := import_colonne('import_corrections', array[
    'delai corrige','delai corrige j','nouveau delai','delai valide',
    'delai j','delai actuel j','delai']);
  c_elim  := import_colonne('import_corrections', array[
    'delai elimination corrige','nouvelle elimination','delai elimination j',
    'delai elimination','elimination']);

  if c_nom is null then
    raise exception 'Colonne du nom de produit introuvable dans import_corrections.';
  end if;
  if c_delai is null then
    raise exception 'Colonne du délai corrigé introuvable dans import_corrections.';
  end if;

  drop table if exists prep_corrections;
  execute format($f$
    create table prep_corrections as
    select trim(%1$I::text)                          as nom,
           import_entier(%2$I::text, null)           as delai_j,
           %3$s                                      as delai_elimination_j
      from import_corrections
     where trim(coalesce(%1$I::text, '')) <> ''
  $f$, c_nom, c_delai,
       case when c_elim is null then 'null::integer'
            else 'import_entier(' || quote_ident(c_elim) || '::text, null)' end);

  raise notice 'Corrections lues : % lignes.', (select count(*) from prep_corrections);
end $$;

call preparer_corrections();

-- ---------------------------------------------------------------------
-- 1. CE QUI VA CHANGER — vérifie avant d'appliquer
-- ---------------------------------------------------------------------
select
  m.nom,
  m.delai_j                                    as delai_avant,
  p.delai_j                                    as delai_apres,
  m.delai_elimination_j                        as elimination_avant,
  coalesce(p.delai_elimination_j, m.delai_elimination_j) as elimination_apres,
  (p.delai_j + coalesce(p.delai_elimination_j, m.delai_elimination_j))
    - (m.delai_j + m.delai_elimination_j)      as ecart_jours,
  case
    when p.delai_j < m.delai_j then '⚠️  PLUS PERMISSIF — les chevaux courront plus tôt'
    else 'Plus restrictif ou identique'
  end                                          as effet
from medicaments m
join prep_corrections p on lower(trim(p.nom)) = lower(trim(m.nom))
where p.delai_j is not null
  and (p.delai_j <> m.delai_j
       or coalesce(p.delai_elimination_j, m.delai_elimination_j) <> m.delai_elimination_j)
order by
  case when p.delai_j < m.delai_j then 0 else 1 end,
  abs(p.delai_j - m.delai_j) desc,
  m.nom;

-- Les lignes du fichier qui ne correspondent à aucun produit connu
select p.nom as produit_du_fichier_non_reconnu
  from prep_corrections p
 where not exists (
   select 1 from medicaments m where lower(trim(m.nom)) = lower(trim(p.nom)))
 order by p.nom;


-- ---------------------------------------------------------------------
-- 2. APPLIQUER
--    Décommente le bloc ci-dessous UNE FOIS que le tableau 1 te convient,
--    puis relance le script.
-- ---------------------------------------------------------------------

/*
begin;

update medicaments m
   set delai_j             = p.delai_j,
       delai_elimination_j = coalesce(p.delai_elimination_j, m.delai_elimination_j)
  from prep_corrections p
 where lower(trim(p.nom)) = lower(trim(m.nom))
   and p.delai_j is not null;

commit;

-- Contrôle : la Vet List après correction
select cheval, libre_le, jours_restants, motif
  from vet_list(current_date)
 where not peut_courir
 order by libre_le desc;
*/
