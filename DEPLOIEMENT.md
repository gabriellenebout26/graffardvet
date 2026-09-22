# Mettre l'app en ligne

Environ vingt minutes, entièrement dans le navigateur. Aucun terminal.

---

## Tes valeurs

Elles sont déjà remplies ci-dessous, tu n'as qu'à copier.

```
NEXT_PUBLIC_SUPABASE_URL
https://mdbnidezfcvarfzyhdco.supabase.co

NEXT_PUBLIC_SUPABASE_ANON_KEY
eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1kYm5pZGV6ZmN2YXJmenloZGNvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODk0ODI2NDIsImV4cCI6MjEwNTA1ODY0Mn0.VFbQPwYC7ZEmMOIjAj-ptmO3KR1_fPrQYKwPoVMicW0
```

Cette clé est faite pour être publique : elle part dans le navigateur de
chaque utilisateur. Ce qui protège tes données, c'est la sécurité au niveau
des lignes déjà en place dans Supabase — seules les adresses inscrites dans
la table `responsables` peuvent lire quoi que ce soit.

---

## 1. Mettre le code sur GitHub (10 min)

1. Décompresse `graffard-vet.zip` sur ton bureau.
2. Va sur [github.com/new](https://github.com/new).
   - Nom : `graffard-vet`
   - Coche **Private**
   - Ne coche ni README, ni .gitignore, ni licence
   - **Create repository**
3. Sur la page qui s'affiche, clique **uploading an existing file**.
4. Ouvre le dossier `graffard-vet` décompressé, sélectionne **tout son
   contenu** (pas le dossier lui-même : les fichiers et sous-dossiers qui
   sont dedans) et fais-le glisser dans la fenêtre GitHub.

   GitHub conserve l'arborescence. Tu dois voir apparaître `src`,
   `supabase`, `scripts`, `package.json`, etc.
5. En bas, **Commit changes**.

---

## 2. Déployer sur Vercel (5 min)

1. [vercel.com/new](https://vercel.com/new) → connecte ton compte GitHub si
   ce n'est pas déjà fait.
2. Trouve `graffard-vet` dans la liste → **Import**.
3. Ne touche à rien dans Framework Preset : Vercel reconnaît Next.js.
4. Déplie **Environment Variables** et ajoute les **deux** lignes du haut de
   ce document. Nom à gauche, valeur à droite, une par une.
5. **Deploy**. Compte deux à trois minutes.

Tu obtiens une adresse du type `graffard-vet-xxxx.vercel.app`.

---

## 3. Autoriser la connexion (3 min) — indispensable

Sans cette étape, les liens de connexion renverront vers une page morte.

Dans Supabase → **Authentication** → **URL Configuration** :

- **Site URL** : colle ton adresse Vercel complète, avec `https://`
- **Redirect URLs** : ajoute la même adresse suivie de `/auth/retour`

  Exemple : `https://graffard-vet-xxxx.vercel.app/auth/retour`

**Save**.

---

## 4. Se connecter

Ouvre ton adresse Vercel. Saisis **b00578075@essec.edu** — c'est l'adresse
inscrite en `admin` dans la base. Tu reçois un lien par email, valable une
heure, à ouvrir depuis le même appareil.

Tu devrais voir ta Vet List avec tes 214 chevaux, et REGAL RESOLVE GB
et ALPAZORA FR signalés sous délai.

---

## Si ça coince

**« Invalid login credentials » ou aucun email reçu.** Supabase envoie les
emails via son service de démonstration, limité à quelques envois par heure.
Regarde dans Supabase → Authentication → Users : si ton compte y apparaît,
l'envoi a fonctionné et le mail est probablement en spam.

**La page se charge mais la liste est vide.** Les variables d'environnement
sont mal saisies, ou tu as oublié de redéployer après les avoir ajoutées.
Vercel → Settings → Environment Variables pour vérifier, puis
Deployments → ⋯ → Redeploy.

**« Accès non ouvert ».** Ton adresse n'est pas dans la table
`responsables`, ou tu t'es connectée avec une autre adresse que
b00578075@essec.edu.

---

## Ensuite

Pour ajouter Francis, Romain et les responsables de cour, il suffit de
mettre leurs vraies adresses dans la table `responsables` — les trois
lignes actuelles contiennent des adresses d'exemple pour Francis et Romain.
Ils se connecteront avec un lien envoyé à cette adresse, sans mot de passe
à créer.
