# 9. Une étude reproductible de bout en bout

Scripts : `08_dictionnaire_variables.R`, `09_verification_reproductibilite.R`.
Fichiers : `config/dictionnaire_variables.yml`, dossier `reference/`.

---

## 9.1 Ce que veut dire « reproductible » ici

Une étude est reproductible si **quelqu'un d'autre**, sur **un autre
ordinateur**, peut refaire **toute** l'analyse et obtenir **les mêmes
résultats**. Dans ce projet, cela repose sur 6 éléments :

| Élément | Où | Rôle |
|---------|----|------|
| Une seule commande | `executer_pipeline.R` | Refait tout dans l'ordre, de la simulation aux résultats |
| Graine aléatoire fixe | `config.yml` (`graine: 2026`) | Les données simulées sont toujours les mêmes |
| Paramètres hors du code | `config.yml` | Rien n'est « caché » dans un script |
| Dictionnaire des variables | `dictionnaire_variables.yml` | Chaque colonne est définie et contrôlée |
| Traçabilité | `output/tracabilite/` | Empreintes, versions de R et des packages, commit Git |
| Comparaison à une référence | `reference/` + script 09 | Preuve que les résultats n'ont pas changé |

## 9.2 La chaîne complète, de la simulation aux résultats

```
config.yml ──► 01 simulation ──► data/raw/        (fichiers bruts fictifs)
                                     │
                                     ▼
               02 contrôle qualité ──► data/processed/  (portions validées)
                                     │                 output/qc/
                                     ▼
       03 POD/dPOD ─ 04 LOD50/RLOD ─ 05 interlabo ─ 06 criblage ─ 07 surface
                                     │
                                     ▼
                              output/tables/  output/figures/
                                     │
                                     ▼
       08 dictionnaire : chaque fichier est-il conforme à sa description ?
                                     │
                                     ▼
       09 reproductibilité : les résultats sont-ils ceux de la référence ?
                                     │
                                     ▼
                            rapport/index.qmd  ──► rapport HTML
```

Chaque étape **relit sur le disque** ce dont elle a besoin. Aucune variable
ne passe en mémoire d'un script à l'autre : on peut donc relancer une étape
seule, et un auditeur peut vérifier chaque fichier intermédiaire.

---

## 9.3 Le dictionnaire des variables (script 08)

### Pourquoi

Un tableau de résultats sans définition des colonnes est inutilisable par
quelqu'un d'autre. « `pod_c_bas` », c'est quoi ? Quelle unité ? Quel
intervalle ? En recherche clinique, c'est l'équivalent des spécifications
de données ; en pharmaceutique, c'est une exigence de documentation.

### Le format

`config/dictionnaire_variables.yml` décrit **16 fichiers** et
**124 variables**. Pour chaque variable :

```yaml
- {nom: pod_candidate, type: numerique, unite: "proportion",
   min: 0, max: 1, description: "POD candidate = x/n"}
```

- `type` : texte, numerique, entier, logique ou date ;
- `unite` : UFC par portion, RFU, °C, h, proportion… ;
- `valeurs` : liste des valeurs permises (par exemple `[candidate, reference]`) ;
- `min`, `max` : bornes ;
- `description` : définition en français.

**Piège du YAML** (rencontré pendant la construction du projet) : en YAML,
`n`, `y`, `no`, `yes`, `on`, `off` sont lus comme VRAI / FAUX. Une variable
qui s'appelle `n` doit être écrite entre guillemets : `nom: "n"`.

### Ce que vérifie le script 08

Pour chaque fichier :

1. **aucune colonne non documentée** (une colonne ajoutée dans un script
   sans mise à jour du dictionnaire est repérée) ;
2. **aucune colonne documentée absente** ;
3. **type** conforme ;
4. **valeurs permises** et **bornes** respectées (sauf pour les fichiers
   bruts, qui contiennent volontairement des erreurs traitées au script 02).

Résultat : 288 contrôles, tous conformes. **Si un seul contrôle échoue, le
pipeline s'arrête** : on ne publie pas un résultat dont la structure n'est
pas celle qui est documentée.

### La restitution des variables

`output/dictionnaire/resume_variables.csv` donne, pour **chaque variable de
chaque fichier** :

- variables numériques : nombre de valeurs, manquants, minimum, médiane,
  moyenne, maximum ;
- variables texte ou logiques : nombre de valeurs, manquants, nombre de
  modalités, effectifs des 5 modalités les plus fréquentes.

