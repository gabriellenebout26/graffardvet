-- =====================================================================
-- Amorçage — à exécuter après 01_schema.sql
-- Remplace les emails par les vrais comptes Google de l'écurie.
-- =====================================================================

insert into responsables (email, nom, role) values
  ('b00578075@essec.edu',            'Gabrielle',        'admin'),
  ('francis@ecurie-graffard.com',    'Francis Graffard', 'consultation'),
  ('romain@ecurie-graffard.com',     'Romain',           'consultation')
  -- ('responsable1@...',            'Responsable cour 1', 'saisie'),
on conflict (email) do update set nom = excluded.nom, role = excluded.role;

-- ---------------------------------------------------------------------
-- Référentiel — médicaments, interventions et vaccins dans une seule
-- liste. Valeurs fournies par l'écurie le 22/09/2026.
-- ---------------------------------------------------------------------

insert into medicaments (nom, delai_j, delai_elimination_j, evenement_compatible) values
  ('Antalzen',        12, 3, 'Administration médicament'),
  ('Avemix',          15, 3, 'Administration médicament'),
  ('Azote',           15, 3, 'Administration médicament'),
  ('Baytril',          4, 3, 'Administration médicament'),
  ('Borgal',           3, 0, 'Administration médicament'),
  ('Calmagine',        5, 3, 'Administration médicament'),
  ('Calmivet',        12, 3, 'Administration médicament'),
  ('Carbesia',         8, 3, 'Administration médicament'),
  ('Chorulon',         7, 3, 'Administration médicament'),
  ('Cloxagel',         3, 0, 'Administration médicament'),
  ('Depociline',      30, 0, 'Administration médicament'),
  ('Dermogine',        3, 0, 'Administration médicament'),
  ('Dimazon',          4, 3, 'Administration médicament'),
  ('Diurizone',       12, 3, 'Administration médicament'),
  ('Equibactin',       3, 0, 'Administration médicament'),
  ('G4',               3, 0, 'Administration médicament'),
  ('Gastrogard',       5, 3, 'Administration médicament'),
  ('Glucocorticoïde', 30, 0, 'Administration médicament'),
  ('Histabiosone',    21, 3, 'Administration médicament'),
  ('Iodure',           3, 0, 'Administration médicament'),
  ('Lasilix',          4, 3, 'Administration médicament'),
  ('Lurocaïne',       15, 3, 'Administration médicament'),
  ('Marbocyl',         4, 3, 'Administration médicament'),
  ('Metacam',          5, 3, 'Administration médicament'),
  ('Oxytetracycline',  4, 3, 'Administration médicament'),
  ('Rapidexon',        7, 3, 'Administration médicament'),
  ('Recocam',         30, 0, 'Administration médicament'),
  ('Rehydex',          3, 0, 'Administration médicament'),
  ('Relaquine',       12, 3, 'Administration médicament'),
  ('Ringer lactate',   3, 0, 'Administration médicament'),
  ('Ronaxan',          4, 3, 'Administration médicament'),
  ('Sedomidine',       4, 3, 'Administration médicament'),
  ('Ventipulmin',     30, 0, 'Administration médicament'),
  ('Dos/Méso',        30, 0, 'Infiltration'),
  ('Horstem',         14, 0, 'Infiltration'),
  ('IRAP',            14, 0, 'Infiltration'),
  ('Adequan',          3, 0, 'Vermifuge'),
  ('Grippe',           4, 0, 'Vaccin'),
  ('Rhino',            4, 0, 'Vaccin'),
  ('Ondes de choc',    5, 0, 'Ondes de choc')
on conflict (nom) do update set
  delai_j              = excluded.delai_j,
  delai_elimination_j  = excluded.delai_elimination_j,
  evenement_compatible = excluded.evenement_compatible;
