# 1. Le contexte métier

## 1.1 Le problème que l'on résout

Les industries pharmaceutique, agroalimentaire et cosmétique doivent
surveiller les **contaminants microbiens** de leur environnement de production :
surfaces (inox, plastique, joints…) et air des salles. La méthode classique
est la **culture** : on prélève, on met en culture sur un milieu nutritif, on
attend plusieurs jours, on regarde s'il y a des colonies.

Des **méthodes rapides** existent : elles détectent un signal (fluorescence,
luminescence, changement de couleur…) produit par les bactéries, souvent dans
une **chambre de mesure optique**. Elles donnent un résultat plus vite, mais
avant de les utiliser à la place de la culture, il faut **prouver** qu'elles
détectent au moins aussi bien. C'est la **validation de méthode**.

Le rôle du biostatisticien dans ce cadre :

- **concevoir** les études (combien de portions, à quels niveaux de
  contamination, dans combien de laboratoires) ;
- **analyser** les résultats avec les indicateurs attendus par les
  référentiels ;
- **optimiser** les réglages de la méthode (plans d'expériences) ;
- **organiser et tracer** les données, pour qu'un auditeur puisse tout
  vérifier.

C'est exactement ce que décrit l'offre d'Efor : analyse des données de
performance, plans d'expériences sur les paramètres physiques,
automatisation, préparation d'une certification AOAC.

## 1.2 Les référentiels

### AOAC INTERNATIONAL

Organisation internationale qui publie des méthodes d'analyse et des
lignes directrices de validation. Deux programmes reviennent souvent :

- **OMA** (*Official Methods of Analysis*) : le niveau le plus exigeant ; il
  demande une **étude collaborative** (plusieurs laboratoires) ;
- **PTM** (*Performance Tested Methods*) : certification de méthodes
  commerciales (souvent des kits), gérée par l'AOAC Research Institute.

Le document de référence pour la microbiologie est l'**Appendix J** :
*AOAC INTERNATIONAL Methods Committee Guidelines for Validation of
Microbiological Methods for Food and Environmental Surfaces* (version 2012).
Il couvre aussi les **surfaces de l'environnement** (inox, plastique,
céramique, caoutchouc, béton, filtres à air…).

### ISO 16140-2

Norme internationale *Microbiologie de la chaîne alimentaire — Validation des
méthodes — Partie 2 : protocole pour la validation de méthodes alternatives
(commerciales) par rapport à une méthode de référence* (2016, amendement
en 2024). Elle est utilisée en Europe, notamment par les organismes de
certification comme AFNOR (marque NF Validation), MicroVal ou NordVal. Elle
introduit notamment le **RLOD** (niveau de détection relatif).

> Je n'ai **pas** reproduit ces référentiels dans le projet. Le projet
> s'**inspire** de leur logique. Pour un vrai dossier de certification, il
> faut suivre le texte officiel complet.

## 1.3 Le vocabulaire indispensable

