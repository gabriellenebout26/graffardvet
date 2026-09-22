-- =====================================================================
-- ÉTAT DES LIEUX — après import et correctif. N'écrit rien.
-- Cinq tableaux à lire de haut en bas.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. Ce que contient la base
-- ---------------------------------------------------------------------
select 'Chevaux actifs'        as element, count(*)::text as valeur from chevaux where actif
union all
select 'Chevaux inactifs',     count(*)::text from chevaux where not actif
union all
select 'Médicaments / actes',  count(*)::text from medicaments
union all
select 'Traitements',          count(*)::text from traitements
union all
select 'Traitement le plus ancien', coalesce(min(date)::text, '—') from traitements
union all
select 'Traitement le plus récent', coalesce(max(date)::text, '—') from traitements
union all
select 'Chevaux sous délai aujourd''hui',
       (select count(*)::text from vet_list(current_date) where not peut_courir);

-- ---------------------------------------------------------------------
-- 2. Les chevaux inactifs — ils ne doivent PAS apparaître en Vet List
--    (tableau vide = soit 05c n'a pas tourné, soit aucun cheval parti)
-- ---------------------------------------------------------------------
select c.nom,
       count(t.id)      as traitements_conserves,
       max(t.date)      as dernier_traitement
  from chevaux c
  left join traitements t on t.cheval_id = c.id
 where not c.actif
 group by c.nom
 order by c.nom;

-- Contrôle : un cheval inactif ne doit jamais ressortir ici.
select 'ANOMALIE : cheval inactif présent en Vet List' as alerte, v.cheval
  from vet_list(current_date) v
  join chevaux c on c.id = v.cheval_id
 where not c.actif;

-- ---------------------------------------------------------------------
-- 3. Les délais à zéro — un cheval serait annoncé disponible aussitôt
-- ---------------------------------------------------------------------
select m.nom, m.delai_j, m.delai_elimination_j,
       count(t.id) as fois_utilise
  from medicaments m
  left join traitements t on t.medicament_id = m.id
 where m.delai_j = 0 and m.delai_elimination_j = 0
 group by m.nom, m.delai_j, m.delai_elimination_j
 order by count(t.id) desc;

-- ---------------------------------------------------------------------
-- 4. Les délais anormalement longs — reste du double comptage ?
--    Au-delà de 45 jours, ça mérite un regard.
-- ---------------------------------------------------------------------
select v.cheval, v.date, v.type, v.medicament,
       v.duree_j, v.delai_j, v.delai_elimination_j, v.delai_acte_j,
       v.peut_courir_le,
       (v.peut_courir_le - v.date) as total_jours
  from v_traitements v
 where (v.peut_courir_le - v.date) > 45
 order by (v.peut_courir_le - v.date) desc
 limit 20;

-- ---------------------------------------------------------------------
-- 5. LA VET LIST DU JOUR — à comparer ligne à ligne avec AppSheet
-- ---------------------------------------------------------------------
select cheval, location, libre_le, jours_restants, motif
  from vet_list(current_date)
 where not peut_courir
 order by cheval;
