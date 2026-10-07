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
