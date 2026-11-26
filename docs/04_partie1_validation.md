# 4. Partie 1 — Valider la méthode : POD, dPOD, LOD50, RLOD

Scripts : `01`, `03`, `04`, `05`. Fonctions : `R/fonctions_pod.R`,
`R/fonctions_lod.R`, `R/fonctions_simulation.R`.

---

## 4.1 Comment les données sont simulées (script 01)

### L'idée physique

Quand on inocule une portion à « 1,2 UFC en moyenne », chaque portion ne
reçoit pas exactement 1,2 bactérie : certaines en reçoivent 0, d'autres 1, 2,
3… Ce nombre suit une **loi de Poisson** de moyenne λ = 1,2. Avec λ = 1,2, la
probabilité de n'avoir **aucune** bactérie est exp(−1,2) ≈ 0,30 : 30 % des
portions sont vides, quelle que soit la qualité de la méthode !

Ensuite, chaque bactérie présente est détectée avec une probabilité *r*
(l'« efficacité » de la méthode : récupération sur la surface, croissance,
lecture du signal…).

### La formule qui en découle

Le nombre de bactéries **détectées** suit une loi de Poisson de moyenne
*r* × λ (propriété d'« amincissement » de la loi de Poisson). La portion est
négative si aucune n'est détectée :

```
P(négatif) = exp(−r λ)      donc      POD(λ) = 1 − exp(−r λ)
```

Dans `config.yml` : *r* = 0,60 pour la candidate et 0,50 pour la référence,
multiplié par 0,85 sur plastique (moins bonne récupération).

### Dans le code (`simuler_detection()`)

```r
cellules  <- rpois(length(lambda), lambda)        # étape 1 : Poisson
detectees <- rbinom(length(lambda), size = cellules, prob = r)  # étape 2
detectees > 0                                     # étape 3 : détecté ?
```

Le test `test-lod.R` vérifie sur 50 000 portions que la proportion observée
correspond bien à 1 − exp(−r λ).

### Le signal de la méthode candidate

La candidate ne donne pas directement « positif » : elle donne un **signal**
en RFU (unités de fluorescence). On le simule par une loi log-normale : environ
10 000 RFU si la cible est détectée, environ 200 RFU sinon (bruit de fond). Une
portion est positive si le signal ≥ 1 000 RFU (seuil dans `config.yml`). Le
bruit de fond dépasse parfois le seuil : cela crée de rares **faux positifs**,
comme dans la réalité.

---

## 4.2 La POD et son intervalle de confiance (script 03)

### Définition

POD = nombre de positifs / nombre de portions. Exemple : 12 positifs sur 20
→ POD = 0,60.

### Pourquoi un intervalle de confiance ?

Avec 20 portions, 0,60 est une estimation très imprécise. L'AOAC demande un
**intervalle de confiance à 95 %**. On n'utilise pas la formule « classique »
p ± 1,96 √(p(1−p)/n), car elle marche mal avec peu de portions et des
proportions proches de 0 ou 1 (elle peut donner des bornes négatives ou
au-dessus de 1, ou un intervalle de largeur nulle si 0/20). On utilise
l'**intervalle de Wilson** :

```
bas  = [x + 1,9207 − 1,96 × √( x(n−x)/n + 0,9604 )] / (n + 3,8415)
haut = [x + 1,9207 + 1,96 × √( x(n−x)/n + 0,9604 )] / (n + 3,8415)
```

avec 1,96² = 3,8415 ; 1,96²/2 = 1,9207 ; 1,96²/4 = 0,9604.

### Calcul à la main (fais-le une fois !)

x = 12, n = 20 :

- centre = 12 + 1,9207 = 13,9207
- marge = 1,96 × √(12 × 8 / 20 + 0,9604) = 1,96 × √5,7604 = 1,96 × 2,4001 = 4,7042
- bas = (13,9207 − 4,7042) / 23,8415 = **0,387**
- haut = (13,9207 + 4,7042) / 23,8415 = **0,781**

Vérifie dans R : `pod_ic(12, 20)` et `prop.test(12, 20, correct = FALSE)$conf.int`.
Les deux donnent le même résultat : c'est exactement ce que vérifie le test
automatique `test-pod.R`.

Cas particuliers : 0/n donne [0 ; 3,8415/(n + 3,8415)] et n/n donne
[n/(n + 3,8415) ; 1]. Avec 0 positif sur 5 non inoculés, la borne haute vaut
0,43 : **5 portions ne suffisent pas** à montrer qu'il n'y a pas de faux
positifs. C'est pour cela que l'étude interlaboratoires (144 portions non
inoculées) est plus informative sur ce point.

---

## 4.3 La dPOD (script 03)

dPOD = POD candidate − POD référence. Si l'IC à 95 % de la dPOD contient 0,
pas de différence significative.

Pour une étude **non appariée** (portions différentes pour chaque méthode),
l'AOAC combine les distances entre chaque POD et ses bornes :

```
bas  = dPOD − √[ (POD_c − bas_c)² + (haut_r − POD_r)² ]
haut = dPOD + √[ (haut_c − POD_c)² + (POD_r − bas_r)² ]
```

Logique : la dPOD est la plus basse quand la candidate est au plus bas **et**
la référence au plus haut, d'où le mélange des bornes. (C'est la méthode de
Newcombe pour une différence de proportions.)