C'est le premier tableau à regarder quand on reçoit un jeu de données.
Exemple : pour les fichiers bruts de l'instrument, l'identifiant
`MAT-ACI-0007` apparaît 2 fois : c'est le doublon injecté, que le contrôle
qualité a bien exclu.

Le rapport affiche le bilan des contrôles, le dictionnaire complet (encadré
dépliable) et la restitution des variables des données validées.

### Exercice

Ajoute une colonne `commentaire` dans `pod_dpod_etude_matrice.csv` (script
03) sans toucher au dictionnaire. Relance le pipeline : le script 08 doit
s'arrêter. Documente la colonne dans le YAML, relance : tout redevient
conforme.

---

## 9.4 La vérification de reproductibilité (script 09)

### Le principe

Le dossier `reference/` contient une copie des résultats d'une exécution
de **référence** (faite sous Linux, R 4.3.3 ; voir `reference/LISEZMOI.md`).
À chaque exécution, le script 09 compare **23 fichiers** à cette référence :

- les 8 fichiers bruts simulés ;
- les données validées ;
- les 11 tables de résultats ;
- le registre et le bilan du contrôle qualité ;
- le résumé des variables.

### Comparer le contenu, pas l'empreinte

On compare **valeur par valeur**, pas les empreintes SHA-256 :

- texte et logique : égalité stricte ;
- nombres : écart relatif ≤ 10⁻⁶ (réglable dans `config.yml`,
  `reproductibilite: tolerance_relative`).

Pourquoi ? Une empreinte change pour une différence invisible (fin de
ligne, dernier chiffre d'un arrondi d'affichage). La comparaison des
valeurs répond à la vraie question : **les résultats sont-ils les
mêmes ?**

### Les statuts

| Statut | Signification |
|--------|---------------|
| `identique` | Toutes les valeurs sont exactement égales |
| `identique à la tolérance près` | Écart numérique minuscule (≤ 10⁻⁶), sans conséquence |
| `DIFFÉRENT` | Écart réel, à examiner |
| `ABSENT DE LA RÉFÉRENCE` | Nouveau fichier, pas encore dans la référence |

Une différence **n'arrête pas** le pipeline : elle est écrite dans le
journal, dans `output/tracabilite/verification_reproductibilite.csv` et
dans le rapport. Elle peut venir d'une autre version d'un package (par
exemple l'optimiseur de `lme4`) : il faut alors regarder quel fichier
diffère et de combien.

### À faire chez toi (sous Windows)

1. Lance `source("executer_pipeline.R")`.
2. Regarde la ligne `[09_reproductibilite]`.
3. Si tout est `identique` : ton exécution sous Windows (R 4.5) redonne
   exactement la référence faite sous Linux (R 4.3). C'est une **preuve de
   reproductibilité entre systèmes**, que tu peux citer en entretien.
4. S'il y a des `DIFFÉRENT`, ouvre
   `output/tracabilite/verification_reproductibilite.csv` et envoie-moi le
   contenu : on regardera ensemble d'où vient l'écart.

### Refaire la référence (volontairement)

Si tu changes un paramètre de `config.yml` (graine, niveaux, seuil…), les
résultats changent : c'est normal. Pour enregistrer la nouvelle référence :

1. supprime le dossier `reference/` ;
2. relance le pipeline : le script 09 recrée la référence ;
3. versionne-la avec Git, avec un message clair :
   `git commit -m "Nouvelle référence : seuil de positivité à 800 RFU"`.

**Ne modifie jamais la référence à la main** : elle perdrait toute valeur
de preuve.

---

## 9.5 Ce qui n'est PAS garanti (honnêteté)

- **Versions des packages non figées.** Le projet enregistre les versions
  utilisées, mais ne les impose pas. Un outil comme `renv` pourrait les
  figer ; je ne l'ai pas utilisé, car un fichier de versions créé sous Linux
  avec R 4.3 aurait obligé Windows à recompiler d'anciennes versions (et
  donc à installer Rtools). C'est un choix à expliquer, pas un oubli.
- **Le rapport HTML** n'est pas comparé (il contient la date du jour).
- **GitHub Actions** utilisera des versions récentes des packages : si un
  fichier y est signalé `DIFFÉRENT`, ce sera visible dans le rapport en
  ligne. C'est voulu : la vérification sert justement à le montrer.
