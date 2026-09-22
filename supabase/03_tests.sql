-- =====================================================================
-- Tests des formules d'éligibilité.
-- À exécuter dans le SQL Editor : tout doit renvoyer ok = true.
-- Le script crée des données de test puis les supprime (rollback).
-- =====================================================================

begin;

insert into chevaux (id, nom) values
  ('11111111-1111-1111-1111-111111111111', 'TEST CHEVAL A'),
  ('22222222-2222-2222-2222-222222222222', 'TEST CHEVAL B');

insert into medicaments (id, nom, delai_j, delai_elimination_j) values
  ('33333333-3333-3333-3333-333333333333', 'TEST GASTROGARD', 7, 3),
  ('44444444-4444-4444-4444-444444444444', 'TEST BORGAL',     8, 0);

insert into traitements (id, cheval_id, date, type, medicament_id, nombre_prises, intervalle_j) values
  -- A : Borgal 5 prises, 1 jour d'intervalle, à partir du 01/09
  ('aaaaaaaa-0000-0000-0000-000000000001',
   '11111111-1111-1111-1111-111111111111', date '2026-09-01',
   'Administration médicament', '44444444-4444-4444-4444-444444444444', 5, 1),
  -- B : Gastrogard prise unique le 01/09 (7 j + 3 j)
  ('aaaaaaaa-0000-0000-0000-000000000002',
   '22222222-2222-2222-2222-222222222222', date '2026-09-01',
   'Administration médicament', '33333333-3333-3333-3333-333333333333', 1, 1),
  -- B : ondes de choc le 01/09 (délai d'acte 5 j, pas de produit)
  ('aaaaaaaa-0000-0000-0000-000000000003',
   '22222222-2222-2222-2222-222222222222', date '2026-09-01',
   'Ondes de choc', null, 1, 1),
  -- A : traitement espacé, 3 prises tous les 7 jours
  ('aaaaaaaa-0000-0000-0000-000000000004',
   '11111111-1111-1111-1111-111111111111', date '2026-09-01',
   'Administration médicament', '44444444-4444-4444-4444-444444444444', 3, 7);

select
  'durée 5 prises × 1 j = 5 j' as cas,
  duree_j = 5 as ok, duree_j as obtenu, 5 as attendu
from v_traitements where id = 'aaaaaaaa-0000-0000-0000-000000000001'
union all
select 'fin de traitement 01/09 + 5 j − 1 = 05/09',
  fin_traitement = date '2026-09-05', extract(day from fin_traitement)::int, 5
from v_traitements where id = 'aaaaaaaa-0000-0000-0000-000000000001'
union all
select 'Borgal : 05/09 + 8 + 0 + 0 + 1 = 14/09',
  peut_courir_le = date '2026-09-14', extract(day from peut_courir_le)::int, 14
from v_traitements where id = 'aaaaaaaa-0000-0000-0000-000000000001'
union all
select 'Gastrogard prise unique : 01/09 + 7 + 3 + 1 = 12/09',
  peut_courir_le = date '2026-09-12', extract(day from peut_courir_le)::int, 12
from v_traitements where id = 'aaaaaaaa-0000-0000-0000-000000000002'
union all
select 'Ondes de choc : 01/09 + 5 + 1 = 07/09',
  peut_courir_le = date '2026-09-07', extract(day from peut_courir_le)::int, 7
from v_traitements where id = 'aaaaaaaa-0000-0000-0000-000000000003'
union all
select 'durée 3 prises × 7 j = 15 j',
  duree_j = 15, duree_j, 15
from v_traitements where id = 'aaaaaaaa-0000-0000-0000-000000000004'
union all
select 'espacé : fin 15/09, peut courir 24/09',
  peut_courir_le = date '2026-09-24', extract(day from peut_courir_le)::int, 24
from v_traitements where id = 'aaaaaaaa-0000-0000-0000-000000000004';

-- Arrêt anticipé : la fin réelle prime sur la fin théorique
update traitements set fin_traitement_reelle = date '2026-09-03'
 where id = 'aaaaaaaa-0000-0000-0000-000000000001';

select 'arrêt anticipé au 03/09 : peut courir 12/09' as cas,
  peut_courir_le = date '2026-09-12' as ok,
  extract(day from peut_courir_le)::int as obtenu, 12 as attendu
from v_traitements where id = 'aaaaaaaa-0000-0000-0000-000000000001';

-- Vet List : au 20/09 le cheval B est encore bloqué par le traitement le plus long
select 'vet_list au 10/09 : B bloqué jusqu''au 12/09' as cas,
  (peut_courir = false and libre_le = date '2026-09-12') as ok,
  libre_le::text as obtenu, '2026-09-12' as attendu
from vet_list(date '2026-09-10') where cheval = 'TEST CHEVAL B';

select 'vet_list au 15/09 : B libre' as cas,
  peut_courir = true as ok, peut_courir::text as obtenu, 'true' as attendu
from vet_list(date '2026-09-15') where cheval = 'TEST CHEVAL B';

rollback;

-- =====================================================================
-- Référentiel unique (septembre 2026)
--
-- RÈGLE : une ligne de traitement pointe vers une entrée du référentiel ;
-- son délai vient de cette entrée, et d'elle seule. Quand un cheval a
-- plusieurs lignes en cours, vet_list retient la plus longue.
-- =====================================================================

begin;

insert into chevaux (id, nom) values
  ('77777777-7777-7777-7777-777777777777', 'TEST REFERENTIEL');

insert into medicaments (id, nom, delai_j, delai_elimination_j, evenement_compatible) values
  ('88888888-8888-8888-8888-888888888801', 'TEST DOS MESO',  30, 0, 'Infiltration'),
  ('88888888-8888-8888-8888-888888888802', 'TEST BORGAL',     3, 0, 'Administration médicament'),
  ('88888888-8888-8888-8888-888888888803', 'TEST GASTRO',     5, 3, 'Administration médicament'),
  ('88888888-8888-8888-8888-888888888804', 'TEST ONDES',      5, 0, 'Ondes de choc');

insert into traitements (id, cheval_id, date, type, medicament_id, nombre_prises, intervalle_j) values
  ('cccccccc-0000-0000-0000-000000000001',
   '77777777-7777-7777-7777-777777777777', date '2026-08-28',
   'Infiltration', '88888888-8888-8888-8888-888888888801', 1, 1),
  ('cccccccc-0000-0000-0000-000000000002',
   '77777777-7777-7777-7777-777777777777', date '2026-08-28',
   'Administration médicament', '88888888-8888-8888-8888-888888888803', 1, 1),
  ('cccccccc-0000-0000-0000-000000000003',
   '77777777-7777-7777-7777-777777777777', date '2026-08-28',
   'Ondes de choc', '88888888-8888-8888-8888-888888888804', 1, 1);

select 'méso 30 + 0 : 28/08 + 30 + 1 = 28/09' as cas,
  peut_courir_le = date '2026-09-28' as ok,
  peut_courir_le::text as obtenu, '2026-09-28' as attendu
from v_traitements where id = 'cccccccc-0000-0000-0000-000000000001'
union all
select 'le délai vient de l''entrée seule : 30 j',
  delai_total = 30, delai_total::text, '30'
from v_traitements where id = 'cccccccc-0000-0000-0000-000000000001'
union all
select 'Gastrogard 5 + 3 : total 8',
  delai_total = 8, delai_total::text, '8'
from v_traitements where id = 'cccccccc-0000-0000-0000-000000000002'
union all
select 'ondes de choc, entrée du référentiel : 5 j',
  delai_total = 5, delai_total::text, '5'
from v_traitements where id = 'cccccccc-0000-0000-0000-000000000003';

-- Trois lignes le même jour : la plus longue gouverne le cheval
select 'trois lignes : la plus longue l''emporte (28/09)' as cas,
  libre_le = date '2026-09-28' as ok,
  libre_le::text as obtenu, '2026-09-28' as attendu
from vet_list(date '2026-09-01') where cheval = 'TEST REFERENTIEL';

rollback;
