# STATE — Rixe

- 07/10 : prototype montré à Chris, retours appliqués (HD par défaut, persos plus grands, bots moins forts, sauts). Brief validé.
- Nuit du 07/10 (branche `nuit/2026-10-07`) : stories de EPICS.md.

## Décisions
- Godot 4.7.2 binaire officiel (~/.local/bin/godot), pas de paquet système (pas de sudo).
- Rendu HD (canvas_items) par défaut, pixel (viewport 640×360) en option F1 : Chris veut des persos nets.
- Saut : touche maintenue = rebond automatique à l'atterrissage (Chris veut « spammer »), buffer 0,2 s, 2 sauts en l'air.
- Captures : x11grab sur Xvfb en temps réel (le movie maker de Godot enregistre la taille logique 640×360 en mode HD).
- Tests : `--tests=…` dans le jeu lui-même, `--fixed-fps 120` pour tourner plus vite que le temps réel.
