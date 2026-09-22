# Tests

## Ce dossier ne concerne pas Supabase

`shim-postgres-local.sql` ne doit **jamais** être exécuté sur le projet
Supabase. Il recrée artificiellement des objets que Supabase fournit déjà
(schémas `auth` et `storage`, rôle `authenticated`) pour pouvoir vérifier le
schéma sur un PostgreSQL ordinaire, hors Supabase.

Sur Supabase, il n'y a que **trois** fichiers à exécuter, dans l'ordre, et ils
sont tous dans le dossier `supabase/` :

1. `supabase/01_schema.sql` — tables, vues de calcul, sécurité
2. `supabase/02_seed.sql` — utilisateurs et référentiel de départ
3. `supabase/03_tests.sql` — vérification (se termine par un `ROLLBACK`, ne
   laisse aucune donnée)

## Les deux jeux de tests

**Formules côté base** — `supabase/03_tests.sql`, à coller dans le SQL Editor
de Supabase. 10 cas : durée sur traitement espacé, arrêt anticipé, délai
d'acte sans produit, Gastrogard +3 j, Vet List à une date donnée. Tout doit
renvoyer `ok = t`.

**Formules côté interface** — `node scripts/test-calcul.mjs`, sans rien
installer d'autre. 8 cas qui vérifient que l'aperçu affiché pendant la saisie
donne exactement les mêmes dates que la base, y compris sur les passages
d'année et les années bissextiles.

## Vérifier le schéma sur un PostgreSQL local (optionnel)

Utile seulement si tu modifies `01_schema.sql` et veux le tester sans toucher
au projet Supabase.

```bash
createdb graffard_test
psql -d graffard_test -f tests/shim-postgres-local.sql
psql -d graffard_test -f supabase/01_schema.sql
psql -d graffard_test -f supabase/03_tests.sql
```
