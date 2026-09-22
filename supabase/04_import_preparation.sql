-- =====================================================================
-- IMPORT SANS TERMINAL — ÉTAPE 1 sur 3 : préparation
--
-- À exécuter APRÈS avoir chargé tes trois CSV dans Supabase
-- (Table Editor > New table > Import data from CSV), nommés exactement :
--     import_chevaux      import_medicaments      import_traitements
--
-- Ce script ne touche à aucune de tes tables définitives. Il lit les
-- tables importées, retrouve tout seul les bonnes colonnes quels que
-- soient les intitulés de ton Sheet, et range le résultat dans trois
-- tables de travail préfixées « prep_ ».
-- =====================================================================

-- ---------------------------------------------------------------------
-- Fonctions utilitaires
-- ---------------------------------------------------------------------

-- Compare des intitulés de colonne sans tenir compte de la casse, des
-- accents, des espaces ni de la ponctuation : « Délai indicatif (j) » et
-- « delai indicatif j » sont reconnus comme identiques.
create or replace function import_norm(t text) returns text
language sql immutable as $$
  select trim(regexp_replace(
    lower(translate(coalesce(t, ''),
      'àâäáãåçéèêëíìîïñóòôöõúùûüýÿÀÂÄÁÃÅÇÉÈÊËÍÌÎÏÑÓÒÔÖÕÚÙÛÜÝ',
      'aaaaaaceeeeiiiinooooouuuuyyAAAAAACEEEEIIIINOOOOOUUUUY')),
    '[^a-z0-9]+', ' ', 'g'));
$$;

-- Cherche dans une table importée la première colonne correspondant à
-- l'un des intitulés proposés. Renvoie NULL si aucune ne correspond.
create or replace function import_colonne(p_table text, p_candidats text[])
returns text language plpgsql as $$
declare trouve text; cand text;
begin
  foreach cand in array p_candidats loop
    select column_name into trouve
      from information_schema.columns
     where table_schema = 'public' and table_name = p_table
       and import_norm(column_name) = import_norm(cand)
     limit 1;
    if trouve is not null then return trouve; end if;
  end loop;
  return null;
end $$;

-- Nom de cheval canonique : « Silent Warning (IRE) » -> « SILENT WARNING IRE »
create or replace function import_nom_cheval(t text) returns text
language sql immutable as $$
  select upper(trim(regexp_replace(
    regexp_replace(coalesce(t, ''), '[()]', ' ', 'g'), '\s+', ' ', 'g')));
$$;

-- Accepte 12/03/2026, 12-03-2026, 12.03.26 et 2026-03-12
create or replace function import_date(t text) returns date
language plpgsql immutable as $$
declare s text := trim(coalesce(t, '')); m text[]; an text;
begin
  if s = '' then return null; end if;
  if s ~ '^\d{4}-\d{1,2}-\d{1,2}' then
    return to_date(substring(s from '^\d{4}-\d{1,2}-\d{1,2}'), 'YYYY-MM-DD');
  end if;
  m := regexp_match(s, '^(\d{1,2})[/.\-](\d{1,2})[/.\-](\d{2,4})');
  if m is not null then
    an := case when length(m[3]) = 2 then '20' || m[3] else m[3] end;
    return to_date(lpad(m[1], 2, '0') || '/' || lpad(m[2], 2, '0') || '/' || an, 'DD/MM/YYYY');
  end if;
  return null;
exception when others then return null;
end $$;

-- Premier nombre entier trouvé dans le texte, sinon la valeur par défaut
create or replace function import_entier(t text, def integer) returns integer
language sql immutable as $$
  select coalesce(nullif(regexp_replace(coalesce(t, ''), '[^0-9-]', '', 'g'), '')::integer, def);
$$;

-- ---------------------------------------------------------------------
-- Préparation
-- ---------------------------------------------------------------------

create or replace procedure import_preparer()
language plpgsql as $$
declare
  c_nom text; c_sexe text; c_annee text; c_prop text; c_loc text;
  m_nom text; m_delai text; m_elim text; m_expr text; m_com text;
  t_cheval text; t_date text; t_type text; t_med text; t_prises text;
  t_interv text; t_poso text; t_ord text; t_fin text; t_notes text;
  manquantes text := '';
