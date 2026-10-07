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
| **2.0** | Survie | grande carte, construction, ressources, faim, vagues |
| **3.0** | Ensemble | écran partagé, manette, multijoueur pair à pair |

## 1.2 — Armurerie
- Munitions et chargeurs, rechargement (touche R, animation, son), à court = coup de pied. (Chris)
- ★ Visée précise au clic droit maintenu : la caméra glisse vers le viseur, dispersion réduite, déplacement ralenti. (Chris)
- ★ Recul contrôlable : le canon monte pendant une rafale, on compense à la souris.
- Nouvelles armes : pistolet (arme de secours), mitraillette, fusil de précision, lance-grenades, katana (tranche net).
- ★ Grenades (touche G) : rebondissent, explosent, creusent le décor, projettent les corps.
- Personnalisation : viseur (point rouge, lunette), chargeur étendu, canon long, crosse ; pièces trouvées ou débloquées. (Chris)

## 1.3 — Butin et cartes
- Les ennemis lâchent munitions, soins et pièces d'armes. (Chris)
- Inventaire en grille, accessible avec Tab. (Chris)
- ★ Nouvelles cartes : toits de ville sous la pluie, usine (tapis roulants, presses), mine (wagons, lampes qui se balancent), forêt de nuit. (Chris : « cartes différentes »)
- Météo : pluie (flaques qui reflètent), neige, vent qui fait voler les écharpes et la fumée.
- Objets d'arène : barils explosifs, vitres qui se brisent, lampes qui tombent quand on tire dessus.
- ★ Décor qui s'effondre : une cellule sans appui tombe et écrase ce qui est dessous.

## 2.0 — Survie (Chris)
- Grande carte procédurale par tronçons, cycle jour/nuit.
- Construction : murs, portes, plateformes, pièges ; même système de cellules que le décor destructible.
- Ressources (bois, métal, nourriture), faim, fabrication de munitions.
- Vagues de nuit, base à défendre.

## 3.0 — Ensemble
- ★ Écran partagé local à 2 (rapide à faire, le jeu est déjà pensé chacun pour soi).
- Manette (vibrations sur les coups, gâchettes). (Chris)
- Multijoueur pair à pair sans ouvrir de ports (WebRTC + petit relais de mise en relation). (Chris)

## Mécaniques à glisser dans n'importe quelle version
- ★ Exécutions façon Mortal Kombat : un adversaire à terre et presque mort peut être achevé au corps à corps, avec un plan de caméra dédié.
- Glissade au sol, saut contre les murs, roulade d'esquive.
- Parade au bon moment pendant un coup de pied adverse (contre-attaque).
- Temps ralenti à la demande (jauge qui se remplit en éliminant).
- Boss toutes les 5 manches (plus grand, armure par membre, attaques lisibles).
- Séries annoncées : doublé, triplé, « sans prendre de coup ».

## Ressenti et lisibilité
- ★ Marqueur de touche (croix blanche, rouge pour la tête) + son de touche à la tête.
- ★ Ralenti de fin de manche sur la dernière élimination (kill cam).
- Chiffres de dégâts (désactivables).
- Indicateur de direction quand on se fait toucher hors champ.

## Visuel
- ★ Éclairage 2D avec ombres portées par le décor (les tirs éclairent la scène).
- Normal maps sur les tuiles (Pigment sait déjà les générer) pour un relief au passage des éclairs.
- Impacts persistants sur le décor, fumée qui reste en nappe après une grosse fusillade.
- Néons et panneaux animés dans les ambiances urbaines.

## Audio
- ★ Musique en couches qui suit l'action : calme, combat, ralenti, dernier survivant.
- Une ambiance musicale par décor (crépuscule, acier, rouille, futures cartes).
- Annonces vocales générées en local (Qwen3-TTS) : « Décapitation », « Doublé », « Dernier debout ».
- Réverbération selon le lieu (mine = écho, extérieur = sec).

## Textures et générateur (Pigment)
- Tenues de stickman : chapeaux, masques, capes, couleurs ; débloquées en jouant.
- Nouvelles tuiles : verre, bois, béton, grille métallique.
- Décors animés (planches de sprites), éléments de premier plan en parallaxe (câbles, feuillages).

## Progression et rejouabilité
- Expérience et déblocages (armes, tenues), défis du jour, succès, statistiques détaillées.
- Rediffusion de la dernière manche, mode photo.
- Éditeur de cartes (les cellules du décor s'y prêtent bien).
