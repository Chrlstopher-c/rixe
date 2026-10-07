# STATE — Rixe

- 07/10 : prototype montré à Chris, retours appliqués (HD par défaut, persos plus grands, bots moins forts, sauts). Brief validé.
- Nuit du 07/10 (branche `nuit/2026-10-07`) : stories de EPICS.md.

## Décisions
- Godot 4.7.2 binaire officiel (~/.local/bin/godot), pas de paquet système (pas de sudo).
- Rendu HD (canvas_items) par défaut, pixel (viewport 640×360) en option F1 : Chris veut des persos nets.
- Saut : touche maintenue = rebond automatique à l'atterrissage (Chris veut « spammer »), buffer 0,2 s, 2 sauts en l'air.
- Captures : x11grab sur Xvfb en temps réel (le movie maker de Godot enregistre la taille logique 640×360 en mode HD).
- Tests : `--tests=…` dans le jeu lui-même, `--fixed-fps 120` pour tourner plus vite que le temps réel.

## Nuit du 07/10 — livré (branche nuit/2026-10-07)
- Saut : rebond auto touche maintenue, buffer 0,2 s, 2 sauts en l'air. Bug « collé au sol » non reproduit par les tests clavier ;
  hypothèse retenue : touche maintenue (just_pressed ne se redéclenche pas) → corrigé par le rebond auto.
- Dégâts localisés (`fighters/body_parts.gd`) : tête ×2,5, membres ×0,6 ; vie par membre ; bras perdu = visée dégradée,
  jambe perdue = lent/rampe ; tête ou torse détruits = mort (décapitation / coupé en deux). Joueur et bots.
- Ralenti uniquement sur mort par la tête (joueur impliqué ou à l'écran). Gore : gibs physiques, jets artériels pulsés, taches.
- Sons synthétisés (`tools/gen_sfx.py`, 16 sons), autoload `Sfx`, hauteur suit le ralenti.
- Mêlée : coup de pied visé (E/F/molette), bots au contact. Armes au sol + ramassage par échange. Bord rouge de dégâts, viseur dynamique, ligne de visée.
- Perf (tools/perf.sh, sway headless GPU, 1080p, 7 combattants) : ~130-144 i/s moyen, 1 % bas 55-65, GPU ~2 ms.
- Piège : Xvfb plafonne à ~8 i/s en 1080p (copie logicielle) → jamais mesurer la perf dessus.
- Piège : en mode test, la logique de manche relançait une manche et libérait les combattants d'un autre test → désactivée sous --tests.
- Finitions (même nuit) : tir aux jambes au ras du sol, écran titre avec démo en fond + pause Échap (volume, HD/pixel,
  réglages persistants dans user://settings.cfg, jamais écrits pendant les tests), musique synthétisée en boucle
  (`tools/gen_music.py`), bots qui vont chercher une arme plus forte (railgun > pompe > fusil).
- E10 (même nuit) : perf consolidée (taches gravées dans une texture SubViewport jamais effacée, grille d'occupation 16 px
  pour les collisions de particules/cadavres, 14 cadavres max) → 1080p ~168 i/s, 1 % bas 77-98.
  3 ambiances Pigment (`arena/themes.gd`, `assets/textures/<thème>/`), tirées par manche.
  Mort du joueur = fin de partie (retour manche 1), record d'éliminations persistant (titre + HUD).
- Modes (07/10, retour de Chris) : `game/modes.gd` (Arcade / Chrono / Objectif), `game/match_state.gd` (stats, chrono,
  réapparitions 2,5 s au point le plus éloigné), `game/leaderboard.gd` (top 5 par mode+réglage, Objectif classé au temps),
  `hud/scoreboard.gd` (fin de partie, jeu figé, Entrée rejouer / Échap menu). Pause → « Menu principal ».
  Bug corrigé : fin de manche arcade avec un bot vivant (décompte de la victime en double).
- V1.1 (07/10) : décor destructible (`arena/terrain.gd` + `terrain_chunk.gd`, cellules 8 px, 40 px de sol sur roche,
  collisions et rendu par tronçon de 16 colonnes, index cellules par tronçon), ricochets (`Gun._trace`, chance selon
  l'angle d'incidence), IA à personnalités (`fighters/ai/` : personality, navigator, aimer, bot_brain à états ENGAGE /
  RUSH / RETREAT / LOOT / SEARCH / HIGH + esquive), perception cadencée à 80 ms, bots qui se régénèrent.
  Bug corrigé : la régénération ramenait la vie à 100 même au-dessus (minf avec MAX_HP).
  Piège GDScript : is_instance_valid sur une variable typée peut mentir dans les tests → weakref.
- V1.2 (07/10) : munitions (chargeur/réserve/rechargement, munitions sur arme identique), visée précise (clic droit),
  remontée du canon (`Gun.climb`, récupération après 0,18 s sans tirer), 5 armes de plus (pistolet, mitraillette,
  précision, lance-grenades à gravité réduite, katana = `kind: blade`), grenades à main (G, 2 par vie),
  accessoires (`Arsenal.ATTACHMENTS`, `Arsenal.compose`), déblocages persistants et armurerie au titre (`game/unlocks.gd`).
  Archétypes : Tireur → précision, Acrobate → mitraillette, Fou → lance-grenades.
- V1.3 (07/10) : butin et inventaire (`fighters/inventory.gd`, `weapons/loot.gd`, `hud/inventory_screen.gd`),
  3 cartes (`arena/maps.gd` : plateformes / toits au-dessus du vide (`void_y`, mort par chute) / mine en roche creusée),
  nouveaux types de cellules ROCK/BRICK, surface par colonne pour l'herbe, météo (`fx/weather.gd`) + vent (`Juice.wind`),
  objets d'arène (`arena/props/` : barils explosifs en chaîne, lampes suspendues), effondrement (`Terrain._settle`,
  `arena/falling_chunk.gd` ; montants de plateformes = appuis). Apparitions dans `game/spawner.gd`.
  Perf : dessins regroupés (multiline), fantômes allégés, rien n'est redessiné hors écran → 1080p ~195 i/s, 1 % bas 67-88.
  Outil : `core/prof.gd` (RIXE_PROF=1) pour profiler une section (Prof.begin/end) avec tools/perf.sh.