begin
  -- Les trois tables importées doivent exister
  if to_regclass('public.import_chevaux') is null then
    raise exception 'Table import_chevaux introuvable. Importe d''abord le CSV des chevaux sous ce nom exact.';
  end if;
  if to_regclass('public.import_medicaments') is null then
    raise exception 'Table import_medicaments introuvable. Importe d''abord le CSV des médicaments sous ce nom exact.';
  end if;
  if to_regclass('public.import_traitements') is null then
    raise exception 'Table import_traitements introuvable. Importe d''abord le CSV des traitements sous ce nom exact.';
  end if;

  -- Repérage des colonnes
  c_nom   := import_colonne('import_chevaux', array['nom','cheval','nom du cheval','horse']);
  c_sexe  := import_colonne('import_chevaux', array['sexe','sex']);
  c_annee := import_colonne('import_chevaux', array['annee de naissance','annee naissance','ne en','naissance','year']);
  c_prop  := import_colonne('import_chevaux', array['proprietaire','proprietaires','owner']);
  c_loc   := import_colonne('import_chevaux', array['location','cour','emplacement','box','ecurie']);

  m_nom   := import_colonne('import_medicaments', array['nom','medicament','produit','nom du medicament']);
  m_delai := import_colonne('import_medicaments', array['delai indicatif ordonnance','delai','delai j','delai jours','delai indicatif','withdrawal']);
  m_elim  := import_colonne('import_medicaments', array['delai elimination','delai elimination j','delai engagement supplementaire','date d engagement supplementaire','elimination']);
  m_expr  := import_colonne('import_medicaments', array['expression ordonnance','molecule','substance','principe actif']);
  m_com   := import_colonne('import_medicaments', array['comments','commentaire','commentaires','remarques']);

  t_cheval := import_colonne('import_traitements', array['cheval','nom du cheval','horse']);
  t_date   := import_colonne('import_traitements', array['date','date de traitement','date du traitement']);
  t_type   := import_colonne('import_traitements', array['type d evenement','type evenement','type','acte']);
  t_med    := import_colonne('import_traitements', array['medicament','produit','nom du medicament']);
  t_prises := import_colonne('import_traitements', array['nombre de prise','nombre de prises','nb prises','prises']);
  t_interv := import_colonne('import_traitements', array['intervalle j','intervalle','intervalle jours']);
  t_poso   := import_colonne('import_traitements', array['posologie','dose','dosage']);
  t_ord    := import_colonne('import_traitements', array['ordonnance','numero ordonnance','n ordonnance','no ordonnance']);
  t_fin    := import_colonne('import_traitements', array['fin de traitement reelle','fin reelle','arret','date d arret']);
  t_notes  := import_colonne('import_traitements', array['notes','remarque','remarques','commentaire']);

  -- Colonnes indispensables
  if c_nom is null then manquantes := manquantes || E'\n  - import_chevaux : colonne du nom du cheval'; end if;
  if m_nom is null then manquantes := manquantes || E'\n  - import_medicaments : colonne du nom du médicament'; end if;
  if m_delai is null then manquantes := manquantes || E'\n  - import_medicaments : colonne du délai'; end if;
  if t_cheval is null then manquantes := manquantes || E'\n  - import_traitements : colonne du cheval'; end if;
  if t_date is null then manquantes := manquantes || E'\n  - import_traitements : colonne de la date'; end if;
  if manquantes <> '' then
    raise exception 'Colonnes introuvables : %  %', manquantes,
      E'\n\nRenomme la colonne dans ton CSV, ou ajoute son intitulé dans la liste correspondante de ce script (procédure import_preparer).';
  end if;

  -- Chevaux
  drop table if exists prep_chevaux;
  execute format($f$
    create table prep_chevaux as
    select distinct on (import_nom_cheval(%1$I::text))
      import_nom_cheval(%1$I::text)              as nom,
      nullif(trim(%2$s), '')                     as sexe,
      nullif(regexp_replace(coalesce(%3$s,''), '[^0-9]', '', 'g'), '')::smallint as annee_naissance,
      nullif(trim(%4$s), '')                     as proprietaire,
      nullif(trim(%5$s), '')                     as location
    from import_chevaux
    where import_nom_cheval(%1$I::text) <> ''
    order by import_nom_cheval(%1$I::text)
  $f$, c_nom,
       coalesce(quote_ident(c_sexe)  || '::text', 'null::text'),
       coalesce(quote_ident(c_annee) || '::text', 'null::text'),
       coalesce(quote_ident(c_prop)  || '::text', 'null::text'),
       coalesce(quote_ident(c_loc)   || '::text', 'null::text'));

  -- Médicaments
  drop table if exists prep_medicaments;
  execute format($f$
    create table prep_medicaments as
    select distinct on (lower(trim(%1$I::text)))
      trim(%1$I::text)                    as nom,
      import_entier(%2$s, 0)              as delai_j,
      import_entier(%3$s, 0)              as delai_elimination_j,
      nullif(trim(%4$s), '')              as expression_ordonnance,
      nullif(trim(%5$s), '')              as commentaire
    from import_medicaments
    where trim(coalesce(%1$I::text, '')) <> ''
    order by lower(trim(%1$I::text))
  $f$, m_nom,
       coalesce(quote_ident(m_delai) || '::text', 'null::text'),
       coalesce(quote_ident(m_elim)  || '::text', 'null::text'),
       coalesce(quote_ident(m_expr)  || '::text', 'null::text'),
       coalesce(quote_ident(m_com)   || '::text', 'null::text'));

  -- Traitements
  drop table if exists prep_traitements;
  execute format($f$
    create table prep_traitements as
    select
      row_number() over ()                  as ligne,
      import_nom_cheval(%1$I::text)         as cheval,
      import_date(%2$I::text)               as date,
      nullif(trim(%3$s), '')                as type_brut,
      nullif(trim(%4$s), '')                as medicament,
      greatest(import_entier(%5$s, 1), 1)   as nombre_prises,
      greatest(import_entier(%6$s, 1), 1)   as intervalle_j,
      nullif(trim(%7$s), '')                as posologie,
      nullif(trim(%8$s), '')                as ordonnance_numero,
      import_date(%9$s)                     as fin_traitement_reelle,
      nullif(trim(%10$s), '')               as notes
    from import_traitements
  $f$, t_cheval, t_date,
       coalesce(quote_ident(t_type)   || '::text', 'null::text'),
       coalesce(quote_ident(t_med)    || '::text', 'null::text'),
       coalesce(quote_ident(t_prises) || '::text', 'null::text'),
       coalesce(quote_ident(t_interv) || '::text', 'null::text'),
       coalesce(quote_ident(t_poso)   || '::text', 'null::text'),
       coalesce(quote_ident(t_ord)    || '::text', 'null::text'),
       coalesce(quote_ident(t_fin)    || '::text', 'null::text'),
       coalesce(quote_ident(t_notes)  || '::text', 'null::text'));

  -- Rattachement du type d'événement à la liste officielle
  alter table prep_traitements add column type type_evenement;
  update prep_traitements p
     set type = d.type
    from delais_acte d
   where import_norm(d.type::text) = import_norm(p.type_brut);
  update prep_traitements
     set type = 'Administration médicament'
   where type is null;

  raise notice 'Préparation terminée : % chevaux, % médicaments, % traitements.',
    (select count(*) from prep_chevaux),
    (select count(*) from prep_medicaments),
    (select count(*) from prep_traitements);
end $$;

call import_preparer();

-- Aperçu : vérifie que les colonnes ont bien été reconnues.
select 'chevaux' as table_, count(*) as lignes from prep_chevaux
union all select 'medicaments', count(*) from prep_medicaments
union all select 'traitements', count(*) from prep_traitements;

select * from prep_chevaux limit 5;
select * from prep_medicaments limit 5;
select ligne, cheval, date, type, medicament, nombre_prises, intervalle_j, posologie
  from prep_traitements limit 5;
