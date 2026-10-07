# Rixe — axes d'amélioration et idées

Ce que je verrais bien entrer dans le jeu, rangé par version. ★ = mes recommandations prioritaires.
Les idées de Chris (07/10) sont marquées (Chris).

## Feuille de route

| Version | Thème | Contenu principal |
|---|---|---|
| ~~1.0~~ | Arcade | combat, démembrement, modes, classements |
| ~~1.1~~ | Monde vivant | décor destructible, ricochets, IA à personnalités |
| ~~1.2~~ | Armurerie | munitions et chargeurs, visée précise, nouvelles armes, grenades, personnalisation |
| ~~1.3~~ | Butin et cartes | drops, inventaire, nouvelles cartes, météo |
| ~~2.0~~ | Survie | grande carte, construction, ressources, faim, vagues |
| ~~3.0~~ | Ensemble | écran partagé, manette |
| ~~3.2~~ | Tout le reste | parties perso, en ligne à 4, progression et tenues, boss, mouvements, cartes, éditeur, rediffusion, photo |
| ~~3.1~~ | Ressenti + en ligne | marqueurs de touche, kill cam, exécutions, musique en couches, annonceur, partie à deux par Internet, viseur au choix |

## 1.2 — Armurerie
- ~~Munitions et chargeurs, rechargement (touche R, animation, son), à court = coup de pied. (Chris)~~ (fait)
- ~~★ Visée précise au clic droit maintenu : la caméra glisse vers le viseur, dispersion réduite, déplacement ralenti. (Chris)~~ (fait)
- ~~★ Recul contrôlable : le canon monte pendant une rafale, on compense à la souris.~~ (fait)
- ~~Nouvelles armes : pistolet (arme de secours), mitraillette, fusil de précision, lance-grenades, katana (tranche net).~~ (fait)
- ~~★ Grenades (touche G) : rebondissent, explosent, creusent le décor, projettent les corps.~~ (fait)
- ~~Personnalisation : viseur (point rouge, lunette), chargeur étendu, canon long, crosse ; pièces trouvées ou débloquées. (Chris)~~ (fait)

## 1.3 — Butin et cartes
- ~~Les ennemis lâchent munitions, soins et pièces d'armes. (Chris)~~ (fait)
- ~~Inventaire en grille, accessible avec Tab. (Chris)~~ (fait)
- ~~★ Nouvelles cartes : toits de ville sous la pluie, usine (tapis roulants, presses), mine (lampes qui se balancent), forêt de nuit. (Chris : « cartes différentes »)~~ (fait), wagonnet dans la mine compris.
- ~~Météo : pluie, neige, vent qui fait voler les écharpes et la fumée.~~ (fait), flaques qui reflètent comprises.
- ~~Objets d'arène : barils explosifs, vitres qui se brisent, lampes qui tombent quand on tire dessus.~~ (fait)
- ~~★ Décor qui s'effondre : une cellule sans appui tombe et écrase ce qui est dessous.~~ (fait)

## 2.0 — Survie (Chris)
- ~~Grande carte procédurale par tronçons, cycle jour/nuit.~~ (fait)
- ~~Construction : murs, portes, plateformes, pièges ; même système de cellules que le décor destructible.~~ (fait)
- ~~Ressources (bois, métal, nourriture), faim, fabrication de munitions.~~ (fait)
- ~~Vagues de nuit, base à défendre.~~ (fait)

## 3.0 — Ensemble
- ~~★ Écran partagé local à 2 (rapide à faire, le jeu est déjà pensé chacun pour soi).~~ (fait)
- ~~Manette (vibrations sur les coups, gâchettes). (Chris)~~ (fait)
- ~~Multijoueur pair à pair sans ouvrir de ports (WebRTC + petit relais de mise en relation). (Chris)~~ (fait, 3.1)

## Mécaniques à glisser dans n'importe quelle version
- ~~★ Exécutions façon Mortal Kombat : un adversaire à terre et presque mort peut être achevé au corps à corps, avec un plan de caméra dédié.~~ (fait, 3.1)
- ~~Glissade au sol, saut contre les murs, roulade d'esquive.~~ (fait)
- ~~Parade au bon moment pendant un coup de pied adverse (contre-attaque).~~ (fait)
- ~~Temps ralenti à la demande (jauge qui se remplit en éliminant).~~ (fait)
- ~~Boss toutes les 5 manches (plus grand, armure par membre, attaques lisibles).~~ (fait)
- ~~Séries annoncées : doublé, triplé, « sans prendre de coup ».~~ (fait)

## Ressenti et lisibilité
- ~~★ Marqueur de touche (croix blanche, rouge pour la tête) + son de touche à la tête.~~ (fait, 3.1)
- ~~★ Ralenti de fin de manche sur la dernière élimination (kill cam).~~ (fait, 3.1)
- ~~Chiffres de dégâts (désactivables).~~ (fait)
- ~~Indicateur de direction quand on se fait toucher hors champ.~~ (fait)

## Visuel
- ~~★ Éclairage 2D avec ombres portées par le décor (les tirs éclairent la scène).~~ (fait)
- ~~Normal maps sur les tuiles (Pigment sait déjà les générer) pour un relief au passage des éclairs.~~ (fait)
- ~~Impacts persistants sur le décor, fumée qui reste en nappe après une grosse fusillade.~~ (fait)
- ~~Néons et panneaux animés dans les ambiances urbaines.~~ (fait)

## Audio
- ~~★ Musique en couches qui suit l'action : calme, combat, ralenti, dernier survivant.~~ (fait, 3.1)
- ~~Une ambiance musicale par décor (crépuscule, acier, rouille, futures cartes).~~ (fait)
- ~~Annonces vocales générées en local (Qwen3-TTS) : « Décapitation », « Doublé », « Dernier debout ».~~ (fait, 3.1)
- ~~Réverbération selon le lieu (mine = écho, extérieur = sec).~~ (fait)

## Textures et générateur (Pigment)
- ~~Tenues de stickman : chapeaux, masques, capes, couleurs ; débloquées en jouant.~~ (fait)
- ~~Nouvelles tuiles : verre, bois, béton, grille métallique.~~ (fait)
- ~~Éléments de premier plan en parallaxe (câbles, feuillages).~~ (fait), décors animés en planches de sprites compris (ventilateurs, torches, drapeaux).

## Progression et rejouabilité
- ~~Expérience et déblocages (armes, tenues), défis du jour, succès, statistiques détaillées.~~ (fait)
- ~~Rediffusion de la dernière manche, mode photo.~~ (fait)
- ~~Éditeur de cartes (les cellules du décor s'y prêtent bien).~~ (fait)

## Prochaines mécaniques (Chris, 08/10)
- ~~★ Corps à corps poussé : enchaînements de coups (combos), saltos, prises (saisir, projeter, clé), contres ; lisible
  et nerveux, avec ses propres animations et sons.~~ (fait, 3.3 : direct/crochet/coup de pied, coup sauté, projection,
  saltos, parade sur tous les coups ; reste : clés et contres dédiés)
- ~~★ Mode de jeu « mains nues » : tout au corps à corps, aucune arme au sol ni au départ.~~ (fait, 3.3)
- ~~Arcade : armes à feu ET ce corps à corps complet intégré (passer de l'un à l'autre sans menu).~~ (fait, 3.3)
