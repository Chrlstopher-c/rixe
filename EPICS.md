# EPICS — Rixe V1 (arcade)

Chaque story : intention — VERIFY exécutable. Tests de jeu = `godot --headless --path . -- --tests=<nom>` (PASS/FAIL, code de sortie).

## E1 — Fondations
- [x] E1.S1 — banc de tests headless (scénarios scriptés, intentions simulées) — VERIFY: `tools/verify.sh` affiche « TESTS OK »
- [x] E1.S2 — scripts start/stop/restart (PID propre, logs remis à zéro), docs projet, CI GitHub Actions (import + tests headless) — VERIFY: `./start.sh && sleep 4 && ./stop.sh` sans erreur, `logs/rixe.log` sans `SCRIPT ERROR`

## E2 — Mouvement
- [x] E2.S1 — saut toujours disponible après atterrissage (bug « collé au sol »), saut spammable, 2 sauts en l'air max — VERIFY: `--tests=movement`

## E3 — Dégâts localisés et démembrement
- [x] E3.S1 — zones touchées (tête, torse, bras, jambes) par test rayon/segment sur le squelette ; tête = dégâts ×2,5 — VERIFY: `--tests=hitzones`
- [x] E3.S2 — membres qui lâchent (vie par membre) : bras perdu → visée dégradée, jambe perdue → lent ; tête détruite → mort immédiate ; joueur et bots — VERIFY: `--tests=dismember`
- [x] E3.S3 — ralenti uniquement sur un kill à la tête ; morceaux qui volent (gibs physiques), jets artériels pulsés, taches sur murs/plateformes, dosage « Doom » — VERIFY: `--tests=headshot_slowmo` + capture vidéo relue

## E4 — Son
- [x] E4.S1 — bruitages synthétisés en local (tirs ×3 armes, impacts, chair, décapitation, saut, atterrissage, dash, douilles, mêlée) + lecteur 2D avec variations de hauteur — VERIFY: `tools/gen_sfx.py` produit les .wav, `--tests=audio` charge tous les sons

## E5 — Mêlée façon Mortal Kombat
- [x] E5.S1 — coup de mêlée (touche E / clic molette) : frappe, gros recul, peut trancher un membre affaibli ; bots l'utilisent au contact — VERIFY: `--tests=melee`

