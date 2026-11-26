# 5. Partie 2 — Plans d'expériences : trouver les bons réglages

Scripts : `06_plan_criblage.R`, `07_plan_composite_surface.R`.
Fonctions : `R/fonctions_plans.R`.

---

## 5.1 Le problème

La méthode candidate a des **paramètres physiques** : température
d'incubation, durée d'enrichissement, concentration du substrat fluorescent,
volume d'échantillon, gain du photodétecteur. On veut le meilleur **rapport
signal / bruit** (S/B) : plus il est grand, mieux on sépare les portions
contaminées du bruit de fond.

### Pourquoi pas « un facteur à la fois » ?

La méthode intuitive : faire varier la température en gardant tout le reste
fixe, garder la meilleure, puis passer à la durée… Elle a deux défauts :

1. elle **rate les interactions** : si la meilleure température dépend de
   la durée, on ne le voit pas ;
2. elle coûte **plus d'essais** pour une précision moindre.

Un **plan d'expériences** fait varier plusieurs facteurs **en même temps**,
de façon organisée, pour estimer tous les effets avec peu d'essais.

### Le banc d'essai simulé

Dans `fonctions_plans.R`, la fonction `reponse_vraie()` contient la « vraie »
loi, que l'analyste est censé ignorer :

```
S/B = 10 + 1,2 A + 1,5 B + 0,8 C + 0,1 D + 0,2 E + 0,6 AB − 1,4 A² − 1,1 B²
```

(A à E en unités codées, voir ci-dessous.) `mesurer_sb()` y ajoute un bruit
de mesure (écart-type 0,6). On s'en sert à la fin pour vérifier que les plans
retrouvent la vérité.

---

## 5.2 Les unités codées

Chaque facteur est ramené à une échelle commune : **−1 = niveau bas**,
**+1 = niveau haut**, **0 = centre**. Exemple pour la température
(30 et 37 °C) : centre = 33,5 °C, demi-étendue = 3,5 °C, donc
code = (T − 33,5) / 3,5. Ainsi 37 °C → +1 ; 30 °C → −1.

Pourquoi ? Pour comparer des effets de facteurs qui n'ont pas la même unité
(°C, heures, mM…). Fonctions `coder()` et `decoder()`.

**Effet d'un facteur** = variation moyenne de la réponse quand on passe de −1
à +1 = **2 × coefficient** de la régression en unités codées.

---

## 5.3 Étape 1 : le criblage (script 06)

### Le plan factoriel complet serait trop cher

5 facteurs à 2 niveaux : 2⁵ = 32 essais. Le **plan fractionnaire 2⁵⁻¹** n'en
utilise que **16**.

### Comment c'est possible ?

On construit un plan complet pour A, B, C, D (16 essais) et on fabrique la
colonne E à partir des autres : **E = ABCD** (le produit des 4 colonnes de −1
et +1). C'est le **générateur** ; `generators(plan)` l'affiche.

Le prix à payer : certains effets sont **confondus** (*aliasés*). Avec
E = ABCD, l'effet de A est confondu avec l'interaction BCDE, l'interaction AB
avec CDE, etc. On dit que le plan est de **résolution V** : les effets
principaux et les interactions entre 2 facteurs ne sont confondus qu'avec des
interactions de 3 facteurs ou plus, que l'on suppose négligeables. C'est un
très bon plan de criblage.

### Les 4 points au centre

Tous les facteurs à 0 (33,5 °C, 12 h…), répétés 4 fois. Ils servent à :

1. estimer l'**erreur de mesure** (4 répétitions du même réglage) ;
2. détecter une **courbure** : si la réponse au centre est différente de la
   moyenne des 16 essais factoriels, la relation n'est pas linéaire.

### Le code

```r
plan <- FrF2(nruns = 16, nfactors = 5, factor.names = niveaux,
             ncenter = 4, randomize = TRUE, seed = cfg$graine)
```

- `randomize = TRUE` : l'ordre des essais est tiré au hasard. **Indispensable
  au labo** : si on fait tous les essais à 37 °C le lundi et à 30 °C le
  mardi, on ne saura pas si l'effet vient de la température ou du jour ;
- `seed` : rend le tirage reproductible.

Puis la régression en unités codées :

```r
lm(sb ~ (A + B + C + D + E)^2 + centre, data = codes)
```

`(A + B + C + D + E)^2` = les 5 effets principaux + les 10 interactions de 2
facteurs. `centre` vaut 1 pour les points au centre : son coefficient mesure
la courbure. 20 essais − 17 paramètres = **3 degrés de liberté** pour
l'erreur, tous issus des répétitions au centre.

### Les résultats

| Terme | Effet | Lecture |
|-------|-------|---------|
| A (température) | 2,95 | fort, positif |
| B (durée) | 2,88 | fort, positif |
| centre (courbure) | 2,01 | significatif : la surface est courbée |
| C (substrat) | 1,89 | net, positif |
| A:B | 1,32 | interaction : l'effet de la température dépend de la durée |
| D, E et le reste | < 0,6 | non significatifs |

Comparaison avec la vérité (effet = 2 × coefficient vrai) : A = 2,4 ;
B = 3,0 ; C = 1,6 ; AB = 1,2 ; D = 0,2 ; E = 0,4. Le criblage a bien trié les
facteurs importants. L'effet de A paraît un peu fort : sur un plan à deux
niveaux, une partie de la courbure se mélange aux effets.