### Exemple du projet (inox, niveau bas)

Candidate 6/18 = 0,333 [0,163 ; 0,563] ; référence 12/20 = 0,600 [0,387 ; 0,781].

- dPOD = 0,333 − 0,600 = −0,267
- bas = −0,267 − √(0,170² + 0,181²) = −0,267 − 0,249 = **−0,516**
- haut = −0,267 + √(0,229² + 0,213²) = −0,267 + 0,313 = **+0,046**

L'intervalle contient 0 de justesse : **pas de différence significative**,
mais le résultat mérite attention. En pratique, on regarderait aussi la
deuxième matrice (sur plastique, la candidate fait mieux) et l'étude
interlaboratoires.

Pour une étude **appariée** (même portion pour les deux méthodes), la
fonction `dpod_apparie()` calcule la moyenne des différences (−1, 0, +1) et
utilise une loi de Student. Elle n'est pas utilisée dans le pipeline (les
surfaces sont en non apparié) mais elle est testée.

### Pourquoi 18 et pas 20 portions ?

Le contrôle qualité a exclu deux portions de ce niveau (signal manquant,
signal négatif). C'est volontaire : ça montre qu'une donnée douteuse n'est
pas « réparée » en douce. Dans un vrai dossier, on documenterait la
décision.

---

## 4.4 La LOD50 (script 04)

### Définition

La **LOD50** est le niveau de contamination auquel la méthode détecte une
fois sur deux (POD = 0,5). Plus elle est basse, plus la méthode est sensible.

### Le modèle statistique

On part de POD(λ) = 1 − exp(−r λ). On transforme :

```
1 − POD = exp(−r λ)
−log(1 − POD) = r λ
log(−log(1 − POD)) = log(r) + log(λ)
```

La fonction log(−log(1 − p)) s'appelle **log-log complémentaire**
(*cloglog*). On a donc un **modèle linéaire généralisé** binomial, lien
cloglog, où log(λ) entre avec un coefficient **fixé à 1** (on dit que c'est un
*offset*). Le seul paramètre à estimer est log(r).

```r
glm(positif ~ 1, offset = log(niveau_cible),
    family = binomial(link = "cloglog"), data = donnees)
```

Puis : POD = 0,5 ⇔ r λ = log(2) ⇔ **LOD50 = log(2) / r**.

Exemple : r = 0,6 → LOD50 = 0,693 / 0,6 = 1,16 UFC par portion.

### L'intervalle de confiance

On calcule l'IC de log(r) par **profil de vraisemblance** (`confint()`), puis
on le transforme. Attention à l'inversion : quand r augmente, la LOD50
diminue. Donc la borne **basse** de la LOD50 vient de la borne **haute** de r.
C'est fait dans `ajuster_lod50()`.

