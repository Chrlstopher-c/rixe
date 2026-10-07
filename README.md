# Rixe

Jeu de combat 2D vu de côté entre stickmen armés, contre des bots. Godot 4.7.2 (GDScript + shaders), 100 % local.

## Lancer
- `./start.sh` (fenêtre, journal `logs/rixe.log`) · `./stop.sh` · `./restart.sh`
- ou directement : `godot --path .` ; options après `--` : `--pixel` (rendu pixel art), `--seed=N`, `--demo` (IA aux commandes)

## Commandes (touches physiques : ZQSD sur AZERTY)
ZQSD/flèches : bouger · Espace/Z : sauter (maintenu = rebonds, 2 sauts en l'air) · S : descendre d'une plateforme ·
souris : viser · clic gauche : tirer · Maj/clic droit : dash · E/clic molette : mêlée · F1 : HD ⇄ pixel · R : relancer la manche

## Outils
- `tools/verify.sh [tests]` : import + tests headless (PASS/FAIL)
- `tools/capture.sh <s> [args]` : partie démo filmée hors écran (Xvfb + GPU) → `~/Downloads/rixe-captures/demo.mp4`
- `tools/perf.sh [s]` : mesure 1080p sur sway headless GPU (moyenne ≥ 60, 1 % bas ≥ 50)
- `godot --path . -- --tests=showcase` : démo scriptée du gore (à filmer avec `tools/capture.sh 13 --tests=showcase`)
- `tools/gen_assets.py` : textures via Pigment (`/mnt/projects/pigment`) ; `tools/gen_sfx.py` : bruitages synthétisés

Aucun port réseau.
