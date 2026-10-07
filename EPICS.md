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