### Vérifier l'hypothèse du modèle

Le modèle « un coup suffit » impose une pente de 1 sur l'échelle log. On le
compare à un modèle où la pente est libre, avec un **test du rapport de
vraisemblance** (`tester_pente_un()`). Une p-valeur élevée = les données ne
contredisent pas l'hypothèse. Dans le projet : pentes libres 1,11 et 0,98,
p = 0,59 et 0,90 → hypothèse acceptable.

### Résultats et lecture honnête

LOD50 candidate = 1,50 [1,10 ; 2,11] (vraie valeur : 1,16).
LOD50 référence = 1,42 [1,05 ; 1,98] (vraie valeur : 1,39).

Les IC contiennent les vraies valeurs. Mais l'estimation dit que la candidate
serait **un peu moins** sensible, alors que dans la simulation elle l'est
**un peu plus**. Leçon : avec 100 portions par méthode, on ne peut pas
départager deux méthodes aussi proches. C'est un excellent point à expliquer
en entretien : il montre que tu sais lire un IC, pas seulement une
estimation.

---

## 4.5 Le RLOD (script 04)

**RLOD** = LOD50 candidate / LOD50 référence. RLOD < 1 : la candidate détecte
des niveaux plus faibles. On l'estime dans **un seul modèle** avec les deux
méthodes :

```
cloglog(POD) = log(r_ref) + δ × [méthode = candidate] + log(λ)
```

δ = log(r_cand / r_ref), donc RLOD = r_ref / r_cand = exp(−δ).

Résultat : RLOD = 1,06 [0,67 ; 1,67] (vrai : 0,83). L'IC contient 1 : pas de
différence démontrée.

> L'ISO 16140-2 fournit sa propre procédure et son propre outil de calcul du
> RLOD. Ce projet utilise un modèle de Poisson proche dans l'esprit, mais **ce
> n'est pas le calcul officiel**. Dis-le si on te pose la question.

---

## 4.6 L'étude interlaboratoires (script 05)

### Pourquoi plusieurs laboratoires ?

Un laboratoire n'est pas l'autre : opérateurs, équipements, eau, milieux…
L'étude collaborative mesure si la méthode donne des résultats comparables
**partout**. Dans la simulation, chaque laboratoire a sa propre efficacité :
r_labo = r × exp(u), avec u tiré d'une loi normale d'écart-type 0,30.

### LPOD et dLPOD : la procédure AOAC en 6 étapes

Fonctions : `R/fonctions_lpod.R`. On note L le nombre de laboratoires
(12), R le nombre de portions par laboratoire (12) et N = L × R (144).

1. **Analyse de variance** des résultats 0/1, comme pour des données
   quantitatives, avec un facteur « laboratoire » :
   - carré moyen intra-laboratoire → **s~r~²** (répétabilité) ;
   - **s~L~²** = (carré moyen inter − carré moyen intra) / R, ramené à 0 s'il
     est négatif (part due aux laboratoires).
2. **s~R~² = s~r~² + s~L~²** (reproductibilité).
3. **s(POD)** = écart-type des 12 POD de laboratoire.
4. **Degrés de liberté** par une approximation de Satterthwaite :

   ```
   ddl = (sL²/L + sr²/N)² / [ (sL²/L)² / (L − 1) + (sr²/N)² / (N − L) ]
   ```

   Idée : la variance de la LPOD vaut environ sL²/L + sr²/N, somme de deux
   variances estimées avec L − 1 et N − L degrés de liberté. Satterthwaite
   donne le nombre de degrés de liberté « équivalent » de cette somme. Cas
   limites (vérifiés par les tests) : sans variabilité intra-labo,
   ddl = L − 1 ; sans variabilité entre labos, ddl = N − L.
5. **IC de la LPOD** :
   - si 0,15 ≤ LPOD ≤ 0,85 : LPOD ± t(0,975 ; ddl) × s(POD) / √L, ramené
     dans [0 ; 1] ;
   - sinon : intervalle de **Wilson** sur x positifs parmi N.