| Terme | Définition simple |
|-------|------------------|
| **Méthode candidate** (ou alternative) | La nouvelle méthode que l'on veut valider |
| **Méthode de référence** | La méthode reconnue (souvent la culture) à laquelle on la compare |
| **Méthode qualitative** | Donne un résultat présence / absence (positif / négatif) |
| **Méthode quantitative** | Donne une quantité (nombre de bactéries) |
| **Matrice** | Le support analysé : ici, une surface en inox ou en plastique |
| **Portion** (*test portion*) | Un échantillon individuel analysé |
| **Inoculation** | Ajout volontaire d'une quantité connue de bactéries |
| **UFC** | Unité formant colonie : une bactérie (ou un amas) capable de donner une colonie |
| **Niveau d'inoculation** | Nombre moyen d'UFC par portion |
| **Résultat fractionnaire** | Niveau où une partie seulement des portions sont positives (idéalement 25 à 75 %) |
| **POD** | Probabilité de détection = positifs / portions testées |
| **dPOD** | Différence de POD entre deux méthodes |
| **LPOD** | POD calculée sur tous les laboratoires d'une étude collaborative |
| **LOD50** | Niveau de contamination pour lequel la POD vaut 50 % |
| **RLOD** | LOD50 de la candidate / LOD50 de la référence (ISO 16140-2) |
| **Inclusivité** | Capacité à détecter toutes les souches **cibles** |
| **Exclusivité** | Capacité à ne **pas** réagir aux souches **non cibles** |
| **Faux positif** | Résultat positif sur une portion non contaminée |
| **Robustesse** | Stabilité du résultat face à de petites variations du protocole |
| **Étude appariée** | La même portion est analysée par les deux méthodes |
| **Étude non appariée** | Portions différentes pour chaque méthode (fréquent pour les surfaces : un écouvillon ne sert qu'une fois) |
| **NPP** (MPN en anglais) | Nombre le plus probable : méthode statistique pour estimer le vrai niveau d'inoculation |

## 1.4 Les études prévues par l'AOAC (méthodes qualitatives)

Ce que j'ai pu vérifier dans l'Appendix J :

1. **Inclusivité / exclusivité** : panels de souches cibles et non cibles.
2. **Étude de matrice** (un seul laboratoire) : pour chaque matrice, au moins
   trois niveaux : **5 portions non inoculées, 20 portions à un niveau
   fractionnaire** (25 à 75 % de positifs, idéalement autour de 50 %) **et
   5 portions à un niveau haut** (POD proche de 1). On calcule POD et dPOD
   avec leurs intervalles de confiance à 95 %.
3. **Robustesse** (PTM seulement) : un **plan factoriel de criblage** avec de
   petites variations des paramètres.
4. **Étude collaborative** (OMA) : au moins 12 laboratoires par matrice, avec
   au moins 10 jeux de données valides, et 12 portions par niveau dans chaque
   laboratoire. On calcule LPOD et dLPOD selon une annexe de calcul en
   6 étapes (voir chapitre 4).

**Règle de décision** : si l'intervalle de confiance à 95 % d'une dPOD
**ne contient pas 0**, la différence entre les deux méthodes est
statistiquement significative au seuil de 5 %.

## 1.5 Ce que fait le projet, en face de chaque étude

| Étude AOAC | Dans le projet | Script |
|-----------|-----------------|--------|
| Étude de matrice (5/20/5) | Oui, 2 matrices (inox, plastique) | `03_etude_matrice_pod.R` |
| LOD50 | Oui, étude dédiée à 5 niveaux | `04_niveau_detection_lod50.R` |
| RLOD (ISO 16140-2) | Oui, par un modèle de Poisson (pas l'outil officiel ISO) | `04_niveau_detection_lod50.R` |
| Étude collaborative | Oui, 12 labos simulés, LPOD/dLPOD selon la procédure AOAC en 6 étapes (réserve sur la formule des degrés de liberté) | `05_etude_interlaboratoires.R` |
| Robustesse | Non (voir exercices du chapitre 5) | — |
| Inclusivité / exclusivité | Non | — |
| Optimisation des paramètres physiques | Oui (plans d'expériences) | `06_…`, `07_…` |
| Préparation des données / traçabilité | Oui | `02_controle_qualite.R` |
| Dictionnaire et restitution des variables | Oui, contrôlé automatiquement | `08_dictionnaire_variables.R` |
| Reproductibilité de bout en bout | Oui, comparaison à une exécution de référence | `09_verification_reproductibilite.R` |

## 1.6 Pour aller plus loin (lectures)

- AOAC INTERNATIONAL, *Appendix J: Guidelines for Validation of
  Microbiological Methods for Food and Environmental Surfaces*, Official
  Methods of Analysis, 2012 (librement consultable en ligne).
- Wehling P. et al., *Probability of Detection (POD) as a statistical model
  for the validation of qualitative methods*, Journal of AOAC International,
  2011 : l'article qui a introduit le modèle POD.
- ISO 16140-2:2016 et son amendement 1:2024 (payants ; les résumés des
  rapports NF Validation publiés par AFNOR montrent comment les résultats
  sont présentés).
- Uhlig S., Gowik P. et al. (2018), *Efficient estimation of the limit of
  detection and the relative limit of detection along with their
  reproducibility in the validation of qualitative microbiological methods
  by means of generalized linear mixed models* : article en accès libre qui
  relie LOD, RLOD et modèles mixtes (proche de ce que fait le script 05).