## E6 — Boucle arcade
- [x] E6.S1 — les armes tombent à la mort, ramassage en passant dessus (échange) — VERIFY: `--tests=pickup`
- [x] E6.S2 — retour visuel des dégâts du joueur (bord d'écran rouge discret), viseur précis souris — VERIFY: capture relue

## E7 — Pigment MCP
- [x] E7.S1 — serveur MCP stdio (textures pixel/low poly/ciel/normal map → fichier PNG), test client de bout en bout, enregistré au niveau utilisateur — VERIFY: `pigment/tests/e2e_mcp.py` OK, chaque outil < 2 s

## E8 — Performance
- [x] E8.S1 — 60 i/s stables en 1080p à 6 combattants sur la tour — VERIFY: `tools/perf.sh` (moyenne ≥ 60, 1 % bas ≥ 50)

## E9 — Finitions V1 (nuit, après les épiques validées)
- [x] E9.S1 — tir aux jambes : le rayon arrêté par le sol juste devant un pied touche la jambe — VERIFY: `--tests=legshot`
- [x] E9.S2 — écran titre (Entrée pour jouer) + pause Échap (reprendre, volume, HD/pixel, quitter) — VERIFY: `--tests=menu`
- [x] E9.S3 — musique synthétisée en boucle, ducking pendant le ralenti — VERIFY: `--tests=audio` (piste chargée, boucle)
- [x] E9.S4 — bots qui ramassent une arme proche plus forte — VERIFY: `--tests=bot_pickup`

## E10 — Marge et variété (nuit)
- [x] E10.S1 — marge perf : 1 % bas ≥ 70 en 1080p — VERIFY: `tools/perf.sh 20` (×2)
- [x] E10.S2 — 3 thèmes d'arène (crépuscule, nuit d'acier, rouille) générés par Pigment, tirés par manche — VERIFY: `--tests=themes`
- [x] E10.S3 — meilleur score (éliminations d'une partie) persistant, affiché au titre et à la mort — VERIFY: `--tests=score`

## E11 — Modes et classements (retour de Chris, 07/10)
- [x] E11.S1 — bug : la manche arcade se terminait avec un bot encore en vie (victime décomptée deux fois) — VERIFY: `--tests=arcade_last_bot`
- [x] E11.S2 — sélecteur de mode au titre : Arcade (une vie), Chrono (1/2/3/5/10 min, réapparitions), Objectif (5/10/20/30 élim.) — VERIFY: `--tests=chrono,objectif`
- [x] E11.S3 — écran de fin (classement des combattants, élim./morts) et top 5 persistant par mode et réglage, vue « Classement » au titre — VERIFY: `--tests=leaderboard` + capture relue

# V1.1 — Monde vivant (demande de Chris, 07/10)

## E12 — Destruction et ricochets
- [x] E12.S1 — décor destructible en cellules de 8 px (sol sur 40 px au-dessus de la roche, caisses, plateformes) : vie par cellule, débris, poussière, collisions reconstruites par tronçon — VERIFY: `--tests=terrain`
- [x] E12.S2 — ricochets selon l'angle d'incidence (fusil 2 rebonds, pompe 1, railgun 1), son dédié, dégâts réduits, peut toucher le tireur — VERIFY: `--tests=ricochet`

## E13 — IA à personnalités
- [x] E13.S1 — 5 archétypes (Brute, Tireur, Acrobate, Renard, Fou) : agressivité, distance, mobilité, précision, seuil de fuite — VERIFY: `--tests=personalities`
- [x] E13.S2 — comportements : engager, foncer, fuir et se soigner, esquiver quand on est visé, flanquer, chercher une arme, se mettre à couvert — VERIFY: `--tests=behaviours`
- [x] E13.S3 — humanisation : temps de réaction, visée qui suit avec dépassement, rafales, mémoire de la dernière position vue, déblocage — VERIFY: `--tests=humanize` + capture relue
- [x] E13.S4 — navigation : monter vers une plateforme accessible, descendre, sauter les trous creusés — VERIFY: `--tests=navigation`

# V1.2 — Armurerie

## E14 — Munitions et visée
- [x] E14.S1 — chargeur + réserve par arme, rechargement (R, auto à vide), pose et sons de rechargement, munitions récupérées sur une arme identique au sol, affichage — VERIFY: `--tests=ammo`
- [x] E14.S2 — visée précise au clic droit (dispersion ×0,4, déplacement ×0,6, caméra qui glisse vers le viseur) — VERIFY: `--tests=aim_recoil`
- [x] E14.S3 — remontée du canon en rafale, à compenser à la souris ; les bots précis compensent — VERIFY: `--tests=aim_recoil`

## E15 — Nouvelles armes et grenades
- [x] E15.S1 — pistolet, mitraillette, fusil de précision, lance-grenades, katana — VERIFY: `--tests=arsenal`
- [x] E15.S2 — grenades (G) : rebonds, explosion qui creuse le décor et arrache des membres, bots qui en lancent — VERIFY: `--tests=grenade`

## E16 — Personnalisation
- [x] E16.S1 — accessoires (point rouge, lunette, chargeur étendu, canon long, crosse) trouvés dans l'arène, visibles sur l'arme — VERIFY: `--tests=attachments`
- [x] E16.S2 — armurerie au titre : arme et accessoires de départ, accessoires débloqués en les ramassant une fois — VERIFY: `--tests=armory`

# V1.3 — Butin et cartes

## E17 — Butin et inventaire
- [x] E17.S1 — butin à la mort (munitions, soin, grenade, accessoires du sac), ramassage, bots qui vont chercher soin/munitions — VERIFY: `--tests=loot`
- [x] E17.S2 — inventaire : 2 armes (1/2, molette, temps pour dégainer), sac de 4 accessoires, trousses (H, soin progressif) — VERIFY: `--tests=inventory`
- [x] E17.S3 — écran d'inventaire (Tab, jeu figé) : monter/ranger les accessoires à la souris — VERIFY: `--tests=inventory_screen` + capture relue

## E18 — Cartes, météo, objets d'arène
- [x] E18.S1 — 3 types de cartes : Plateformes (actuelle), Toits (immeubles au-dessus du vide, chute mortelle), Mine (roche épaisse creusée de galeries, tout se creuse) — VERIFY: `--tests=maps`
- [x] E18.S2 — météo : pluie (Toits), neige (Acier), braises (Rouille) ; vent qui pousse fumée, écharpes et grenades — VERIFY: `--tests=weather`
- [x] E18.S3 — objets d'arène : barils explosifs, lampes suspendues qui tombent et éclairent — VERIFY: `--tests=props`

## E19 — Effondrement
- [x] E19.S1 — les morceaux de décor qui ne tiennent plus à rien tombent, écrasent et blessent — VERIFY: `--tests=collapse`

# V2.0 — Survie

## E20 — Monde et cycle
- [x] E20.S1 — mode Survie : terres sauvages de 6000 px (collines, arbres, rochers, buissons, carcasses), fond répété sans fin, taches adaptées — VERIFY: `--tests=survival`
- [x] E20.S2 — cycle jour (2 min 30) / nuit (1 min 30) avec crépuscule et aube, teinte du monde et du fond, torche du joueur — VERIFY: capture relue

## E21 — Ressources et construction
- [x] E21.S1 — récolte : la pioche (2e arme), les coups et les tirs du joueur donnent bois / pierre / métal ; buissons = nourriture — VERIFY: `--tests=survival`
- [x] E21.S2 — construction (B) : murs bois/pierre, plateforme, porte (le joueur passe, pas les pillards), pointes ; démontage remboursé à moitié — VERIFY: `--tests=survival`

## E22 — Faim et fabrication
- [x] E22.S1 — faim (6 min pour mourir de faim, plus de régénération si affamé), manger (C) — VERIFY: `--tests=survival`
- [x] E22.S2 — fabrication dans l'inventaire : munitions, trousse, grenade — VERIFY: `--tests=survival`

## E23 — Vagues
- [x] E23.S1 — pillards (équipe, visent le joueur, forcent murs et portes) : vague à chaque nuit (2 + 2 × jour), rôdeurs le jour ; mort = fin, score = nuits tenues, classement — VERIFY: `--tests=survival`

# V3.0 — Ensemble (local)

## E24 — Manette
- [x] E24.S1 — manette : sticks, gâchettes (tir / visée précise), boutons, aide à la visée, vibrations ; bascule automatique clavier ⇄ manette ; menus à la croix — VERIFY: `--tests=pad`

## E25 — Écran partagé
- [x] E25.S1 — deux joueurs (J1 clavier/souris, J2 manette), écran coupé en deux rendus pleine définition, coopération en arcade, chacun pour soi en chrono/objectif — VERIFY: `--tests=duo` + capture relue

## E26 — En ligne (relais Cloudflare Worker, adresse fixe)
Choix : relais WebSocket par Durable Object (pas de WebRTC) — marche derrière toutes les box, sans port ouvert,
sans binaire natif à embarquer ; +10-30 ms de latence. Hôte autoritaire (bots, objets, manches), chaque joueur
autoritaire sur son propre combattant ; « qui provoque l'effet calcule ses dégâts ».
- [x] E26.S1 — relais : salon à code de 4 lettres, 2 places, messages binaires relayés — VERIFY: `cd relay && pnpm test`
- [x] E26.S2 — lien réseau Godot (WebSocketPeer, rôles hôte/invité, reconnexion propre) — VERIFY: `tools/online_test.sh link`
- [x] E26.S3 — partie synchronisée : même carte, marionnettes interpolées, tirs, dégâts, morts, réapparitions,
  objets — VERIFY: `tools/online_test.sh match`
- [x] E26.S4 — menu En ligne (héberger / rejoindre par code), HUD et fin de partie de l'invité — VERIFY: tests menu + capture
- [x] E26.S5 — déploiement du Worker (adresse workers.dev fixe, hors dépôt) + release — VERIFY: `tools/online_test.sh match` contre le Worker déployé

## E27 — Exécution par l'invité en ligne
- [x] E27.S1 — l'invité exécute un bot de l'hôte (l'hôte l'immobilise, le coup de grâce arrive comme une touche) — VERIFY: `tools/online_test.sh exec`

## E28 — Pseudo
- [x] E28.S1 — pseudo par défaut « anon » + nombre, modifiable au menu, utilisé partout (fil, en ligne, fins de partie, classements) — VERIFY: tests menu + online match

## E29 — Classement mondial
- [x] E29.S1 — Worker : envoi et lecture des meilleurs scores par mode, validation, limitation — VERIFY: `cd relay && pnpm test`
- [x] E29.S2 — jeu : envoi en fin de partie, onglet MONDIAL au classement — VERIFY: test contre relais local

## E30 — En ligne à 4
- [x] E30.S1 — relais : salon jusqu'à 4 places (hôte + 3 invités), messages diffusés avec l'expéditeur — VERIFY: `cd relay && pnpm test`
- [x] E30.S2 — session à N invités (J2, J3, J4), marionnettes de chacun chez chacun — VERIFY: `tools/online_test.sh` à 3 et 4 jeux

## E31 — Parties personnalisées
- [x] E31.S1 — réglages de partie : mode, durée/objectif, carte, équipes, nombre et niveau des bots, armes, joueurs max — VERIFY: tests
- [x] E31.S2 — salon en ligne clair : joueurs (pseudos, équipes), réglages de l'hôte visibles, choix de son équipe — VERIFY: tests + capture
