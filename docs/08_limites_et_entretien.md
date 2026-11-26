# 8. Limites, ce que tu peux dire, et préparation à l'entretien

## 8.1 Les limites du PROJET

1. **Données simulées.** Elles suivent exactement les hypothèses des modèles
   (loi de Poisson, cellules détectées indépendamment). Les vraies données
   sont plus « sales » : amas de bactéries, cellules stressées qui poussent
   mal, effets de la flore annexe, matrices qui inhibent le signal…
2. **Niveau d'inoculation supposé connu.** En réalité, on l'estime (par la
   méthode NPP pour les aliments) et cette estimation a sa propre
   incertitude. L'AOAC précise que la NPP ne s'applique pas aux surfaces.
3. **Études absentes** : inclusivité / exclusivité (panels de souches),
   confirmation des résultats présomptifs, robustesse au sens AOAC, stabilité
   des réactifs d'un lot à l'autre.
4. **Calculs à vérifier ou différents des référentiels** : la formule des
   degrés de liberté de la LPOD (Satterthwaite) a été reconstruite à partir
   d'une copie partiellement illisible du texte AOAC ; le RLOD est estimé par
   un modèle de Poisson et non par l'outil officiel de l'ISO 16140-2.
5. **Pas un système validé.** Le pipeline illustre les principes de
   traçabilité, mais n'est pas un système informatisé validé (pas de gestion
   des accès, de signature électronique, d'audit trail au sens
   réglementaire).
6. **Le workflow GitHub Actions** n'a pas été testé sur les serveurs de GitHub
   avant la livraison (voir chapitre 7).

## 8.2 TES limites, à dire honnêtement

Ce que l'offre demande et que tu n'as pas :

| Exigence de l'offre | Ta situation réelle |
|---------------------|---------------------|
| Bonne connaissance en microbiologie (contaminants de surface et de l'air) | Pas de formation en microbiologie. Tu connais le vocabulaire et la logique statistique grâce à ce projet |
| Techniques de détection biochimique en chambre optique | Aucune pratique. Tu sais analyser un signal et fixer un seuil, pas faire fonctionner l'appareil |
| Validation et certification AOAC | Pas d'expérience réelle. Tu as étudié l'Appendix J et reproduit ses calculs statistiques principaux |
| Plans d'expériences | **Oui** : déjà acquis (NKURU, formation) et démontré ici |
| Analyse de données de performance | **Oui** : biostatistique, modèles linéaires généralisés et mixtes |
| Automatisation, traçabilité | **Oui** : R, Git, GitLab FAIR à l'INRAE, GitHub Actions |

**Phrase pour l'entretien :**

> « Je n'ai pas de formation en microbiologie et je n'ai jamais travaillé sur
> une chambre optique. En revanche, j'ai étudié les lignes directrices AOAC
> pour comprendre ce qu'on attend du statisticien dans une validation, et
> j'ai monté un projet complet sur données simulées : POD, dPOD, LOD50,
> étude interlaboratoires, plans d'expériences et pipeline traçable. Ma
> valeur ajoutée est sur la partie statistique et données ; je compte sur
> l'équipe du laboratoire pour la partie biologique, et je suis prêt à me
> former. »

## 8.3 Ce que tu peux écrire dans un CV

**Juste :**

> **Projet personnel — Validation statistique d'une méthode de détection de
> contaminants (données simulées, 2026)** : étude de matrice (POD, dPOD avec
> IC de Wilson selon la logique AOAC Appendix J), LOD50 et RLOD par modèle
> de Poisson (GLM cloglog), étude interlaboratoires (modèle mixte lme4),
> plans d'expériences (fractionnaire 2^5-1, composite centré, surface de
> réponse), pipeline R automatisé avec contrôles qualité, traçabilité
> SHA-256 et tests (GitHub Actions). github.com/REMESHA/validation-methode-detection

**À ne pas écrire :**

