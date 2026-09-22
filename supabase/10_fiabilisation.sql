-- =====================================================================
-- FIABILISATION — quatre contrôles avant de faire confiance aux chiffres.
-- N'écrit rien.
--
-- Chaque tableau se récupère avec le bouton « Export » du SQL Editor,
-- pour l'envoyer à Chris ou l'imprimer.
-- =====================================================================


-- =====================================================================
-- A. FRAÎCHEUR DES DONNÉES
--    Le calcul le plus juste du monde sur des données incomplètes
--    donne un résultat faux. On commence par là.
-- =====================================================================

select
  'Dernier traitement enregistré'             as controle,
  coalesce(max(date)::text, 'aucun')          as valeur,
  case
    when max(date) is null then 'Aucune donnée'
    when max(date) < current_date - 21 then
      '⚠️  Plus de 3 semaines — le Sheet est-il à jour ?'
    when max(date) < current_date - 7 then
      'À vérifier : plus d''une semaine sans saisie'
    else 'Récent, cohérent avec une activité normale'
  end                                          as verdict
from traitements;

-- Rythme des saisies sur 12 mois : un trou révèle une période non reportée
select
  to_char(date_trunc('month', date), 'YYYY-MM')  as mois,
  count(*)                                        as traitements,
  count(distinct cheval_id)                       as chevaux_concernes
from traitements
where date > current_date - interval '12 months'
group by date_trunc('month', date)
order by date_trunc('month', date) desc;


-- =====================================================================
-- B. RÉFÉRENTIEL À FAIRE VALIDER PAR CHRIS
--    Trié par fréquence d'usage : les premières lignes couvrent
--    l'essentiel des traitements. S'il n'a que vingt minutes, elles
--    suffisent.
--
--    Exporte ce tableau, ajoute deux colonnes vides « délai corrigé »
--    et « commentaire », et envoie-le-lui.
-- =====================================================================

select
  m.nom                                         as produit_ou_acte,
  m.expression_ordonnance                       as molecule,
  m.delai_j                                     as delai_actuel_j,
  m.delai_elimination_j                         as delai_elimination_j,
  m.delai_j + m.delai_elimination_j + 1         as total_jours_avant_course,
  count(t.id)                                   as fois_utilise,
  max(t.date)                                   as derniere_utilisation,
  case
    when m.delai_j = 0 and m.delai_elimination_j = 0
      then '⚠️  Aucun délai : le cheval est annoncé disponible aussitôt'
    when m.delai_j = 0
      then '⚠️  Délai principal à zéro'
    when m.delai_j >= 30
      then 'Délai long — confirmer qu''il s''agit bien d''un acte'
    when m.delai_elimination_j = 0 and m.delai_j between 1 and 15
      then 'Pas de +3 j partant probable — volontaire ?'
    else ''
  end                                           as point_a_confirmer
from medicaments m
left join traitements t on t.medicament_id = m.id
group by m.id, m.nom, m.expression_ordonnance, m.delai_j, m.delai_elimination_j
order by count(t.id) desc, m.nom;

-- Les délais par acte, pour les lignes sans produit renseigné.
-- Ceux-là, c'est moi qui les ai devinés : à confirmer un par un.
select
  d.type                                        as type_d_acte,
  d.delai_j                                     as delai_actuel_j,
  d.commentaire,
  count(t.id) filter (where t.medicament_id is null) as fois_utilise_sans_produit,
  'Valeur posée par défaut — à confirmer avec Chris' as point_a_confirmer
from delais_acte d
left join traitements t on t.type = d.type
group by d.type, d.delai_j, d.commentaire
order by count(t.id) filter (where t.medicament_id is null) desc, d.type;


-- =====================================================================
-- C. ÉCHANTILLON DE VÉRIFICATION CONTRE L'AGENDA PAPIER
--
--    Deux groupes :
--    - les chevaux actuellement sous délai : ce sont eux qui peuvent
--      coûter une course ou un contrôle positif
--    - un échantillon des traitements récents, pour tester la saisie
--
--    Imprime, va chercher l'agenda, et coche ligne à ligne.
-- =====================================================================

-- C1. Tous les chevaux actuellement sous délai
select
  'SOUS DÉLAI'                as groupe,
  v.cheval,
  v.date                      as date_traitement,
  v.type,
  v.medicament,
  v.posologie,
  v.nombre_prises,
  v.ordonnance_numero,
  v.fin_traitement,
  v.peut_courir_le,
  ''                          as conforme_agenda_O_N,
  ''                          as correction
from v_traitements v
join chevaux c on c.id = v.cheval_id
where c.actif
  and v.peut_courir_le > current_date
order by v.peut_courir_le desc, v.cheval;

-- C2. Vingt traitements récents tirés au hasard
select
  'ÉCHANTILLON'               as groupe,
  v.cheval,
  v.date                      as date_traitement,
  v.type,
  v.medicament,
  v.posologie,
  v.nombre_prises,
  v.ordonnance_numero,
  v.fin_traitement,
  v.peut_courir_le,
  ''                          as conforme_agenda_O_N,
  ''                          as correction
from v_traitements v
join chevaux c on c.id = v.cheval_id
where c.actif
  and v.date > current_date - interval '90 days'
  and v.peut_courir_le <= current_date
order by random()
limit 20;


-- =====================================================================
-- D. INCOHÉRENCES INTERNES
--    Ce que la base peut détecter seule, sans référence extérieure.
-- =====================================================================

select 'Traitement dans le futur' as anomalie, c.nom as cheval,
       t.date::text as detail
  from traitements t join chevaux c on c.id = t.cheval_id
 where t.date > current_date

union all
select 'Arrêt antérieur au début', c.nom,
       'début ' || t.date || ', arrêt ' || t.fin_traitement_reelle
  from traitements t join chevaux c on c.id = t.cheval_id
 where t.fin_traitement_reelle is not null and t.fin_traitement_reelle < t.date

union all
select 'Durée supérieure à 60 jours', c.nom,
       v.duree_j || ' jours (' || v.nombre_prises || ' prises × ' || v.intervalle_j || ' j)'
  from v_traitements v join chevaux c on c.id = v.cheval_id
  join traitements t on t.id = v.id
 where v.duree_j > 60

union all
select 'Deux traitements identiques le même jour', c.nom,
       t.date || ' — ' || coalesce(m.nom, t.type::text) || ' (' || count(*) || ' fois)'
  from traitements t
  join chevaux c on c.id = t.cheval_id
  left join medicaments m on m.id = t.medicament_id
 group by c.nom, t.date, m.nom, t.type, t.cheval_id, t.medicament_id
having count(*) > 1

union all
select 'Cheval sans aucun traitement', c.nom, 'effectif actif'
  from chevaux c
 where c.actif
   and not exists (select 1 from traitements t where t.cheval_id = c.id)

order by 1, 2;
