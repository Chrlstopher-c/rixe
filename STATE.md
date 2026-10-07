# STATE — Rixe
*Dernière mise à jour : 2026-10-07*

## Résumé de l'état actuel
Jeu de combat 2D stickman en Godot 4.7.2, sur la tour (`/mnt/projects/rixe`, lien `~/projects/rixe`). Dernière version publiée : **v3.0.1**.
- Dépôt public : github.com/Chrlstopher-c/rixe. CI verte (40 tests headless).
- Releases sur GitHub pour Linux (testée), Windows et macOS universel (compilées, jamais lancées sur une vraie machine).
- Modes : Arcade, Chrono, Objectif, Survie. Écran partagé à deux et manette.
- Perf 1080p sur la tour : 150 à 210 i/s en moyenne, 1 % bas entre 50 et 100 selon la carte et le nombre de combattants.
- Textures générées par Pigment (`/mnt/projects/pigment`, dépôt privé, MCP `pigment`).

## Ce qui a été fait — session du 07/10
- **v1.0.0** : arcade. Démembrement, gore, ralenti sur mort par la tête, sons et musique synthétisés, modes Chrono et Objectif, classements. Release validée par Chris.
- **v1.1.0** : décor destructible en cellules de 8 px, ricochets, IA à 5 personnalités.
- **v1.2.0** : munitions, visée précise, remontée du canon, 5 armes de plus, grenades, accessoires, armurerie.
- **v1.3.0** : butin, inventaire (2 armes, sac, soins), 3 cartes (plateformes, toits, mine), météo, barils et lampes, effondrement du décor.
- **v2.0.0** : mode Survie (carte de 6000 px, jour/nuit, récolte, construction, faim, fabrication, pillards).
- **v3.0.0** : manette et écran partagé à deux. **v3.0.1** : export macOS universel.
- `IDEES.md` : feuille de route et idées classées, demandé par Chris.

## Décisions prises
| Décision | Raison | Date |
|----------|--------|------|
| Rendu HD par défaut, pixel en option (F1) | Chris veut des personnages nets | 07/10 |
| Saut : touche maintenue = rebond auto, buffer 0,2 s, 2 sauts en l'air | Chris veut « spammer » le saut | 07/10 |
| Ralenti seulement sur une mort par la tête | Consigne de Chris | 07/10 |
| Tout se fait et se teste sur la tour, rien sur le portable | Consigne de Chris | 07/10 |
| Physique à 120 Hz conservée | À 60 Hz le gain était nul : le coût venait des dessins, pas de la physique | 07/10 |
| Arènes sous `arena/`, survie sous `survival/` | Découpage par domaine | 07/10 |
| Mac : signature ad hoc, sans notarisation | Pas de compte développeur Apple | 07/10 |

## Contexte non-évident
- **Captures** : `tools/capture.sh` filme en temps réel (Xvfb + x11grab). Le movie maker de Godot enregistre la taille logique 640×360 en HD, donc inutilisable ici.
- **Perf** : `tools/perf.sh` tourne sur un sway headless rendu par le GPU, avec un XDG_RUNTIME_DIR privé. Ne jamais mesurer sur Xvfb (~8 i/s en 1080p).
- **Profilage** : `core/prof.gd` avec RIXE_PROF=1 (Prof.begin/end). Les gros postes ont été le dessin des bonhommes et les particules.
  - Correctifs appliqués : tracés regroupés (draw_multiline), fantômes allégés, rien de dessiné hors écran.
- **Tests** : `--tests=…` dans le jeu même, avec `--fixed-fps 120`. Les noms en `showcase*` sont des démos filmables, exclues de `all`.
- **Réglages** : jamais écrits pendant les tests (`Settings.persist = false`).
- **Pièges GDScript** :
  - `is_instance_valid` peut mentir sur une variable typée : utiliser `weakref`.
  - Un objet libéré passé à un paramètre typé provoque une erreur : passer par `Variant`.
  - `class_name Tree` est interdit (classe native), d'où `WildTree`.
- **Écran partagé** : deux SubViewport partagent le World2D. La vue principale est éteinte (caméra désactivée, transformation hors champ). Les caméras actives sont dans `Juice.cameras`.
- **Export macOS** : nécessite `textures/vram_compression/import_etc2_astc=true`.

## Prochaines étapes
1. Retour de Chris sur v1.1 → v3.0.1 : ressenti des IA, survie, écran partagé, et tester l'app Mac sur un vrai Mac.
2. Multijoueur en ligne pair à pair (E26), dès que Chris a choisi l'hébergement du serveur de mise en relation.
3. Idées suivantes : voir `IDEES.md` (exécutions façon Mortal Kombat, marqueurs de touche, musique en couches, tenues).

## Points en suspens
- **Hébergement du serveur de mise en relation** (décision de Chris) : Cloudflare Worker (recommandé) ou Pi. Pas de sous-domaine sur le tunnel du Pi sans demande explicite.
- Builds Windows et macOS jamais lancées sur une vraie machine.

## Historique
- 07/10 nuit : V1 arcade (E1–E10), branche nuit/2026-10-07 fusionnée dans main.
- 07/10 : prototype montré, retours appliqués (HD, persos plus grands, bots moins forts, sauts), brief validé.