- « Expérience en validation AOAC » (c'est faux) ;
- « Validation conforme AOAC / ISO 16140-2 » (le projet s'en inspire) ;
- « Maîtrise de la microbiologie » ;
- toute formulation qui laisse croire que les données sont réelles.

## 8.4 Questions probables et éléments de réponse

**1. « Pourquoi l'intervalle de Wilson et pas l'intervalle classique ? »**
Avec 20 portions et des proportions proches de 0 ou 1, l'intervalle
classique (Wald) a une mauvaise couverture et peut sortir de [0 ; 1] ; à 0/20
il a une largeur nulle. Wilson reste dans [0 ; 1] et a une meilleure
couverture. C'est aussi ce que demandent les lignes directrices AOAC.

**2. « Que signifie une dPOD dont l'IC contient 0 ? »**
Qu'on n'a pas mis en évidence de différence au seuil de 5 %. Ça ne prouve pas
que les méthodes sont équivalentes : avec 20 portions, l'IC est large
(± 0,28 environ). Pour démontrer une équivalence, il faudrait fixer une marge
acceptable à l'avance et vérifier que l'IC entier est dans cette marge.

**3. « Pourquoi 20 portions au niveau bas et seulement 5 au niveau haut ? »**
C'est au niveau fractionnaire (25-75 % de positifs) que les méthodes peuvent
se distinguer : c'est là que l'information est maximale. Au niveau haut, les
deux méthodes détectent tout ; 5 portions suffisent à le vérifier.

**4. « Comment calculez-vous la LOD50 ? »**
Modèle de Poisson : POD = 1 − exp(−r λ), ajusté comme un GLM binomial à lien
log-log complémentaire avec log(λ) en offset. LOD50 = ln(2) / r. J'ai vérifié
l'hypothèse de pente 1 par un test du rapport de vraisemblance. On peut aussi
utiliser une régression logistique ou probit sur log(λ), ou la méthode de
Spearman-Kärber.

**5. « Pourquoi un modèle mixte pour l'étude interlaboratoires ? »**
Les laboratoires sont un échantillon de tous les laboratoires possibles. Un
effet aléatoire estime la variabilité entre laboratoires (la
reproductibilité), au lieu d'estimer 12 effets particuliers sans intérêt.

**6. « Qu'est-ce qu'un plan de résolution V ? »**
Les effets principaux et les interactions d'ordre 2 ne sont confondus
qu'avec des interactions d'ordre 3 ou plus. Avec 5 facteurs, un plan 2⁵⁻¹ de
16 essais (générateur E = ABCD) est de résolution V.

**7. « À quoi servent les points au centre ? »**
À estimer l'erreur de mesure par répétition et à détecter une courbure. Dans
le projet, la courbure était significative, d'où le passage à un plan
composite.

**8. « Pourquoi randomiser l'ordre des essais ? »**
Pour éviter qu'un effet du temps (dérive de l'appareil, lot de réactif,
opérateur) se confonde avec l'effet d'un facteur.

**9. « Comment garantissez-vous la traçabilité de vos analyses ? »**
Données brutes jamais modifiées, empreinte SHA-256 de chaque fichier lu,
paramètres dans un fichier de configuration versionné, registre des
anomalies, journal horodaté, version de R, des packages et du commit Git,
tests automatiques. Je connais les principes ALCOA+.

**10bis. « Comment savez-vous que votre analyse est reproductible ? »**
Une seule commande refait tout depuis la simulation (graine fixe), les
paramètres sont dans un fichier versionné, chaque variable est décrite dans
un dictionnaire vérifié automatiquement, et un script compare chaque
fichier produit, valeur par valeur, à une exécution de référence. (Si ton
exécution sous Windows affiche « 23 identique(s) », ajoute : « j'ai obtenu
exactement les mêmes résultats sous Linux avec R 4.3 et sous Windows avec
R 4.5 ».)

**10. « Vous n'avez pas de formation en microbiologie. Comment allez-vous
faire ? »**
Voir la phrase du 8.2. Ajouter : formation BPC validée, inscription au DIU
CESAM (module STARC), habitude de travailler avec des biologistes à l'INRAE
(microbiote, métabolome, RNA-seq).

## 8.5 Questions à poser au recruteur

- Quel type de contaminants et de matrices (surfaces, air, eaux) ?
- La certification visée est-elle un PTM ou un OMA ? Une validation
  ISO 16140-2 est-elle aussi prévue ?
- Avec quels outils statistiques travaille l'équipe (R, SAS, JMP, Minitab) ?
- Qui conçoit les plans d'expériences aujourd'hui ?
- Une formation en microbiologie est-elle prévue à l'arrivée ?
