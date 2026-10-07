# Rixe

Jeu de combat 2D vu de côté entre stickmen armés, contre des bots. Godot 4.7.2 (GDScript + shaders), 100 % local.

## Lancer
- `./start.sh` (fenêtre, journal `logs/rixe.log`) · `./stop.sh` · `./restart.sh`
- ou directement : `godot --path .` (écran titre) ; options après `--` : `--play` (sans titre), `--pixel`, `--seed=N`, `--demo` (IA aux commandes)

## Commandes (touches physiques : ZQSD sur AZERTY)
ZQSD/flèches : bouger · Espace/Z : sauter (maintenu = rebonds, 2 sauts en l'air) · S : descendre d'une plateforme ·
souris : viser · clic gauche : tirer · clic droit maintenu : visée précise · R : recharger · G : grenade · 1/2/molette : changer d'arme · H : soin · Tab : inventaire (et fabrication en survie) · B : construire · C : manger (survie) · Maj : dash · E/clic molette : mêlée · F1 : HD ⇄ pixel · au titre : ‹ › pour le mode et la durée/objectif, Armurerie (arme et accessoires de départ), Classement · Échap : pause (reprendre, recommencer, volume, affichage, menu)

## Manette et deux joueurs
Manette : stick gauche bouger, A sauter, stick droit viser, gâchette droite tirer, gâchette gauche visée précise, B coup de pied, X recharger, RB grenade, LB dash, Y changer d'arme, croix haut soin, Start pause. Au titre, « JOUEURS 2 » : écran partagé, J1 au clavier/souris, J2 à la manette.

## En ligne (à deux par Internet, sans ouvrir de port)
Au titre, « EN LIGNE » : l'un héberge (un code de 4 lettres s'affiche, il choisit le mode et lance), l'autre tape le code. Les messages passent par un petit relais Cloudflare (Worker) ; son adresse vient de `RIXE_RELAY` ou du fichier `online/relay.cfg` (hors dépôt, embarqué à l'export, voir `online/relay.cfg.example`), sinon `ws://127.0.0.1:8787`.
- Relais en local : `cd relay && pnpm install && pnpm dev` ; tests : `pnpm test`
- Déployer : `cd relay && pnpm run deploy` (compte Cloudflare connecté par `wrangler login`), puis écrire l'adresse `wss://…workers.dev` dans `online/relay.cfg`
- `tools/online_test.sh link|match|checks|version` : relais local + deux jeux headless qui jouent ensemble
- Multiplateforme : `RIXE_HOST_CMD="build/linux/rixe.x86_64 --headless" RIXE_GUEST_CMD=tools/win_run.sh tools/online_test.sh match` (jeu Windows sous Proton-GE)
- Contrôles en ligne : même version exigée des deux côtés (refus clair sinon) ; décor comparé à chaque manche et recalé sur celui de l'hôte s'il diffère

## Outils
- `tools/verify.sh [tests]` : import + tests headless (PASS/FAIL)
- `tools/capture.sh <s> [args]` : partie démo filmée hors écran (Xvfb + GPU) → `~/Downloads/rixe-captures/demo.mp4`
- `tools/perf.sh [s]` : mesure 1080p sur sway headless GPU (moyenne ≥ 60, 1 % bas ≥ 50)
- `godot --path . -- --tests=showcase` : démo scriptée du gore (à filmer avec `tools/capture.sh 13 --tests=showcase`)
- `tools/gen_music.py` : musique en trois couches synthétisée (calme, combat, tension)
- `tools/gen_voice.py` : annonces vocales (Qwen3-TTS VoiceDesign en local, voix décrite par un texte, aucun clonage) ; prises vérifiées par transcription
- `tools/gen_assets.py` : textures via Pigment (dépôt voisin `../pigment` ou `PIGMENT_PATH`) ; `tools/gen_sfx.py` : bruitages synthétisés

Le jeu n'ouvre aucun port : en ligne, il se connecte en sortie au relais (WebSocket).
