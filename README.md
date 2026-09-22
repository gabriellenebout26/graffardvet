# Suivi des traitements — Écurie Graffard

Remplaçant de l'app AppSheet : même périmètre, une vraie base de données et une
interface pensée pour la consultation quotidienne.

- **Base** : Supabase (PostgreSQL) — les formules de délai vivent dans la base,
  pas dans l'app. Un seul endroit à corriger si une règle change.
- **App** : Next.js 15 + React, déployée sur Vercel. Fonctionne sur mobile.
- **Connexion** : lien à usage unique envoyé par email. Pas de mot de passe à
  créer ni à transmettre aux responsables de cour.

---

## Ce que tu fais de ton côté — 5 étapes, une petite heure

### 1. Créer le projet Supabase (10 min)

> Les scripts du dossier `supabase/` s'exécutent dans l'ordre de leur numéro :
> `01` à `03` pour monter la base (cette étape), `04` à `06` pour importer tes
> données (étape 2). Rien d'autre n'est à coller dans Supabase — le dossier
> `tests/` est réservé aux tests hors Supabase, voir `tests/README.md`.

1. [supabase.com](https://supabase.com) → **New project**
   - Nom : `graffard-vet`
   - Region : **Europe (Paris)** ou Frankfurt
   - Note le mot de passe de la base quelque part (tu ne t'en serviras
     probablement jamais, mais il n'est plus affiché ensuite).
2. Une fois le projet prêt : **SQL Editor** → **New query**
3. Colle le contenu de `supabase/01_schema.sql`, **Run**. Les messages
   `NOTICE: ... does not exist, skipping` sont normaux.
4. Nouvelle requête, colle `supabase/02_seed.sql` — **en remplaçant d'abord les
   emails** par les vraies adresses (la tienne en `admin`, Francis et Romain en
   `consultation`, les responsables de cour en `saisie`). **Run**.
5. Vérification : nouvelle requête, colle `supabase/03_tests.sql`, **Run**.
   Les 10 lignes doivent afficher `ok = t`. Le script se termine par un
   `ROLLBACK` : il ne laisse aucune donnée derrière lui.

### 2. Importer les données du Sheet — tout dans le navigateur (20 min)

Aucun terminal, aucune installation. Trois scripts SQL font le travail.

1. Dans `Suivi_Ecurie_Graffard_v2`, pour chacun des trois onglets :
   **Fichier → Télécharger → CSV**.
2. Renomme les trois fichiers **exactement** ainsi — c'est ce nom qui donnera
   son nom à la table :

   - `import_chevaux.csv`
   - `import_medicaments.csv`
   - `import_traitements.csv`

3. Dans Supabase : **Table Editor → New table → Import data from CSV**, un
   fichier à la fois. Supabase crée la table et devine les colonnes tout seul.
   Tu dois voir apparaître `import_chevaux`, `import_medicaments` et
   `import_traitements` dans la liste des tables.
4. **SQL Editor** → colle `supabase/04_import_preparation.sql` → **Run**.
   Ce script retrouve les bonnes colonnes quels que soient tes intitulés
   (« Nom du cheval », « Délai indicatif ordonnance »…), met les noms de chevaux
   au format canonique et lit les dates au format français comme ISO. Il affiche
   un aperçu : **vérifie que les colonnes sont bien tombées en face**.
5. Colle `supabase/05_import_verification.sql` → **Run**. Ce script **n'écrit
   rien**. Il te sort deux tableaux :

   - un résumé : combien de traitements seront importés, combien ignorés
   - la liste des problèmes, `BLOQUANT` d'abord, avec le numéro de ligne du CSV

   **C'est le moment de corriger le Sheet**, pas après. Un `BLOQUANT` veut dire
   que le traitement ne sera pas importé du tout. Un `À VÉRIFIER` s'importera,
   mais mérite un coup d'œil — en particulier les délais à 0 j, qui feraient
   annoncer un cheval disponible à tort.
6. Après correction : réexporte le CSV, réimporte la table (supprime l'ancienne
   d'abord), relance `04` puis `05`.
7. Quand le rapport te convient : colle `supabase/06_import_execution.sql` →
   **Run**. Il charge tout dans une transaction — en cas d'erreur, rien n'est
   écrit — et termine en affichant **la liste des chevaux actuellement sous
   délai**. Compare-la à ta Vet List AppSheet du jour : c'est le vrai test.

Le script est relançable sans créer de doublons. Si un intitulé de colonne
n'est pas reconnu, le script te le dit et s'arrête : ajoute-le dans la liste
correspondante de la procédure `import_preparer`, en haut du fichier `04`.

<details>
<summary>Variante avec un terminal (si tu as Node.js)</summary>

`scripts/import-sheet.mjs` fait la même chose en ligne de commande, avec les
CSV dans un dossier `data/` et les clés dans `.env.local` :

```bash
npm install
npm run import:dry   # rapport, n'écrit rien
npm run import
```

La table de correspondance des colonnes est la constante `MAP` en haut du
fichier.
</details>

### 3. Lancer l'app en local (5 min)

```bash
npm run dev
```

Ouvre http://localhost:3000, connecte-toi avec ton email. Vérifie sur trois ou
quatre chevaux que les dates « peut courir » correspondent à ce qu'affiche
AppSheet aujourd'hui.

### 4. Déployer sur Vercel (10 min)

1. Mets le dossier sur GitHub (dépôt privé).
2. [vercel.com](https://vercel.com) → **Add New → Project** → sélectionne le dépôt.
3. **Environment Variables** : ajoute `NEXT_PUBLIC_SUPABASE_URL` et
   `NEXT_PUBLIC_SUPABASE_ANON_KEY`. **Pas** la `service_role`.
4. **Deploy**. Tu obtiens une URL du type `graffard-vet.vercel.app`.
5. Retourne dans Supabase → **Authentication → URL Configuration** : mets cette
   URL en `Site URL`, et ajoute `https://…vercel.app/auth/retour` dans
   **Redirect URLs**. Sans ça, les liens de connexion renverront vers localhost.

### 5. Ouvrir les accès (5 min)

Supabase → **Table Editor → responsables** : une ligne par personne, avec son
email et son rôle.

| Rôle | Qui | Ce qu'il peut faire |
|---|---|---|
| `consultation` | Francis, Romain | Vet List, chevaux, historiques — lecture seule |
| `saisie` | responsables de cour | + enregistrer traitements et administrations |
| `admin` | toi | + référentiel des délais et gestion des accès |

Les droits sont appliqués **dans la base** (Row Level Security), pas seulement
dans l'interface : un utilisateur en consultation ne peut techniquement pas
écrire, même en passant à côté de l'app.

---

## Période de double saisie

Garde AppSheet en parallèle une à deux semaines. Chaque matin, compare la Vet
List des deux côtés. Quand plus aucun écart n'apparaît pendant une semaine
pleine, bascule les responsables de cour et passe AppSheet en lecture seule
(ne le supprime pas tout de suite).

---

## Les écrans

| Écran | Pour qui | Ce qu'il remplace |
|---|---|---|
| **Vet List** | Francis, Romain | La vue Vet list — avec en plus le sélecteur de date de course : « qui est disponible pour le 12 octobre ? » |
| **Traitements du jour** | responsables de cour | La vue Traitements du jour, avec *Administré*, *Arrêter*, *Dupliquer* |
| **Chevaux / fiche cheval** | tous | L'historique par cheval |
| **Nouveau traitement** | responsables de cour | Le formulaire Traitements, avec l'aperçu du calcul en direct pendant la saisie |
| **Référentiel des délais** | toi | La table des médicaments |
| **Utilisateurs** | toi | La table Responsables |

---

## Les formules

Elles sont dans `supabase/01_schema.sql`, dans la vue `v_traitements` :

```
Durée (j)            = (Nombre de prises − 1) × Intervalle (j) + 1
Fin de traitement    = Date + Durée − 1        (ou la fin réelle si arrêt anticipé)
Peut courir le       = Fin de traitement + Délai produit + Délai élimination
                                         + Délai acte + 1
```

Le `+ 1` final est l'article 85 (délai exclusif : le cheval court à J+1), validé
par Chris. Le délai d'élimination couvre la déclaration de partant probable
(~3 jours avant la course, où le cheval peut être contrôlé) : c'est le `+3` de
produits comme le Gastrogard.

Les délais par acte sans produit (ondes de choc 5 j, vulvoplastie 15 j,
infiltration 30 j) sont dans la table `delais_acte` — modifiables sans toucher
au code.

**Le formulaire de saisie affiche un aperçu du calcul**, dans
`src/lib/calcul.ts`. C'est une copie des formules SQL, pour l'affichage en
direct uniquement : la valeur qui fait foi est toujours celle de la base.
`scripts/test-calcul.mjs` vérifie que les deux donnent exactement les mêmes
dates — à relancer si tu touches à une formule.

## Tests

```bash
node scripts/test-calcul.mjs   # aperçu du formulaire — 8 cas
```

Et côté base, `supabase/03_tests.sql` dans le SQL Editor — 10 cas, dont l'arrêt
anticipé, les traitements espacés, les passages d'année et les bissextiles.

Détail dans `tests/README.md`.

---

## Ce qui n'est pas dans cette V1

Volontairement, pour sortir vite :

- **Dépôt des PDF d'ordonnance** — le bucket Storage `ordonnances` et la colonne
  `ordonnance_url` sont déjà créés, il ne manque que le champ d'upload dans le
  formulaire. Une demi-journée.
- **Lecture automatique des ordonnances de Chris** — l'étape d'après, et le vrai
  gain de temps : extraction molécule/posologie du PDF, pré-remplissage du
  formulaire, validation humaine avant écriture.
- **Édition du référentiel depuis l'app** — pour l'instant via le Table Editor
  de Supabase, ce qui est suffisant pour quelques modifications par an.
- **Notifications** (fin de traitement, cheval redevenu engageable).