6. **dLPOD** = LPOD candidate − LPOD référence, IC par la même combinaison
   des bornes que la dPOD.

> **Réserve importante.** Les étapes 1 à 3, 5 et 6 sont conformes au texte
> de l'annexe AOAC que j'ai pu lire. La formule de l'étape 4 était
> **illisible** dans les copies disponibles : la forme ci-dessus est la
> forme de Satterthwaite cohérente avec les éléments lisibles (s~L~, s~r~, L,
> N). Il faut la vérifier dans le PDF original avant tout usage réel, et le
> dire si on te pose la question.

Résultat au niveau bas : LPOD candidate = 0,51 [0,38 ; 0,63] avec
s~r~ = 0,48, s~L~ = 0,16 et 30,4 degrés de liberté ; dLPOD = 0,00
[−0,16 ; 0,16] : pas de différence.

### Le modèle mixte (lme4)

```r
glmer(positif ~ methode + offset(log(niveau_cible)) + (1 | laboratoire),
      family = binomial(link = "cloglog"), data = inoc)
```

- `methode` : effet **fixe** (ce qu'on veut comparer) ;
- `(1 | laboratoire)` : effet **aléatoire** : chaque laboratoire a son propre
  décalage, tiré d'une loi normale. Le modèle estime l'**écart-type** de ces
  décalages ;
- résultat : 0,31 estimé pour 0,30 dans la simulation.

Le modèle est écrit de **deux façons équivalentes** dans le script 05 :

- `positif ~ 0 + methode + ...` : un coefficient log(r) par méthode, d'où
  directement les deux LOD50 ;
- `positif ~ methode + ...` : la référence sert de base, le coefficient
  `methodecandidate` vaut δ = log(r~cand~ / r~ref~), d'où RLOD = exp(−δ).

Les **intervalles de confiance** sont obtenus par **profil de
vraisemblance** (`confint(modele, method = "profile")`), y compris pour
l'écart-type entre laboratoires (paramètre `.sig01`).

| Paramètre | Estimation [IC 95 %] | Vraie valeur |
|-----------|---------------------|--------------|
| LOD50 référence | 1,19 [0,89 ; 1,58] | 1,39 |
| LOD50 candidate | 1,11 [0,83 ; 1,48] | 1,16 |
| RLOD | 0,94 [0,70 ; 1,26] | 0,83 |
| Écart-type entre laboratoires | 0,31 [0,10 ; 0,59] | 0,30 |

Les quatre vraies valeurs sont dans leur intervalle.

**Interprétation précise** : ces LOD50 sont celles d'un laboratoire
**médian** (effet laboratoire u = 0). Ce n'est pas la même chose que la LOD50
« moyenne sur tous les laboratoires » : comme la relation entre u et la POD
n'est pas linéaire, la moyenne des POD des laboratoires n'est pas la POD du
laboratoire médian.

Pourquoi un effet aléatoire et pas un effet fixe par laboratoire ? Parce qu'on
ne s'intéresse pas à LAB03 en particulier : les 12 laboratoires représentent
« les laboratoires en général ». C'est la même logique que pour les animaux ou
les patients dans tes analyses lme4 précédentes.

---

## 4.7 Exercices

1. Dans `config.yml`, passe le niveau bas de 1,2 à 0,3 UFC. Relance le
   pipeline. Le niveau est-il encore « fractionnaire » (25-75 %) ? Que
   deviennent les IC des dPOD ?
2. Passe les réplicats du niveau bas de 20 à 60. Combien vaut maintenant la
   demi-largeur de l'IC de la dPOD ? (Indice : elle diminue à peu près comme
   1/√n.)
3. Calcule la **LOD95** (niveau où POD = 0,95) : LOD95 = log(20) / r.
   Ajoute-la au tableau du script 04.
4. Change la graine (`graine: 2027`) et relance. Les conclusions changent-elles ?
   Pourquoi est-ce normal ?
5. Seuil de positivité : passe-le de 1 000 à 400 RFU. Que deviennent les faux
   positifs ? (Regarde `output/tables/faux_positifs_interlabo.csv`.)
