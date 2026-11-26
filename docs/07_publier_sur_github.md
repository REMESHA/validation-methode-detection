# 7. Publier le projet sur GitHub

Tu l'as déjà fait pour `observatoire-prix-porc` : la démarche est la même.
Compte GitHub : `REMESHA`.

## 7.1 Avant de publier

1. Lance tout en local et vérifie qu'il n'y a pas d'erreur :
   ```r
   source("executer_pipeline.R")
   ```
   ```bash
   Rscript tests/lancer_tests.R
   quarto render rapport/index.qmd
   ```
2. Ouvre `rapport/index.html` et relis-le en entier.
3. Relis le `README.md` : c'est la première chose que verra un recruteur.

## 7.2 Créer le dépôt sur GitHub

1. Sur github.com : bouton **New repository**.
2. Nom : `validation-methode-detection`.
3. **Public**.
4. Ne coche **rien** (pas de README, pas de .gitignore, pas de licence : ils
   sont déjà dans le dossier).
5. **Create repository**.

## 7.3 Activer GitHub Pages (à faire AVANT le premier envoi)

Dans le dépôt : **Settings** → **Pages** → *Build and deployment* →
**Source : GitHub Actions**.

Si tu oublies cette étape, la dernière étape du workflow échouera. Ce n'est
pas grave : active Pages, puis relance le workflow (onglet **Actions** →
*pipeline* → **Re-run all jobs**).

## 7.4 Envoyer le code

Dans un terminal, depuis le dossier du projet :

```bash
git init
git add .
git commit -m "Projet de validation statistique d'une méthode de détection (données simulées)"
git branch -M main
git remote add origin https://github.com/REMESHA/validation-methode-detection.git
git push -u origin main
```

Ce qui est envoyé : le code, la configuration, le dictionnaire, les données
brutes simulées, les sorties (`output/`), le dossier **`reference/`** (il
permet à GitHub Actions de vérifier la reproductibilité), le guide. Ce qui n'est **pas** envoyé (voir
`.gitignore`) : le rapport HTML, qui est reconstruit par GitHub Actions.

## 7.5 Suivre le workflow

Onglet **Actions** : le workflow *pipeline* démarre tout seul. Il dure
quelques minutes (l'installation des packages est la partie la plus longue).

- **Coche verte** : tout a marché. Le rapport est en ligne à
  `https://remesha.github.io/validation-methode-detection/`.
- **Croix rouge** : clique dessus, puis sur l'étape en rouge pour lire le
  message d'erreur.

### Erreurs possibles et solutions

| Étape en échec | Cause probable | Solution |
|----------------|---------------|----------|
| *Installer les packages R* | Package indisponible ou conflit | Relancer (souvent un problème réseau) ; sinon lire le nom du package dans le message |
| *Exécuter le pipeline* | Erreur dans un script | Reproduire en local, corriger, renvoyer |
| *Lancer les tests* | Un test échoue | Lire quel test et pourquoi |
| *Publier sur GitHub Pages* | Pages non activé | Voir 7.3 |
| Message sur une version d'action (`@v7`, `@v5`…) | Version d'action non disponible | Remplacer par la version utilisée dans `observatoire-prix-porc`, qui marche déjà |

> Je n'ai pas pu exécuter le workflow GitHub Actions moi-même : le code R, les
> tests et le rapport ont été vérifiés en local, mais pas le fichier
> `pipeline.yml` sur les serveurs de GitHub. Si une étape bloque, compare avec
> le workflow de ton dépôt `observatoire-prix-porc`.

## 7.6 Les sorties téléchargeables

Dans **Actions** → la dernière exécution → en bas, **Artifacts** →
`sorties-pipeline` : un zip avec `output/` et `data/processed/`. C'est une
preuve d'exécution, avec le manifeste SHA-256 et le commit Git.

## 7.7 Après la publication

1. Ajoute le lien du dépôt et du rapport dans ton CV et sur LinkedIn.
2. Dans la page du dépôt, renseigne la description (roue dentée à droite de
   *About*) : « Validation statistique d'une méthode de détection (POD, dPOD,
   LOD50, plans d'expériences, traçabilité) — données simulées ».
3. Ajoute le lien du rapport dans le champ *Website* du même encadré.

## 7.8 Modifier le projet plus tard

```bash
git add .
git commit -m "Ajout de l'étude de robustesse"
git push
```

Le workflow repart automatiquement et met à jour le rapport en ligne.