**Décision de l'analyste** (écrite dans le script 07) :

- A et B : à optimiser (effets forts + interaction + courbure) ;
- C : fixé au niveau haut (effet positif) ;
- D et E : fixés au niveau le plus pratique (pas d'effet net).

---

## 5.4 Étape 2 : la surface de réponse (script 07)

### Pourquoi un nouveau plan ?

Un plan à 2 niveaux ne peut estimer que des droites. Pour trouver un
**maximum**, il faut un modèle avec des termes au carré (A², B²), donc au
moins **3 niveaux** par facteur.

### Le plan composite centré (CCD)

Pour 2 facteurs, 13 essais :

- 4 points du **carré** (±1, ±1) ;
- 4 points **axiaux** (±1,414 ; 0) et (0 ; ±1,414) ;
- 5 points au **centre**.

La valeur 1,414 rend le plan **rotatable** : la précision de la prédiction
ne dépend que de la distance au centre. (Formule générale quand le carré est
un plan complet à k facteurs : α = (2^k)^(1/4) ; pour k = 2, α = √2.)

**Attention** : les points axiaux sortent du domaine du criblage (28,6 °C à
38,4 °C ; 3,5 h à 20,5 h). Au laboratoire, un réglage peut être impossible
(l'incubateur ne descend pas sous une température, le protocole impose une
durée minimale…). Le projet le gère **automatiquement** :

1. `config.yml` déclare des **limites physiques** (température 25–42 °C,
   durée 2–24 h) ;
2. avant de construire le plan, `choisir_alpha_ccd()` calcule les points
   axiaux et vérifie qu'ils sont dans ces limites ;
3. si oui : plan rotatable ; si non : points axiaux **sur les faces** du
   carré (α = 1, `alpha = "faces"`) ; si même le carré sort des limites : le
   script s'arrête avec un message ;
4. double sécurité : après construction, chaque essai réel est revérifié.

Le choix est écrit dans le journal et dans le rapport. Essaie : mets
`duree_enrichissement: {min: 4, max: 24}` dans `config.yml` et relance le
script 07. Le point axial à 3,5 h devient impossible et le plan bascule sur
les faces.

Le plan est fait en **2 blocs** (le carré, puis les points axiaux) : comme
s'ils étaient réalisés deux jours différents. Le modèle inclut un effet
`Block` pour absorber une éventuelle différence entre les jours.

### Le code

```r
plan <- ccd(~ x1 + x2, n0 = c(2, 3), alpha = "rotatable", randomize = TRUE,
            coding = list(x1 ~ (temperature - 33.5) / 3.5,
                          x2 ~ (duree_enrichissement - 12) / 6))
modele <- rsm(sb ~ Block + SO(x1, x2), data = plan)
summary(modele)
```

`SO(x1, x2)` (*second order*) = x1 + x2 + x1:x2 + x1² + x2².

### L'analyse canonique

`summary(modele)$canonical` donne :

- `xs` : le **point stationnaire** (où la pente est nulle) ;
- les **valeurs propres** : toutes négatives → **maximum** ; toutes positives
  → minimum ; signes mélangés → **point selle** (pas d'optimum unique).

### Résultats

| | Plan | Vérité (simulation) |
|---|---|---|
| Température optimale | 35,8 °C | 35,6 °C |
| Durée optimale | 18,3 h | 17,1 h |
| S/B à l'optimum | 11,6 | 11,5 |

Le plan retrouve l'optimum à moins de 0,2 °C et à 1,2 h près, avec
33 essais au total (20 + 13).

### Ce qu'on ferait ensuite au labo

1. **Essais de confirmation** : 3 à 5 essais au réglage optimal, pour
   vérifier que le S/B mesuré est dans l'intervalle prédit (le script calcule
   cet intervalle : `ic_prediction` dans `plan_composite.rds`).
2. **Robustesse** : de petites variations autour du réglage choisi
   (par exemple ±1 °C, ±1 h) avec un petit plan factoriel, pour vérifier que
   le résultat reste stable. C'est ce que l'AOAC appelle l'étude de
   robustesse (programme PTM).

---

## 5.5 Exercices

1. **Plan un facteur à la fois** : simule-le avec `mesurer_sb()` (fais varier
   A en gardant B = 0, puis B en gardant A à sa meilleure valeur). Combien
   d'essais te faut-il pour arriver aussi près de l'optimum ?
2. Passe le bruit (`ecart_type_bruit`) de 0,6 à 1,5. Le criblage trouve-t-il
   encore C ? Combien de points au centre faudrait-il ?
3. Force le plan sur les faces (limite minimale de durée à 4 h dans
   `config.yml`, voir 5.4). L'optimum trouvé change-t-il ? Pense à
   recréer la référence de reproductibilité ensuite (chapitre 9).
4. **Robustesse** : écris un script `08_robustesse.R` avec un plan 2³⁻¹
   (`FrF2(nruns = 4, nfactors = 3, ...)`) autour de l'optimum, avec des
   variations de ±1 °C, ±1 h et ±10 % de substrat, et 10 répétitions par
   essai. Les effets sont-ils négligeables ?
